param(
    [Parameter(Mandatory = $true)][string]$DfidCiBuildNumber,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Dev", "Dev0", "Dev1", "Dev2")]
    [string]$TargetStage,
    [Parameter(Mandatory = $true)][string]$Pat,
    [Parameter(Mandatory = $false)][string]$DfidInfraCommit = "fc48829e5", # Not validating so make sure right value is passed
    [switch]$CalledFromScript = $false
)
$Org = "Ceridian"
$Project = "Sharptop"
$ReleaseDefId = 930
$TargetStageFull = "$TargetStage | Pre deployment"

if (!$CalledFromScript) {
    validateAz.ps1
    if ($Pat) {
        $Pat | az devops login --organization "https://dev.azure.com/$Org" | Out-Null
    }
}

# === Get build artifact by BuildNumber ===
$build = az pipelines build list `
    --project $Project `
    --org "https://dev.azure.com/$Org" `
    --query "[?buildNumber=='$DfidCiBuildNumber'] | [-1]" `
    --output json | ConvertFrom-Json

if (-not $build) {
    throw "Could not find build with number $DfidCiBuildNumber"
}

$artifactAlias = $build.definition.name
$artifactVersionId = $build.id
Write-Host "Found build artifact: $artifactAlias (ID: $artifactVersionId)"

# === Fetch release definition ===
$releaseDef = az devops invoke `
  --area release `
  --resource definitions `
  --route-parameters project=$Project definitionId=$ReleaseDefId `
  --org https://dev.azure.com/$Org `
  --api-version '7.1-preview' `
  --output json | ConvertFrom-Json

# === Match target stage ===
$stage = $releaseDef.environments | Where-Object { $_.name -eq $TargetStageFull }
if (-not $stage) {
    throw "Stage '$TargetStageFull' not found."
}
Write-Host "Targeting stage: $TargetStageFull (ID: $($stage.id))"

# === Build release body ===
$releaseBody = @{
    definitionId = $ReleaseDefId
    description  = "Automated release for build $DfidCiBuildNumber"
    artifacts    = @(
        @{
            alias = $artifactAlias
            instanceReference = @{
                id   = $artifactVersionId
                name = $DfidCiBuildNumber
            }
        },
        @{
            alias = "_dayforce-identity-infrastructure"
            instanceReference = @{
                id   = $DfidInfraCommit
                name = $DfidInfraCommit
            }
        }
    )
    environmentsMetadata = @(
        @{
            definitionEnvironmentId = $stage.id
            currentReleaseAction    = "deploy"
        }
    )
}

# Write JSON to temp file
$releaseBodyJson = $releaseBody | ConvertTo-Json -Depth 10 -Compress
$tempFile = [System.IO.Path]::GetTempFileName()
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tempFile, $releaseBodyJson, $utf8NoBom)

# === Trigger release (create + deploy target stage) ===
$release = az devops invoke `
    --area release `
    --resource releases `
    --route-parameters project=$Project `
    --org https://dev.azure.com/$Org `
    --api-version '7.1-preview' `
    --http-method POST `
    --in-file $tempFile `
    --output json | ConvertFrom-Json

Remove-Item $tempFile -Force

$releaseId = $release.id
Write-Host "Release created. ID: $releaseId"

$releaseEnv = $release.environments | Where-Object { $_.name -eq $TargetStageFull }
if (-not $releaseEnv) {
    throw "Target stage '$TargetStageFull' not found in created release"
}

$releaseEnvId = $releaseEnv.id

$patToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
$headers = @{
    Authorization = "Basic $patToken"
    Accept        = "application/json; api-version=7.1-preview.6"
}

# === Using REST because az devops is not liking this part :( ===
$envUri  = "https://vsrm.dev.azure.com/$Org/$Project/_apis/release/releases/$releaseId/environments/$releaseEnvId"
$envBody = @{ status = "inProgress" } | ConvertTo-Json -Depth 5

Invoke-RestMethod `
    -Uri $envUri `
    -Method Patch `
    -Headers $headers `
    -Body $envBody `
    -ContentType "application/json" | Out-Null

Write-Host "Deployment for stage: $TargetStageFull (EnvID: $releaseEnvId) done"  -ForegroundColor Green

