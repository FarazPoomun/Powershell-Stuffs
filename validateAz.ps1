
# === Ensure az CLI exists ===
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI (az) is not installed. Please install it first: https://aka.ms/installazurecliwindows"
    exit 1
}

# === Ensure azure-devops extension is installed ===
$ext = az extension list --query "[?name=='azure-devops']" --output tsv

if (-not $ext) {
    Write-Host "Azure DevOps CLI extension not found. Installing..."
    $indexUrl = "https://raw.githubusercontent.com/Azure/azure-cli-extensions/main/src/index.json"
    $indexFile = "$env:TEMP\azext_index.json"

    Write-Host "Fetching extension index..."
    Invoke-WebRequest -Uri $indexUrl -OutFile $indexFile -UseBasicParsing

    $index = Get-Content $indexFile -Raw | ConvertFrom-Json
    $devopsVersions = $index.extensions."azure-devops"

    if (-not $devopsVersions) {
        throw "Could not find azure-devops in index.json"
    }

    $latest = $devopsVersions | Sort-Object { [version]($_.metadata.version) } -Descending | Select-Object -First 1
    $downloadUrl = $latest.downloadUrl
    $filename = $latest.filename
    $localFile = Join-Path $env:TEMP $filename

    Write-Host "Latest Azure DevOps extension: $($latest.metadata.version)"
    Write-Host "Downloading from $downloadUrl ..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $localFile -UseBasicParsing

    Write-Host "Installing Azure DevOps extension..."
    az extension add --source $localFile --yes
    Write-Host "Azure DevOps CLI extension installed successfully!"
} else {
    Write-Host "Azure DevOps CLI extension is already installed."
}