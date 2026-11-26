# 인계: 다음에 할 수정 사항 세 가지

## 무엇을, 왜

기준: 2026-11-25. 사용자가 PC 앱(v0.1.1)을 써 보고 세 가지를 지적했다. 이 문서는 그 수정을 맡을 다음 작업자(에이전트)의 작업 지시서다. 아직 코드는 고치지 않았다. 끝낸 항목은 이 문서에서 지우고 [오류 기록](ERRORS.md)의 1장으로 옮긴다.

| # | 지적 | 원인 | 크기 |
| --- | --- | --- | --- |
| A | Google 로그인을 마쳐도 앱으로 돌아오지 않는다 | 서버(Supabase)의 Redirect URLs에 앱 주소가 없다. 앱은 실패를 알리지 않는다 | 설정 1분 + 코드 중간 |
| B | AI 모델 화면의 모델 줄이 제각각 가운데로 쏠려 있다 | 줄을 담는 `Column`에 정렬을 주지 않았다 | 한 줄 |
| C | 엔진 주소를 손으로 적게 하지 말고, 앱이 엔진을 스스로 띄워 주소를 잡아야 한다 | 지금은 앱 안의 엔진과 "직접 띄운 서버의 주소 칸"뿐이다. 사용자가 **앱이 `llama-server`를 띄우는 방식**을 골랐다 | 큼 |

순서는 B → A → C를 권한다(작은 것부터, C는 따로 올린다).

---

## A. Google 로그인이 앱으로 돌아오지 않는다

**확인한 것**: 로그인 뒤 브라우저에 가계부 웹 페이지(kimhershey.github.io/gagyebu)가 열린다(사용자 확인). 앱은 돌아올 주소로 `io.github.kimhershey.gagyebu://login-callback`을 보내는데(`app/lib/data/server/supabase_connection.dart:16`, `:155–170`), Supabase는 이 주소가 Redirect URLs 목록에 없으면 조용히 Site URL(웹 페이지)로 돌려보낸다. 앱의 나머지는 갖춰져 있다: Windows 실행 파일이 받은 주소를 실행 중인 창에 넘기고(`app/windows/runner/main.cpp`의 `SendAppLinkToInstance`), 설치 파일이 URL 스킴을 등록하고(`installer/gagyebu.iss` `[Registry]`), `supabase_flutter`가 `code`를 세션으로 바꾼다.

### A1. 서버 설정 (사용자가 직접)

Supabase 대시보드 → Authentication → URL Configuration → **Redirect URLs**에 한 줄을 더한다. Android 앱도 같은 주소를 쓴다.

```
io.github.kimhershey.gagyebu://login-callback
```

다음 에이전트는 이 설정을 바꿀 수 없다. 사용자에게 했는지 먼저 묻고, PC에서 다시 로그인한 결과를 받는다.

### A2. 앱이 로그인 실패를 삼키지 않는다

`SupabaseAuthService`가 로그인 흐름의 오류를 두 군데서 버린다(`supabase_connection.dart:100–103`의 `onError: (Object _) {}`, `:126–129`의 `handleError`).

- `AuthService`(`app/lib/data/server/server_connection.dart`)에 로그인 실패를 알리는 흐름을 더한다(예: `Stream<AuthFailure> get signInFailures`). 세션 갱신 실패처럼 로그인과 상관없는 오류는 지금처럼 넘긴다.
- `SyncController`(`app/lib/app/sync_controller.dart`)가 듣고, 로그인 화면(`app/lib/features/auth/auth_screen.dart`)이 기존 `_error` 자리에 "로그인을 마치지 못했습니다. 다시 시도해 주세요."를 보여 준다.

### A3. 브라우저로 나간 뒤 "기다리는 중"

- Windows · Android에서 브라우저를 연 뒤 로그인 화면에 안내를 띄운다: "브라우저에서 로그인을 마치면 이 창으로 돌아옵니다. 브라우저가 '가계부를 여시겠습니까'라고 물으면 열기를 누르세요." 단추는 "브라우저 다시 열기", "취소".
- 60초가 지나면 한 줄을 더한다: "돌아오지 않으면 브라우저에 무엇이 보이는지 확인해 주세요. 웹 가계부가 열렸다면 서버에 앱 주소가 등록되지 않은 것입니다."
- 로그인되면 사라진다. 웹에서는 쓰지 않는다.

### A4. 웹이 남의 로그인으로 들어왔을 때 알린다

설정이 빠지면 브라우저가 웹 페이지에 `?code=…`를 달고 온다. 웹은 그 코드를 세션으로 바꿀 수 없다.

- 첫 화면(`app/lib/features/auth/welcome_screen.dart`)이 A2의 흐름을 듣고 알린다: "이 로그인은 다른 앱에서 시작된 것이라 여기서 끝낼 수 없습니다. 시작한 앱으로 돌아가 다시 시도해 주세요."
- 주소에서 `code`를 지운다.

