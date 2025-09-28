param(
    [switch]$ShowLogs = $false,
    [switch]$CreateReleaseAfterCI, 
    [ValidateSet("Dev", "Dev0", "Dev1", "Dev2")]
    [string]$TargetStage
)

# === Validations ===
if ($CreateReleaseAfterCI -and -not $TargetStage) {
    throw "❌ The -TargetStage parameter is mandatory when -CreateReleaseAfterCI is specified."
}

# === Variables ===
$org = "Ceridian"
$project = "Sharptop"
$pipelineId = 5043
$pat = ""

validateAz.ps1;

# === Authenticate with PAT ===
$pat | az devops login --organization "https://dev.azure.com/$org" | Out-Null

# === Trigger pipeline ===
$response = az pipelines run `
    --id $pipelineId `
    --branch "dfid/poc/container-hardening/chainguard-img" `
    --org "https://dev.azure.com/$org" `
    --project $project `
    --output json | ConvertFrom-Json

$runId = $response.id
$buildNumber = $response.buildNumber
Write-Host "Pipeline run triggered. Run ID $runId BuildNumber: $buildNumber"

# === Function: Wait for pipeline ===
function Wait-ForPipelineCompletion {
    param($runId, $ShowLogs)

    $printedLogs = @{}
    do {
        $status = az pipelines runs show `
            --id $runId `
            --org "https://dev.azure.com/$org" `
            --project $project `
            --output json | ConvertFrom-Json

        $state = $status.status
        $result = $status.result

        if ($state -eq "completed") {
            if ($result -eq "succeeded") {
                Write-Host "Status: $state ($result)" -ForegroundColor Green
            } elseif ($result -eq "failed") {
                Write-Host "Status: $state ($result)" -ForegroundColor Red
            } else {
                Write-Host "Status: $state ($result)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Status: $state" -ForegroundColor Yellow
        }

        if ($ShowLogs) {
            # Get and stream logs
            $logsJson = az devops invoke `
                --org "https://dev.azure.com/$org" `
                --area build `
                --resource logs `
                --route-parameters project=$project buildId=$runId `
                --output json | ConvertFrom-Json

            foreach ($lg in $logsJson.value) {
                $logId = $lg.id
                $logContent = az devops invoke `
                    --org "https://dev.azure.com/$org" `
                    --area build `
                    --resource logs `
                    --route-parameters project=$project buildId=$runId logId=$logId `
                    --output json | ConvertFrom-Json

                $lines = $logContent.value -split "`n"
                $alreadyPrinted = if ($printedLogs.ContainsKey($logId)) { $printedLogs[$logId] } else { 0 }

                if ($lines.Length -gt $alreadyPrinted) {
                    $newLines = $lines[$alreadyPrinted..($lines.Length - 1)]
                    Write-Host "`n=== Log ID: $logId ($($lg.type)) [new output] ==="
                    $newLines | ForEach-Object { Write-Output $_ }
                    $printedLogs[$logId] = $lines.Length
                }
            }
        }

        Start-Sleep -Seconds 10
    } while ($state -ne "completed" -and $state -ne "cancelling" -and $state -ne "stopped")

    Write-Host "Pipeline finished with result: $result"
    return $result
}

# === Main execution ===
Write-Host "`n=== Monitoring Run $runId ==="
$result = Wait-ForPipelineCompletion -runId $runId -ShowLogs:$ShowLogs

if ($CreateReleaseAfterCI -and $result -eq "succeeded") {
    Write-Host "✅ Creating release for stage: $TargetStage"
    & "C:\Dayforce\Utils\triggerDfidReleasePipeline.ps1" -CalledFromScript -DfidCiBuildNumber $buildNumber -TargetStage $TargetStage -Pat $pat
}
elseif ($CreateReleaseAfterCI) {
    throw "❌ CI pipeline did not succeed. Release skipped."
}
