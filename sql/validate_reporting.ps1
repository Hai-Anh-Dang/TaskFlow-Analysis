param(
    [string]$Server = 'localhost\SQLEXPRESS',
    [string]$Database = 'TaskFlow',
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$EvidenceDirectory = (Join-Path $ProjectRoot 'validation/local/sql')
)
$ErrorActionPreference = 'Stop'
$stageRoot = $ProjectRoot
[void](New-Item -ItemType Directory -Path $EvidenceDirectory -Force)
$outputPath = Join-Path $EvidenceDirectory 'sql_execution_results.json'
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = "Server=$Server;Database=$Database;Integrated Security=True;Encrypt=False;Connect Timeout=15;Application Name=TaskFlowReportingValidation"
$record = [ordered]@{
    execution_started_utc = [DateTime]::UtcNow.ToString('o')
    server = $Server
    database = $Database
    mode = 'Execute updated views and reporting queries inside one transaction; roll back all view changes'
    script_hashes = @()
    result_sets = @()
    rollback_completed = $false
    success = $false
}
$transaction = $null
function Get-ReportingDefinitions([System.Data.SqlClient.SqlConnection]$sqlConnection) {
    $definitionCommand = $sqlConnection.CreateCommand()
    $definitionCommand.CommandText = "SELECT v.name, m.definition FROM sys.views v JOIN sys.schemas s ON v.schema_id=s.schema_id JOIN sys.sql_modules m ON v.object_id=m.object_id WHERE s.name='taskflow_reporting' ORDER BY v.name FOR JSON PATH"
    $definitionReader = $definitionCommand.ExecuteReader()
    $definitionText = [System.Text.StringBuilder]::new()
    try { while ($definitionReader.Read()) { [void]$definitionText.Append($definitionReader.GetString(0)) } }
    finally { $definitionReader.Close(); $definitionCommand.Dispose() }
    return $definitionText.ToString()
}
try {
    $connection.Open()
    $definitionsBefore = Get-ReportingDefinitions $connection
    $definitionsBefore | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'database_views_before.json') -Encoding UTF8
    $transaction = $connection.BeginTransaction()
    foreach ($fileName in @('02_reporting_views.sql', '03_dashboard_queries.sql')) {
        $scriptPath = Join-Path $stageRoot "sql\$fileName"
        $record.script_hashes += [ordered]@{file=$fileName;sha256=(Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash}
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw
        $batches = [regex]::Split($scriptText, '(?im)^\s*GO\s*(?:--[^\r\n]*)?\r?$')
        $batchNumber = 0
        foreach ($batch in $batches) {
            $batchNumber++
            if ([string]::IsNullOrWhiteSpace($batch)) { continue }
            $command = $connection.CreateCommand()
            $command.Transaction = $transaction
            $command.CommandTimeout = 300
            $command.CommandText = $batch
            $reader = $command.ExecuteReader()
            try {
                do {
                    if ($reader.FieldCount -eq 0) { continue }
                    $columns = @()
                    for ($index=0; $index -lt $reader.FieldCount; $index++) { $columns += $reader.GetName($index) }
                    $rows = [System.Collections.Generic.List[object]]::new()
                    while ($reader.Read()) {
                        $row = [ordered]@{}
                        for ($index=0; $index -lt $reader.FieldCount; $index++) {
                            $value = $reader.GetValue($index)
                            if ($value -is [DBNull]) { $value = $null }
                            elseif ($value -is [DateTime]) { $value = $value.ToString('yyyy-MM-ddTHH:mm:ss') }
                            $row[$columns[$index]] = $value
                        }
                        $rows.Add($row)
                    }
                    $record.result_sets += [ordered]@{script=$fileName;batch=$batchNumber;columns=$columns;row_count=$rows.Count;rows=$rows.ToArray()}
                    Write-Output "$fileName batch $batchNumber returned $($rows.Count) rows: $($columns -join ', ')"
                } while ($reader.NextResult())
            } finally {
                $reader.Close()
                $command.Dispose()
            }
        }
    }
    $record.success = $true
} catch {
    $record.error = $_.Exception.Message
    Write-Output "Validation failed: $($record.error)"
} finally {
    if ($null -ne $transaction) {
        try { $transaction.Rollback(); $record.rollback_completed = $true }
        catch { $record.rollback_error = $_.Exception.Message }
    }
    if ($record.rollback_completed) {
        $definitionsAfter = Get-ReportingDefinitions $connection
        $record.database_view_definitions_unchanged = ($definitionsBefore -ceq $definitionsAfter)
    }
    $connection.Dispose()
    $record.execution_finished_utc = [DateTime]::UtcNow.ToString('o')
    $record | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $outputPath -Encoding UTF8
}
if (-not $record.success -or -not $record.rollback_completed -or -not $record.database_view_definitions_unchanged) { exit 1 }
Write-Output "Validation executed successfully; SQL changes rolled back. Evidence: $outputPath"