### A5. Windows 앱이 URL 스킴을 스스로 등록한다 (권장, 이번 원인은 아님)

- 앱을 켤 때 `HKCU\Software\Classes\io.github.kimhershey.gagyebu`가 없거나 다른 실행 파일을 가리키면 지금 실행 파일로 고쳐 쓴다. 값은 `installer/gagyebu.iss` 81–87줄과 같게.
- `app/lib/platform/`에 새 파일. 레지스트리 접근은 창구 뒤에 두어 시험에서 가짜로 바꾼다. `win32_registry`(BSD-3, 이미 의존성 트리에 있다)를 직접 의존성으로. 실패해도 앱은 뜬다.

### A6. 문서

`supabase/README.md`의 설정 점검표에 Redirect URLs 두 줄(웹, 앱)과 빠졌을 때의 증상. `docs/ERRORS.md`, `docs/SPEC.md` 4.3.

---

## B. AI 모델 화면의 모델 줄을 왼쪽으로 맞춘다

`app/lib/features/models/models_screen.dart:246`의 `Column(children: [...])`에 정렬이 없어, 폭이 제각각인 `_ModelTile`이 가운데로 온다.

- 그 `Column`에 `crossAxisAlignment: CrossAxisAlignment.stretch`를 준다(`_OrphanTile`도 같은 `Column` 안이다).
- 시험(`test/features/models_screen_test.dart`): 모든 모델 줄의 왼쪽 끝이 카드 제목 "모델"의 왼쪽 끝과 같다. 네 화면 크기에서.
- 같은 화면에서 함께 볼 것: 크기 표기가 1024 단위인데 "GB"라고 적는다(1.28GB 파일이 "1.19GB"). 문서(`docs/MODELS.md`)와 다르다. 어느 한쪽으로 맞춘다.

---

## C. 앱이 `llama-server`를 띄우고 주소를 스스로 잡는다 (Windows)

### 진행 (2026-11-26)

**끝낸 것**: 앱이 `llama-server`를 스스로 띄우는 뼈대. Windows에서 받아 둔 글 모델이 있으면 앱을 켤 때 서버를 띄우고(Vulkan → 안 되면 CPU), 빈 포트와 임의의 키를 스스로 정하고, 준비되면 그 서버로 읽고, 15분 쉬면 내렸다가 다음 요청에서 다시 띄운다. 띄우지 못하면 앱 안의 엔진으로 물러난다. 설정 → AI 모델에 "엔진" 카드(실행 중 · 백엔드 · 주소 · 올라간 모델)가 생겼다. 앱이 죽으면 서버도 함께 끝나게 했다(작업 개체). 실행 파일은 판 `b12774`를 해시와 함께 고정해 설치 파일에 넣는다(`installer/fetch_engines.ps1`).

- 코드: `app/lib/ai/llm/llama_server.dart`, `app/lib/app/engine_providers.dart`, `app/lib/app/background_jobs.dart`, `app/lib/features/models/models_screen.dart`의 `_EngineCard`, `app/windows/runner/main.cpp`
- 확인: 같은 판의 Linux 실행 파일과 실제 모델로 통합 시험 통과(`app/test/integration/llama_server_test.dart`). **Windows에서는 돌려 보지 못했다.**

**남은 것**: 이미지 요청을 서버로 보내기(지금은 앱 안의 엔진이 읽는다), "고급" 설정(실행 파일 직접 지정 · 쉬는 시간 · 자동 시작 끄기, 주소 칸을 고급으로 옮기기), 엔진 카드의 [다시 시작], 평가 도구의 `--sidecar`, 가짜 프로세스로 하는 상태 기계 시험.

### 목표

사용자가 손댈 것이 없다. 모델을 받아 두면, 앱이 켜질 때 엔진을 띄우고, 빈 포트를 잡고, 준비되면 쓰고, 쉬면 내리고, 앱을 끄면 함께 끈다. 사용자가 보여 준 화면(다른 앱의 엔진 카드: 실행 중 · 버전 · 백엔드 Vulkan · 127.0.0.1:포트 · 로드된 모델 · 자동 시작 · 유휴 슬립)이 본보기다.

### 정한 것

