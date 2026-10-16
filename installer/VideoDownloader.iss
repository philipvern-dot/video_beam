; Builds video_beam.exe, the setup program attached to a GitHub Release.
; The tool programs are not in git. This script reads them from the working copy.
; Compile with Inno Setup 6:
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" VideoDownloader.iss

#define AppVersion "1.0.3"
#define Repo ".."
#define ToolExe "E:\Programming\video_beam\tools"

[Setup]
AppId={{8F3A1C2E-6B47-4D19-9E5A-7C0D4B8E2F61}
AppName=Video Beam
AppVersion={#AppVersion}
AppPublisher=Video Beam
AppCopyright=Copyright (c) 2026 Philip Miller
DefaultDirName={localappdata}\Programs\Video Beam
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#Repo}
OutputBaseFilename=video_beam
Compression=lzma2
SolidCompression=yes
LZMAUseSeparateProcess=yes
WizardStyle=modern
Uninstallable=yes
UninstallDisplayName=Video Beam
UninstallDisplayIcon={app}\vb-icon.ico
SetupIconFile={#Repo}\vb-icon.ico
VersionInfoVersion=1.0.3.0
VersionInfoProductName=Video Beam
VersionInfoCompany=Video Beam
VersionInfoDescription=Installs Video Beam and the tools it needs
CloseApplications=yes

[Files]
Source: "{#Repo}\app\VideoBeam.ps1"; DestDir: "{app}\app"
Source: "{#Repo}\app\launch.vbs"; DestDir: "{app}\app"
Source: "{#Repo}\app\version.txt"; DestDir: "{app}\app"
Source: "{#Repo}\app\blocked-sites.md"; DestDir: "{app}\app"; Flags: onlyifdoesntexist
Source: "{#Repo}\LICENSE"; DestDir: "{app}"
Source: "{#Repo}\vb-icon.ico"; DestDir: "{app}"
Source: "{#Repo}\tools\FFmpeg-LICENSE.txt"; DestDir: "{app}\tools"
Source: "{#ToolExe}\yt-dlp.exe"; DestDir: "{app}\tools"
Source: "{#ToolExe}\ffmpeg.exe"; DestDir: "{app}\tools"
Source: "{#ToolExe}\ffprobe.exe"; DestDir: "{app}\tools"
Source: "{#ToolExe}\deno.exe"; DestDir: "{app}\tools"

[Tasks]
Name: startmenuicon; Description: "Create a Start menu shortcut"; GroupDescription: "Shortcuts:"; Flags: checkedonce
Name: desktopicon; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Icons]
Name: "{autoprograms}\Video Beam"; Filename: "{sys}\wscript.exe"; Parameters: "//nologo ""{app}\app\launch.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\vb-icon.ico"; Comment: "Download videos and playlists as MP4 or MP3 files"; Tasks: startmenuicon
Name: "{autodesktop}\Video Beam"; Filename: "{sys}\wscript.exe"; Parameters: "//nologo ""{app}\app\launch.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\vb-icon.ico"; Comment: "Download videos and playlists as MP4 or MP3 files"; Tasks: desktopicon

[InstallDelete]
Type: files; Name: "{autoprograms}\Video Beam.lnk"
Type: files; Name: "{autodesktop}\Video Beam.lnk"
Type: files; Name: "{autoprograms}\Video Downloader.lnk"
Type: files; Name: "{autodesktop}\Video Downloader.lnk"

[Run]
Filename: "{sys}\wscript.exe"; Parameters: "//nologo ""{app}\app\launch.vbs"""; WorkingDir: "{app}"; Description: "Open Video Beam"; Flags: postinstall nowait skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\Video Beam.lnk"
Type: files; Name: "{app}\Video Downloader.lnk"
