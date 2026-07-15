param(
  [string]$InstallDir = "$env:LOCALAPPDATA\Programs\EndVPN"
)

$ErrorActionPreference = 'Stop'

$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$zipPath = Join-Path $sourceRoot 'EndVPN-windows-release.zip'
$tempDir = Join-Path $env:TEMP ('EndVPNSetup_' + [guid]::NewGuid().ToString('N'))
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'EndVPN.lnk'
$startMenuDir = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\EndVPN'
$startMenuShortcut = Join-Path $startMenuDir 'EndVPN.lnk'
$exePath = Join-Path $InstallDir 'endvpn.exe'

if (-not (Test-Path -LiteralPath $zipPath)) {
  throw "Payload not found: $zipPath"
}

Get-Process -Name 'endvpn' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath $tempDir) {
  Remove-Item -LiteralPath $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Expand-Archive -LiteralPath $zipPath -DestinationPath $tempDir -Force
Copy-Item -Path (Join-Path $tempDir '*') -Destination $InstallDir -Recurse -Force

$uninstallScript = Join-Path $InstallDir 'uninstall.ps1'
@"
`$ErrorActionPreference = 'SilentlyContinue'
Get-Process -Name 'endvpn' | Stop-Process -Force
Remove-Item -LiteralPath '$desktopShortcut' -Force
Remove-Item -LiteralPath '$startMenuShortcut' -Force
Remove-Item -LiteralPath '$startMenuDir' -Recurse -Force
Remove-Item -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\EndVPN' -Recurse -Force
Remove-Item -LiteralPath '$InstallDir' -Recurse -Force
"@ | Set-Content -LiteralPath $uninstallScript -Encoding UTF8

function New-EndVpnShortcut {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Target
  )

  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($Path)
  $shortcut.TargetPath = $Target
  $shortcut.WorkingDirectory = Split-Path -Parent $Target
  $shortcut.IconLocation = "$Target,0"
  $shortcut.Description = 'EndVPN'
  $shortcut.Save()
}

New-Item -ItemType Directory -Force -Path $startMenuDir | Out-Null
New-EndVpnShortcut -Path $desktopShortcut -Target $exePath
New-EndVpnShortcut -Path $startMenuShortcut -Target $exePath

$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\EndVPN'
New-Item -Path $uninstallKey -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'DisplayName' -Value 'EndVPN' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'DisplayVersion' -Value '1.1.0' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'Publisher' -Value 'EndVPN' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'InstallLocation' -Value $InstallDir -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'DisplayIcon' -Value $exePath -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'UninstallString' -Value "powershell.exe -ExecutionPolicy Bypass -File `"$uninstallScript`"" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'NoModify' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name 'NoRepair' -Value 1 -PropertyType DWord -Force | Out-Null

Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $exePath