| | |
| --- | --- |
| 대상 | Windows만. Android는 지금의 앱 안의 엔진(`llamadart`)을 그대로 쓴다 |
| Windows의 순서 | ① 앱이 띄운 `llama-server` → ② 띄우지 못하면 앱 안의 엔진(이미 있는 코드)으로 물러난다. 사용자가 "다른 서버 주소"를 적어 두었으면 그것이 맨 먼저다(지금과 같다) |
| 실행 파일 | llama.cpp의 공식 릴리스(MIT)에서 **특정 판을 고정**해 받고 SHA-256을 확인해 **설치 파일에 넣는다**(`engines/vulkan/`, `engines/cpu/`). 설치 파일이 빌드 폴더를 통째로 담으므로(`installer/gagyebu.iss:75`) 빌드 폴더에 넣기만 하면 된다. 크기가 너무 크면 CPU만 넣고 Vulkan은 모델처럼 내려받게 한다(판단은 실제 크기를 보고) |
| 백엔드 | Vulkan으로 띄워 보고, 준비되지 않으면 CPU로 다시 띄운다 |
| 주소 | `127.0.0.1`에만 연다. 포트는 앱이 빈 것을 골라 준다(`ServerSocket.bind(…, 0)`으로 얻은 번호). 임의의 키를 만들어 `--api-key`로 주고 요청마다 보낸다(같은 PC의 다른 프로그램이 못 쓰게) |
| 모델 | 준비된 글 모델(와 mmproj)로 띄운다. 모델이 바뀌면 다시 띄운다. 여러 모델을 갈아 끼우는 방식(라우터 모드)은 고정한 판의 문서를 읽고 되면 쓴다. **서버의 인자와 주소는 추측하지 말고 고정한 판의 `tools/server/README.md`로 확인한다** |
| 수명 | 앱이 켜지고 준비된 모델이 있으면 띄운다(설정에서 끌 수 있다). 15분 쉬면 내리고 다음 요청에서 다시 띄운다. 앱을 끄면 끈다 |
| 남는 프로세스 | 앱이 갑자기 죽어도 서버가 남지 않아야 한다. 실행 파일 쪽(`app/windows/runner/main.cpp`)에서 작업 개체(Job Object)를 만들어 "닫히면 자식도 끝낸다"로 두는 방법을 권한다. 더해서, 켤 때 지난번에 적어 둔 pid가 우리 서버로 남아 있으면 끝낸다 |
| 원문 보호 | 서버의 로그를 디스크에 쓰지 않는다(메모리에 최근 줄만). 요청 본문이 로그에 찍히지 않게 띄운다. 밖으로 나가는 연결은 없다 |
| 고정할 판 | Qwen3.5(`arch = qwen35`)를 올릴 수 있는 판이어야 한다. 2026-11-17에 커밋 `d3c3e24`로 올라갔다. 최신 릴리스를 골라 실제로 올려 보고 정한다 |

### 만들 것

1. **`app/lib/ai/llm/sidecar/`** (새 폴더)
   - `sidecar_process.dart`: 프로세스를 띄우고 끝내는 창구(`dart:io`의 `Process`를 감싼다. 시험에서 가짜로 바꾼다).
   - `sidecar_manager.dart`: 상태 기계 — 꺼짐 → 시작 중 → 준비됨 → 쉬어서 내림 / 실패. 빈 포트 고르기, 띄우기, `/health`가 준비될 때까지 기다리기, Vulkan → CPU 물러나기, 다시 띄우기, 끝내기. 상태는 `Stream`으로 내보낸다.
   - `sidecar_engine.dart`: `LlmEngine` · `VisionEngine` · `CancellableEngine`을 구현한다. 글은 기존 `OpenAiCompatibleEngine`(`app/lib/ai/llm/openai_compatible_engine.dart`)의 요청 꼴을 그대로 쓰되 키 머리글을 더한다. 이미지는 같은 주소에 그림을 붙여 보낸다. 멈춤은 진행 중인 요청을 끊는다(서버는 연결이 끊기면 생성을 멈춘다).
2. **`app/lib/app/engine_providers.dart`**: Windows에서 위 순서대로 고른다. `llmEngineProvider` · `visionEngineProvider`의 모양은 그대로다(부르는 네 곳은 바뀌지 않는다).
3. **화면** (`app/lib/features/models/models_screen.dart`): "엔진" 카드를 더한다 — 상태(실행 중 / 시작 중 / 쉬는 중 / 실패와 까닭), 백엔드, 판, 주소, 올라간 모델, [다시 시작]. 지금의 "로컬 엔진 주소(선택)" 카드는 **"고급"으로 접어** "다른 서버 쓰기"로 옮기고, 실행 파일 직접 지정 · 쉬는 시간 · 자동 시작 끄기를 그 안에 둔다.
4. **빌드**: `.github/workflows/ci.yml`과 `release.yml`의 Windows 작업에서 고정한 판의 릴리스 파일을 받아 해시를 확인하고 `app/build/windows/x64/runner/Release/engines/`에 푼다. 고정한 판과 해시는 저장소의 파일 하나(예: `catalog/engines.json`)에 둔다. `app/tool/check_licenses.dart`에 서버 실행 파일과 함께 오는 DLL의 라이선스를 더한다(허용형만).
5. **도구**: `app/tool/llm_eval.dart`에 `--sidecar=<실행 파일>`을 더해 같은 클래스로 잰다.
6. **문서**: `docs/MODELS.md`(구조 그림과 4장), `README.md`의 "AI 모델", `docs/SPEC.md` 5.4, `docs/ERRORS.md`.

