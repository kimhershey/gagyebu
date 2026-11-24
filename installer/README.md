# installer/

Windows 설치 파일을 만드는 [Inno Setup](https://jrsoftware.org/isinfo.php) 스크립트다. 릴리스 작업(`.github/workflows/release.yml`)이 `v*` 태그마다 이 스크립트로 `gagyebu-setup.exe`를 만들어 GitHub Releases에 올린다. 아래는 PC에서 직접 만들어 볼 때의 순서다.

## 설치 파일이 하는 일

- 관리자 권한을 묻지 않고 현재 사용자의 폴더(`%LOCALAPPDATA%\Programs\Gagyebu`)에 설치한다.
- 시작 메뉴에 "가계부" 바로가기를 만든다(바탕 화면 바로가기는 고를 수 있다).
- URL 스킴 `io.github.kimhershey.gagyebu`를 현재 사용자의 레지스트리(`HKCU\Software\Classes`)에 등록한다. 브라우저에서 로그인한 뒤 `io.github.kimhershey.gagyebu://login-callback`으로 앱에 돌아올 때 쓴다(`docs/SPEC.md` 4.3).
- "앱 및 기능"에 제거 프로그램을 등록한다. 제거하면 설치한 파일과 위 레지스트리 키를 지운다. 가계부 데이터(앱이 따로 두는 로컬 DB)는 지우지 않는다.
- 같은 `AppId`로 다시 설치하면 기존 설치를 덮어쓴다(업데이트).

## 로컬에서 만들기

Windows PC에서 한다. Flutter 3.50.0과 Visual Studio의 "C++를 사용한 데스크톱 개발", Inno Setup 6.3 이상이 필요하다(`winget install JRSoftware.InnoSetup` 또는 `choco install innosetup`).

1. 앱을 빌드한다. 서버 주소와 공개 키를 넣지 않으면 로그인이 없는 개발용 앱이 된다(저장소 `README.md`의 "개발").

   ```powershell
   cd app
   flutter pub get
   flutter build windows --release
   ```

2. VC++ 런타임 DLL 세 개를 실행 폴더에 넣는다. 이 DLL이 없는 PC에서는 앱이 켜지지 않는다. Visual Studio를 깐 PC에는 아래 폴더에 있다.

   ```powershell
   $release = "build\windows\x64\runner\Release"
   foreach ($name in "msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll") {
     Copy-Item (Join-Path $env:SystemRoot "System32\$name") $release
   }
   ```

3. 저장소 맨 위 폴더에서 설치 파일을 만든다. 버전은 `app/pubspec.yaml`의 `version`에서 `+` 앞부분을 넘긴다.

   ```powershell
   cd ..
   & "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DAppVersion=0.1.0 installer\gagyebu.iss
   ```

   결과물은 `app\build\installer\gagyebu-setup.exe`다. Inno Setup을 다른 곳에 깔았으면 그 폴더의 `ISCC.exe`를 쓴다.

`/DAppVersion=`을 빼거나 빌드 산출물(`app\build\windows\x64\runner\Release\gagyebu.exe`)이 없으면 스크립트가 무엇이 빠졌는지 알리고 멈춘다.

## 알아 둘 것

- 설치 파일에 코드 서명을 하지 않는다. 내려받아 실행하면 Windows SmartScreen이 "알 수 없는 게시자"라고 경고한다. "추가 정보 → 실행"으로 넘어갈 수 있다.
- 파일 이름에 버전을 넣지 않는다(`gagyebu-setup.exe`). Releases의 내려받기 주소가 버전마다 같은 꼴이 되게 하려는 것이다.
- `gagyebu.iss`의 `AppId`는 바꾸지 않는다. 바꾸면 새 버전이 기존 설치를 덮어쓰지 못하고 따로 깔린다.
- 한국어 안내문은 Inno Setup에 들어 있는 `Languages\Korean.isl`을 쓴다. 이 파일이 없는 판에서는 영어로만 만들어진다.

## 라이선스

- Inno Setup은 설치 파일을 만드는 도구이고 앱 안에 들어가지 않는다. 라이선스(Inno Setup License)는 상업적 이용을 포함해 쓰고 고치고 다시 배포하는 것을 허용하며 소스 공개 의무가 없다. 조건은 저작권 표시를 지우지 않는 것과 출처를 속이지 않는 것이다. 상업적으로 쓰는 경우에는 만든 쪽이 유료 라이선스 구매를 요청하고 있다.
- VC++ 런타임 DLL은 Microsoft의 재배포 가능 파일이다. 오픈 소스는 아니지만 앱과 함께 배포하는 것이 허용되고 소스 공개 의무가 없다.
