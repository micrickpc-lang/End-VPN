#define MyAppName "END VPN"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "END VPN"
#define MyAppExeName "endvpn.exe"
#ifndef MyOutputBaseFilename
#define MyOutputBaseFilename "EndVPNSetup"
#endif

[Setup]
AppId={{4F60AA01-2B91-4B5D-9FC8-FA52C175EF57}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\END VPN
DefaultGroupName=END VPN
DisableProgramGroupPage=yes
OutputDir=..\..\build\release_artifacts
OutputBaseFilename={#MyOutputBaseFilename}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
LicenseFile=OFFER_RU.txt
WizardImageFile=branding\wizard-large.bmp
WizardSmallImageFile=branding\wizard-small.bmp
WizardImageStretch=yes
WizardImageAlphaFormat=defined
WizardImageBackColor=$080605
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
ShowLanguageDialog=no
LanguageDetectionMethod=uilanguage
MinVersion=10.0.17763

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\END VPN"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\END VPN"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCR; Subkey: "endvpn"; ValueType: string; ValueName: ""; ValueData: "URL:END VPN Payment"; Flags: uninsdeletekey
Root: HKCR; Subkey: "endvpn"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "endvpn\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCR; Subkey: "endvpn\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,END VPN}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM endvpn.exe"; Flags: runhidden; RunOnceId: "StopEndVPN"
