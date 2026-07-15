$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$artifactsDir = Join-Path $root 'build\release_artifacts'
$payloadZip = Join-Path $artifactsDir 'EndVPN-windows-release.zip'
$localPayload = Join-Path $PSScriptRoot 'EndVPN-windows-release.zip'
$sedPath = Join-Path $PSScriptRoot 'EndVPNSetup.SED'

if (-not (Test-Path -LiteralPath $payloadZip)) {
  throw "Windows release zip not found: $payloadZip"
}

Copy-Item -LiteralPath $payloadZip -Destination $localPayload -Force
Start-Process -FilePath 'iexpress.exe' -ArgumentList @('/N', '/Q', $sedPath) -Wait -NoNewWindow

$setupPath = Join-Path $artifactsDir 'EndVPNSetup.exe'
if (-not (Test-Path -LiteralPath $setupPath)) {
  throw "Setup was not created: $setupPath"
}

Write-Host "Built $setupPath"

