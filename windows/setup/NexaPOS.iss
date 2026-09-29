; Native installer: the app runtime is x64, but setup itself needs no .NET Framework.
; Build with ISCC /DAppVersion=... /DRuntimeDir=... /DOutputBase=... /O...
#ifndef AppVersion
  #error AppVersion must be supplied by the release workflow.
#endif
#ifndef RuntimeDir
  #error RuntimeDir must be supplied by the release workflow.
#endif
#ifndef OutputBase
  #error OutputBase must be supplied by the release workflow.
#endif

[Setup]
AppId=NexaPOS
AppName=NexaPOS
AppVersion={#AppVersion}
AppPublisher=NexaPOS
DefaultDirName={autopf}\NexaPOS
DefaultGroupName=NexaPOS
DisableDirPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=6.1
OutputBaseFilename={#OutputBase}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\nexapos_mobile.exe
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
WizardStyle=modern

[Files]
Source: "{#RuntimeDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autodesktop}\NexaPOS"; Filename: "{app}\nexapos_mobile.exe"; WorkingDir: "{app}"
Name: "{commonprograms}\NexaPOS\NexaPOS"; Filename: "{app}\nexapos_mobile.exe"; WorkingDir: "{app}"

; The old C# setup copied itself into Program Files. Its uninstall entry is
; obsolete after this native installer has registered its own uninstaller.
[InstallDelete]
Type: files; Name: "{app}\NexaPOS-Setup.exe"

[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\NexaPOS"; Flags: deletekey
Root: HKLM; Subkey: "Software\Classes\nexapos"; ValueType: string; ValueName: ""; ValueData: "URL:NexaPOS"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Classes\nexapos"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKLM; Subkey: "Software\Classes\nexapos\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\nexapos_mobile.exe"" ""%1"""
