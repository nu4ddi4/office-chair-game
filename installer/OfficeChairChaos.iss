#ifndef GameVersion
  #define GameVersion "0.1.1"
#endif
#ifndef BuildDir
  #define BuildDir "..\chaos-dist"
#endif

[Setup]
AppId=OfficeChairChaos
AppName=김 대리, 나 좀 밀어봐
AppVersion={#GameVersion}
AppPublisher=Office Chair Chaos contributors
DefaultDirName={localappdata}\Programs\OfficeChairChaos
DefaultGroupName=김 대리, 나 좀 밀어봐
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
OutputDir={#BuildDir}
OutputBaseFilename=OfficeChairChaos-Setup
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\OfficeChairChaos.exe
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#GameVersion}.0

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "바탕 화면에 바로 가기 만들기"; Flags: unchecked

[Files]
Source: "{#BuildDir}\OfficeChairChaos.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\LICENSES.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\office-chair.install.json"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\김 대리, 나 좀 밀어봐"; Filename: "{app}\OfficeChairChaos.exe"
Name: "{autodesktop}\김 대리, 나 좀 밀어봐"; Filename: "{app}\OfficeChairChaos.exe"; Tasks: desktopicon; WorkingDir: "{app}"

[Run]
Filename: "{app}\OfficeChairChaos.exe"; Description: "게임 실행"; Flags: nowait postinstall skipifsilent
