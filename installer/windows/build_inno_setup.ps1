$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$scriptPath = Join-Path $PSScriptRoot 'EndVPN.iss'
$brandingScript = Join-Path $PSScriptRoot 'build_branding.ps1'
$outputPath = Join-Path $root 'build\release_artifacts\EndVPNSetup.exe'
$compilerPaths = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
$compiler = $compilerPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $compiler) {
  throw 'Inno Setup 6 is not installed.'
}
if (-not (Test-Path -LiteralPath (Join-Path $releaseDir 'endvpn.exe'))) {
  throw "Windows release is missing: $releaseDir"
}

New-Item -ItemType Directory -Force -Path (Split-Path $outputPath) | Out-Null
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $brandingScript
if ($LASTEXITCODE -ne 0) {
  throw "Branding build failed with exit code $LASTEXITCODE"
}
& $compiler /Qp $scriptPath
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup failed with exit code $LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $outputPath)) {
  throw "Setup was not created: $outputPath"
}

Write-Host "Built $outputPath"
