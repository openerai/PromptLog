#define MyAppName "Prompt Log"
#define MyAppVersion "0.4.0"
#define MyAppPublisher "Prompt Log"
#define MyAppExeName "PromptLog.exe"

[Setup]
AppId={{7D519580-54C0-48EF-8537-8B2B0E5F7BA4}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\Prompt Log
DefaultGroupName=Prompt Log
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=PromptLog-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\build\windows\PromptLog.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
CloseApplications=yes
AppMutex=PromptLog.Application
ArchitecturesAllowed=x64compatible
MinVersion=10.0

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "바탕 화면에 바로가기 만들기"; GroupDescription: "추가 바로가기:"; Flags: unchecked

[Files]
Source: "..\build\windows\PromptLog.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Prompt Log"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Prompt Log 제거"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Prompt Log"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Prompt Log 실행"; Flags: nowait postinstall skipifsilent
