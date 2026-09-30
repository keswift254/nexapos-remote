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
; Administrative installs use the common desktop. Old C# installers created
; a per-user desktop shortcut, so upgrades first remove both possible legacy
; locations below and then create exactly one common-desktop shortcut.
Name: "{commondesktop}\NexaPOS"; Filename: "{app}\nexapos_mobile.exe"; WorkingDir: "{app}"
Name: "{commonprograms}\NexaPOS\NexaPOS"; Filename: "{app}\nexapos_mobile.exe"; WorkingDir: "{app}"

; Always start NexaPOS after setup completes, including silent in-app updates.
; runasoriginaluser prevents the elevated installer from starting the POS as admin.
[Run]
Filename: "{app}\nexapos_mobile.exe"; WorkingDir: "{app}"; Flags: nowait runasoriginaluser

; Clean up the legacy setup copy and shortcut locations before recreating the
; current shortcuts. This prevents upgraded PCs from showing two NexaPOS icons.
[InstallDelete]
Type: files; Name: "{app}\NexaPOS-Setup.exe"
Type: files; Name: "{userdesktop}\NexaPOS.lnk"
Type: files; Name: "{commondesktop}\NexaPOS.lnk"
Type: files; Name: "{userprograms}\NexaPOS\NexaPOS.lnk"
Type: files; Name: "{commonprograms}\NexaPOS\NexaPOS.lnk"

[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\NexaPOS"; Flags: deletekey
Root: HKLM; Subkey: "Software\Classes\nexapos"; ValueType: string; ValueName: ""; ValueData: "URL:NexaPOS"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Classes\nexapos"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKLM; Subkey: "Software\Classes\nexapos\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\nexapos_mobile.exe"" ""%1"""
