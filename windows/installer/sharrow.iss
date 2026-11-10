; Inno Setup 6 script. Build with:
;   iscc /DAppVersion=1.0.0 windows\installer\sharrow.iss
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{6F1D6B0E-3C1A-4E57-9A63-2B8F6A1C9D42}
AppName=Sharrow
AppVersion={#AppVersion}
AppPublisher=Sharrow
AppPublisherURL=https://sharrow.app
DefaultDirName={autopf}\Sharrow
DefaultGroupName=Sharrow
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=Sharrow-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\sharrow.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=force

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Sharrow"; Filename: "{app}\sharrow.exe"; AppUserModelID: "App.Sharrow.Desktop"
Name: "{autodesktop}\Sharrow"; Filename: "{app}\sharrow.exe"; Tasks: desktopicon; AppUserModelID: "App.Sharrow.Desktop"

[Run]
Filename: "{app}\sharrow.exe"; Description: "{cm:LaunchProgram,Sharrow}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /IM xray.exe /F"; Flags: runhidden; RunOnceId: "KillXray"
Filename: "{cmd}"; Parameters: "/C taskkill /IM sharrow.exe /F"; Flags: runhidden; RunOnceId: "KillApp"
