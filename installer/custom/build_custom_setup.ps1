$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$artifactsDir = Join-Path $root 'build\release_artifacts'
$publishDir = Join-Path $root 'build\custom_installer'
$project = Join-Path $PSScriptRoot 'EndVPN.Installer.csproj'
$issScript = Join-Path $root 'installer\windows\EndVPN.iss'
$brandingScript = Join-Path $root 'installer\windows\build_branding.ps1'
$coreSetup = Join-Path $artifactsDir 'EndVPNCoreSetup.exe'
$result = Join-Path $artifactsDir 'EndVPNSetup.exe'
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

New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $brandingScript
if ($LASTEXITCODE -ne 0) {
  throw "Branding build failed with exit code $LASTEXITCODE"
}

& $compiler /Qp /DMyOutputBaseFilename=EndVPNCoreSetup $issScript
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup failed with exit code $LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $coreSetup)) {
  throw "Core setup was not created: $coreSetup"
}

dotnet publish $project `
  -c Release `
  -r win-x64 `
  --self-contained true `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:EnableCompressionInSingleFile=true `
  -p:PublishTrimmed=false `
  -p:PublishReadyToRun=false `
  -o $publishDir

if ($LASTEXITCODE -ne 0) {
  throw "Custom installer build failed with exit code $LASTEXITCODE"
}

$published = Join-Path $publishDir 'EndVPNSetup.exe'
if (-not (Test-Path -LiteralPath $published)) {
  throw "Published setup was not found: $published"
}

Copy-Item -LiteralPath $published -Destination $result -Force
Remove-Item -LiteralPath $coreSetup -Force
Write-Host "Built $result"