### 다시 쓸 것

- 요청과 답의 꼴: `OpenAiCompatibleEngine`(문법 · 스키마 · 생각 모드 끔이 이미 들어 있다).
- 내려받기와 해시 확인: `ModelManager`(`app/lib/ai/llm/model_manager.dart`) — Vulkan 묶음을 내려받게 할 때.
- 연결 확인: `checkModelEndpoint`(`app/lib/features/models/model_providers.dart`).
- 멈춤과 줄 세우기의 약속: `LocalModelEngine`(`app/lib/ai/llm/local_model_engine.dart`)과 `CancellableEngine`.
- 실제 모델로 재는 도구와 표본: `tool/llm_eval.dart`, `query_eval.dart`, `narrative_eval.dart`, `vision_eval.dart`, `eval/golden/`.

### 여기서 확인할 수 있는 것과 없는 것

- **있다(Linux)**: 프로세스를 다루는 코드는 플랫폼을 가리지 않는다. llama.cpp의 Linux 릴리스 파일과 카탈로그의 모델(`dart run tool/model_fetch.dart --id=qwen3.5-2b-q4_k_m --dir=…`)을 받아, 띄우기 → 준비 → 읽기 → 멈춤 → 쉬면 내림 → 다시 띄움 → 끝내기를 실제로 돌린다. 수치를 앱 안의 엔진과 견준다(지난 실측: 서버 5초, 앱 안의 엔진 8초).
- **없다**: Windows에서 실행 파일이 뜨는지, Vulkan, 작업 개체, 설치 파일에 든 경로. CI의 Windows 빌드 통과까지만 본다. 나머지는 사용자에게 PC에서 확인을 청한다.

---

## 하지 않는 것

- Google 로그인을 로컬 주소(127.0.0.1)로 돌아오게 바꾸기: A1을 하고도 돌아오지 않는 PC가 나오면 그때 한다.
- Android에서 서버를 띄우기, 웹에서 모델 돌리기.

## 다음 에이전트가 지킬 것

- 모든 응답과 문서는 한글로만. 라이브러리와 실행 파일은 허용형 라이선스만(MIT · BSD · Apache 등).
- `claude/v1`에서 작업한다. `main`에 올리는 것과 릴리스는 사용자의 명시적 승인을 받는다.
- 태그는 이 환경에서 올릴 수 없다. 릴리스는 `app/pubspec.yaml`의 버전을 올린 뒤(다음은 `0.1.2+3`) `gh workflow run release.yml --ref main -f notes="…"`.
- "기기가 있어야 한다"고 넘기기 전에 여기서 돌려 볼 수 있는지 먼저 따진다(지난번에 이것을 건너뛰어 모델 하네스가 반쯤 된 채로 나갔다).
- 서명 키가 아직 없어 APK는 디버그 키로 서명된다. 바뀌지 않았으면 결과에 다시 적는다.

## 검증

- `flutter analyze` 0건, `flutter test` 전체 통과, `dart run tool/check_licenses.dart` 통과, CI의 Android · Windows 빌드 통과.
- **A**: 로그인 실패가 화면에 뜨는 시험, 기다리는 안내의 시험(뜸 · 60초 뒤 도움말 · 로그인되면 사라짐 · 웹에는 없음), 웹에 `?code=아무값`을 붙여 열면 알림이 뜨고 주소에서 지워지는 것(Playwright), 스킴 등록 시험(없을 때 씀 · 같으면 안 씀 · 다르면 고침 · 실패해도 앱이 뜸). PC에서: Google 로그인이 앱으로 돌아온다, `Win+R`에 `io.github.kimhershey.gagyebu://login-callback`을 넣으면 앱이 켜진다.
- **B**: 모델 줄의 왼쪽 끝이 카드 제목과 같다는 시험.
- **C**: 가짜 프로세스로 상태 기계의 시험(시작 실패 → CPU, 준비 시간 초과, 도중에 죽음 → 다시 띄움, 쉬면 내림, 끝낼 때 정리, 포트 충돌). 실제 `llama-server`와 모델로 도는 통합 시험(환경 변수를 줘야 도는 꼴, `test/integration/`의 본을 따른다). `tool/llm_eval.dart --sidecar=`의 수치를 `eval/README.md`에 적는다. PC에서: 앱을 켜면 엔진 카드가 "실행 중"이 되고 주소가 보인다, 모르는 형식의 문자를 넣으면 읽는다, 앱을 끄면 작업 관리자에 `llama-server`가 남지 않는다.
