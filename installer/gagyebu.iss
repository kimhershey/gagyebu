; 가계부 Windows 설치 파일 (Inno Setup 6.3 이상)
;
; 만드는 법(저장소 맨 위 폴더에서. 자세한 것은 installer/README.md):
;   ISCC.exe /DAppVersion=0.1.0 installer\gagyebu.iss
;
; - 관리자 권한 없이 현재 사용자의 폴더(%LOCALAPPDATA%\Programs\Gagyebu)에 설치한다.
; - 앱 로그인에서 돌아올 때 쓰는 URL 스킴(io.github.kimhershey.gagyebu)을 현재 사용자의
;   레지스트리(HKCU)에 등록한다. 관리자 권한 없이 쓸 수 있는 곳이 HKCU뿐이다.
; - 이 파일은 BOM 없는 UTF-8이다. Inno Setup 6.3부터 그대로 읽는다.

; 버전은 명령줄에서 받는다. 스크립트에 적어 두면 app/pubspec.yaml과 어긋나기 쉽다.
#ifndef AppVersion
#error 버전을 /DAppVersion=1.2.3 꼴로 넘겨야 한다.
#endif

#define AppName "가계부"
#define AppExeName "gagyebu.exe"
#define AppUrlScheme "io.github.kimhershey.gagyebu"
#define AppUrl "https://github.com/kimhershey/gagyebu"
; flutter build windows --release가 만든 실행 폴더. 이 스크립트가 있는 폴더가 기준이다.
#define BuildDir "..\app\build\windows\x64\runner\Release"

#if !FileExists(AddBackslash(SourcePath) + AddBackslash(BuildDir) + AppExeName)
#error 빌드 산출물이 없다. app 폴더에서 flutter build windows --release를 먼저 돌린다.
#endif

[Setup]
; AppId는 이 앱의 설치 기록을 가리키는 값이다. 바꾸면 새 버전이 기존 설치를 덮어쓰지 못하고 따로 깔린다.
AppId={{6F0C1B1E-5B0A-4C53-9E55-0E6B6C3B8A27}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=kimhershey
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases

; 관리자 권한을 묻지 않는다. {autopf}는 사용자 폴더(%LOCALAPPDATA%\Programs)가 된다.
; 설치 폴더 이름은 영문으로 둔다(경로에 한글이 없어야 탈이 적다).
PrivilegesRequired=lowest
DefaultDirName={autopf}\Gagyebu
DisableProgramGroupPage=yes
UsePreviousAppDir=yes

; Flutter의 Windows 앱은 Windows 10 이상, 64비트에서 돈다. ARM64 Windows 11은 x64 앱을 돌릴 수 있다.
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; 결과물: app\build\installer\gagyebu-setup.exe
; 파일 이름에 버전을 넣지 않는다. Releases의 내려받기 주소가 버전마다 같은 꼴이 되게 하려는 것이다.
OutputDir=..\app\build\installer
OutputBaseFilename=gagyebu-setup
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; 새 버전을 깔 때 실행 중인 앱을 닫는다(파일이 잠겨 있으면 덮어쓰지 못한다).
CloseApplications=yes

[Languages]
; 한국어 파일이 있으면 먼저 둔다(앞에 있는 언어가 기본이다). 없는 판에서도 스크립트가 깨지지 않게 한다.
#if FileExists(AddBackslash(CompilerPath) + "Languages\Korean.isl")
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
#endif
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 실행 폴더 전체(실행 파일, flutter_windows.dll, 플러그인 DLL, data 폴더).
; VC++ 런타임 DLL도 이 폴더에 넣어 두면 함께 들어간다(installer/README.md).
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; URL 스킴. 브라우저가 io.github.kimhershey.gagyebu://login-callback?... 을 열면 Windows가 아래 명령으로
; 앱을 띄우고 주소를 첫 인자로 넘긴다. 제거할 때 키를 통째로 지운다.
Root: HKCU; Subkey: "Software\Classes\{#AppUrlScheme}"; ValueType: string; ValueName: ""; ValueData: "URL:{#AppName}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\{#AppUrlScheme}"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\{#AppUrlScheme}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"
Root: HKCU; Subkey: "Software\Classes\{#AppUrlScheme}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; 제거 프로그램은 설치한 파일과 위 레지스트리 키만 지운다. 사용자의 가계부 데이터(앱이 따로 두는
; 로컬 DB)는 건드리지 않는다. 다시 깔면 그대로 이어서 쓸 수 있어야 하기 때문이다.
