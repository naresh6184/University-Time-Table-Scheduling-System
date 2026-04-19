; UniScheduler Inno Setup Installer Script

[Setup]
AppName=UniScheduler
AppVersion=1.2.0
DefaultDirName=C:\UniScheduler
DefaultGroupName=UniScheduler
; FIX 6: Replaced hardcoded "C:\Users\Nares\Desktop" with a portable relative path.
; The installer .exe will now be placed in an "dist_v120" folder next to this script,
; which works on any machine without modification.
OutputDir=dist_v120
OutputBaseFilename=UniScheduler_Setup_v1_2_0
Compression=lzma2
SolidCompression=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
SetupIconFile=frontend\windows\runner\resources\app_icon.ico
UninstallDisplayName=UniScheduler

[Files]
; Flutter frontend (compiled Windows app)
Source: "frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

; Python backend (PyInstaller onedir bundle)
Source: "dist\UniScheduler_Server\*"; DestDir: "{app}\server"; Flags: recursesubdirs createallsubdirs

[Icons]
; FIX 7: Added WorkingDir to all shortcuts so the app launches with the correct
; working directory. Without this, relative paths (e.g. finding the server in
; {app}\server) can silently break at runtime.
Name: "{userdesktop}\UniScheduler"; Filename: "{app}\UniScheduler.exe"; WorkingDir: "{app}"
Name: "{group}\UniScheduler"; Filename: "{app}\UniScheduler.exe"; WorkingDir: "{app}"
Name: "{group}\Uninstall UniScheduler"; Filename: "{uninstallexe}"

[Run]
; FIX 7 (cont): Added WorkingDir here too for the post-install launch.
Filename: "{app}\UniScheduler.exe"; WorkingDir: "{app}"; Description: "Launch UniScheduler"; Flags: nowait postinstall skipifsilent
