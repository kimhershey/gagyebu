# 앱 안의 AI 모델: 설치와 로드

기준: 2026-11-24(v0.1.1). Windows · Android 앱이 기기 안에서 돌리는 모델을 어떻게 받고, 올리고, 쓰는지 적는다. 모델을 새로 더하거나 바꿀 때 이 문서를 본다. 전체 설계는 [설계서](SPEC.md) 5장, 잰 수치는 [평가 기록](../eval/README.md)에 있다.

## 1. 지금 상태

| | 상태 |
| --- | --- |
| 모델 목록(카탈로그) | 네 파일의 주소 · 크기 · 해시가 채워져 있다. 앱에서 받을 수 있다 |
| 설치(내려받기 · 이어받기 · 해시 확인) | 실제 주소로 돌려 봤다(Linux). 668MB 파일을 중간에 끊고 이어받아 해시가 맞았다 |
| 로드와 실행 | 실제 모델(Qwen3.5-2B · 4B)을 앱의 런타임에 올려 문자 읽기 · 조회 · 총평 · 이미지를 돌려 봤다(Linux, CPU) |
| Windows · Android 기기에서의 실행 | **확인하지 못했다.** 빌드만 된다. 화면에서 내려받기, Windows의 Vulkan 가속, 휴대폰의 속도와 메모리는 기기가 있어야 본다 |
| 웹 | 모델을 쓰지 않는다(규칙만). 7.3절 |

어디서 무엇이 되는가:

| | 웹 | Android 앱 | Windows 앱 |
| --- | --- | --- | --- |
| 결제 문자 · 한 줄 문장(규칙) | 됨 | 됨 | 됨 |
| 규칙이 모르는 형식의 문자를 모델로 읽기 | — | 메모리 6GB 이상 | 됨 |
| 조회에서 규칙이 못 읽은 물음 | — | 메모리 6GB 이상 | 됨 |
| 월별 총평을 모델이 쓰기 | 문장 틀 | 메모리 6GB 이상 | 됨 |
| 이미지(거래내역 화면 · 영수증) 읽기 | — | — | 메모리 8GB 이상 |

## 2. 구조

```
                    ┌──────────────────────── 설치 ────────────────────────┐
catalog/models.json ─▶ 카탈로그 읽기 ─▶ 기기 사양으로 권하기 ─▶ 내려받기 · 해시 확인 ─▶ model_files 표
 (GitHub 원본,         model_catalog      model_tier             model_manager          (로컬 DB)
  못 읽으면 앱에 든 사본)                                          파일: 앱 지원 폴더/models/<id>.gguf
                                                                                            │
                    ┌──────────────────────── 로드 ────────────────────────┐                ▼
입력창 · 조회 · 통계 ─▶ llmEngineProvider ─────▶ LocalModelEngine ─▶ LlamadartRuntime ─▶ llama.cpp
이미지 입력 ─────────▶ visionEngineProvider ──▶  (줄 세우기, 쉬면 내림)  (올리기, 상태 저장)
                          ▲
설정의 "모델 서버 주소" ──┘ 적어 두면 OpenAiCompatibleEngine이 그 서버에 묻는다(글만)
```

| 파일 | 하는 일 |
| --- | --- |
| `catalog/models.json` | 받을 수 있는 모델의 목록. 원본 |
| `app/assets/catalog/models.json` | 같은 내용의 사본. 원본을 못 읽을 때 쓴다. 둘이 같은지 시험이 본다 |
| `app/lib/ai/llm/model_catalog.dart` | 카탈로그 읽기. 모르는 판(`version`)은 받지 않는다 |
| `app/lib/ai/llm/model_tier.dart` | 기기의 플랫폼과 메모리로 권할 모델 고르기 |
| `app/lib/ai/llm/model_manager.dart` | 내려받기, 이어받기, 해시 확인, 지우기, 앱을 켤 때 기록과 파일 맞추기 |
| `app/lib/ai/llm/model_file_store*.dart` | 파일을 두는 곳(웹 빌드에는 빈 구현이 들어간다) |
| `app/lib/data/repositories/model_file_repository.dart` | `model_files` 표(파일마다의 상태) |
| `app/lib/ai/llm/local_model_runtime*.dart` | 런타임의 창구. 웹 빌드에서 llama.cpp가 빠지게 하는 조건부 가져오기 |
| `app/lib/ai/llm/llamadart_runtime.dart` | llama.cpp로 올리고 돌린다. 시스템 글을 다시 읽지 않게 하는 상태 저장 |
| `app/lib/ai/llm/local_model_engine.dart` | 처음 쓸 때 올림, 요청 줄 세우기, 쉬면 내림, 멈춤 |
| `app/lib/app/engine_providers.dart` | 지금 쓸 엔진 고르기 |
| `app/lib/ai/llm/openai_compatible_engine.dart` | 사용자가 띄운 모델 서버에 묻기 |
| `app/lib/features/models/` | 설정 → AI 모델 화면 |
| 모델을 부르는 곳 | `ai/llm/llm_text_parser.dart`(문자), `ai/query/llm_query_parser.dart`(조회), `ai/llm/narrative_writer.dart`(총평), `ai/vision/vision_text_parser.dart`(이미지) |

모델을 부르는 네 곳은 모두 같은 틀이다. 질문을 만들고 → 문법(GBNF)으로 답의 형식을 묶고 → 받은 답을 코드로 검증하고 → 어긋나면 까닭을 붙여 한 번 다시 묻고 → 또 어긋나면 포기한다. 포기하면 규칙이나 문장 틀로 물러난다. 금액 · 날짜 · 합계는 모델이 아니라 코드가 계산한다.

## 3. 설치

### 3.1 카탈로그

```json
{
  "id": "qwen3.5-2b-q4_k_m",
  "kind": "text",
  "name": "Qwen3.5-2B",
  "license": "Apache-2.0",
  "url": "https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/<판>/Qwen3.5-2B-Q4_K_M.gguf",
  "size_bytes": 1280835840,
  "sha256": "aaf42c8b…",
  "min_memory_gb": 6,
  "platforms": ["android", "windows"],
  "mmproj": "qwen3.5-2b-mmproj"
}
```

| 칸 | 뜻 |
| --- | --- |
| `id` | 파일 이름(`<id>.gguf`)과 `model_files.id`, 거래의 `ai_model`에 쓰인다. 영문 · 숫자 · `.` `-` `_`만, 80자까지 |
| `kind` | `text`(글), `vision`(이미지를 읽는 데 쓰는 모델), `mmproj`(이미지를 모델이 읽을 수 있게 바꾸는 파일) |
| `url` · `sha256` | 둘 다 있어야 받을 수 있다. 해시 없이는 받지 않는다(받은 파일이 맞는지 알 길이 없다) |
| `size_bytes` | 받기 전에 저장 공간을 보는 데 쓴다 |
| `min_memory_gb` | 이 모델을 돌리는 데 필요한 기기 메모리 |
| `platforms` | `android`, `windows` |
| `mmproj` | 이미지를 읽을 때 함께 쓰는 mmproj의 `id` |

앱은 카탈로그를 `https://raw.githubusercontent.com/kimhershey/gagyebu/main/catalog/models.json`에서 읽고, 못 읽으면 앱에 든 사본을, 그것도 못 읽으면 빈 목록을 쓴다. **`main`의 이 파일을 고치면 이미 설치된 앱이 다음에 화면을 열 때 바로 반영된다.** 새 릴리스가 필요 없다.

지금 들어 있는 것:

| id | 파일 | 크기 | 쓰는 곳 |
| --- | --- | --- | --- |
| `qwen3.5-2b-q4_k_m` | Qwen3.5-2B Q4_K_M | 1.28GB | 글(Android · Windows, 6GB 이상) |
| `qwen3.5-2b-mmproj` | 2B의 mmproj F16 | 668MB | 이미지(Windows, 8GB 이상) |
| `qwen3.5-4b-q4_k_m` | Qwen3.5-4B Q4_K_M | 2.74GB | 이미지(Windows, 16GB 이상) |
| `qwen3.5-4b-mmproj` | 4B의 mmproj F16 | 672MB | 이미지(Windows, 16GB 이상) |

### 3.2 권하기

기기의 메모리를 읽어(`device_info_plus`) GB로 올림하고, `min_memory_gb`가 그 이하인 것 가운데 가장 큰 모델을 권한다. 메모리를 읽지 못하면 가장 작은 글 모델만 권한다. 이미지 모델은 mmproj까지 그 기기에서 쓸 수 있어야 권한다. 권하기만 하고, 사용자가 "내려받기"를 눌러야 받는다.

### 3.3 내려받기

1. 받기 전에 저장 공간을 본다. 파일 크기에 64MB의 여유를 더한 만큼 없으면 받지 않고 알린다.
2. `<id>.gguf.part`에 받는다. 받다 만 `.part`가 있으면 그 뒤부터 이어받는다(HTTP Range). 서버가 이어받기를 받아 주지 않으면 처음부터 다시 받는다.
3. 60초 동안 아무것도 오지 않으면 끊긴 것으로 보고 멈춘다. 받은 데까지는 남는다.
4. 다 받으면 SHA-256을 카탈로그의 값과 맞춰 본다. 다르면 파일을 지우고 실패로 둔다.
5. 맞으면 `.part`를 `<id>.gguf`로 바꾸고 `model_files`에 "준비됨"으로 적는다.

파일은 앱 지원 폴더의 `models/`에 둔다(Windows: `%APPDATA%` 아래 앱 폴더, Android: 앱 전용 저장소). 진행 상황은 8MB마다 `model_files`에 적는다. 앱을 켤 때 기록과 파일을 맞춘다: "받는 중"으로 남은 것은 실패로 고치고(이어받을 수 있다), "준비됨"인데 파일이 없으면 기록을 지운다.

모델 파일을 받는 GET 말고는 밖으로 나가는 요청이 없다. 보내는 내용도 없다.

### 3.4 다른 방법: 모델 서버 주소

설정 → AI 모델에 내 PC에서 띄운 모델 서버(OpenAI 호환, 예: `llama-server`)의 주소를 적으면, 내려받은 모델 대신 그 서버에 묻는다. 글만 되고 이미지는 안 된다. 주소를 적어 두면 그쪽이 먼저다.

## 4. 로드

### 4.1 어떤 모델을 올리나

`model_files`에서 "준비됨"인 파일을 보고 고른다(`engine_providers.dart`의 `localModelSpecsProvider`).

- 글: 준비된 글 모델. 여럿이면 나중에 받은 것.
- 이미지(Windows): 이미지용 모델과 그 mmproj가 둘 다 준비돼 있으면 그것. 아니면 mmproj가 붙은 글 모델.
- 같은 모델을 글과 이미지에 함께 쓰면 엔진도 하나다. 메모리에 두 번 올리지 않는다.

### 4.2 올리고 내리기

- 앱을 켤 때 올리지 않는다. **처음 요청이 올 때** 올린다(2B는 Linux CPU에서 1.5초쯤).
- Windows는 Vulkan으로 올려 보고 실패하면 CPU로 다시 올린다. Android는 CPU다.
- 문맥 길이는 4096토큰. 온도 0(같은 입력에 같은 답), 생각 모드는 끈다.
- 요청은 한 줄로 세워 차례로 돌린다. 런타임은 한 번에 하나만 돌린다.
- **5분 동안 쓰지 않으면 메모리에서 내린다.** 다음 요청에서 다시 올린다.
- 입력창의 "그만"은 돌고 있는 생성과 기다리는 요청을 모두 멈춘다.
- 추론은 런타임이 띄운 별도 격리 영역(isolate)에서 돈다. 화면이 멈추지 않는다.

### 4.3 시스템 글을 다시 읽지 않기

질문의 대부분(문자 읽기는 1,590토큰 가운데 1,438토큰)은 요청마다 같은 시스템 글이다. llama.cpp는 앞 요청과 같은 앞부분을 다시 읽지 않는데, Qwen3.5는 되감을 수 없는 기억을 쓰는 층이 있어 그것이 안 된다. 그래서 런타임이 직접 한다(`llamadart_runtime.dart`의 `_PrefixCache`).

1. 어떤 시스템 글이 처음 오면, 그 글까지만 읽은 상태를 임시 폴더의 파일에 저장한다(2B에서 38MB).
2. 요청마다 그 파일을 불러온 뒤(20ms쯤) 사용자 글만 이어서 읽는다.
3. 시스템 글이 다른 것(문자 · 조회 · 총평) 셋까지 들고 있고, 모델을 내릴 때 파일을 지운다.

파일에는 시스템 글을 읽은 상태만 들어간다. 사용자가 넣은 원문은 들어가지 않는다. 이 방식이 안 되는 런타임이면 조용히 처음부터 읽는다(느리지만 답은 같다). 이미지가 든 요청에는 쓰지 않는다.

### 4.4 Windows: 앱이 띄우는 모델 서버

Windows에서는 글을 읽을 때 앱 안의 엔진 대신 **앱이 스스로 띄운 `llama-server`**를 먼저 쓴다(`app/lib/ai/llm/llama_server.dart`). 사용자가 할 일은 없다.

- 실행 파일은 설치 폴더의 `engines/vulkan/`과 `engines/cpu/`에 들어 있다. 빌드할 때 `installer/fetch_engines.ps1`이 llama.cpp의 릴리스(판 `b12774`, MIT)를 받아 해시를 확인하고 넣는다.
- 받아 둔 글 모델이 있으면 앱을 켤 때 띄운다. Vulkan으로 띄워 보고 2분 안에 준비되지 않으면 CPU로 띄운다.
- `127.0.0.1`에만 열고, 포트는 그때 비어 있는 것을, 키는 임의로 정한다. 키 없는 요청은 서버가 거절한다. 주소와 키는 어디에도 적어 두지 않는다.
- 15분 쉬면 내리고 다음 요청에서 다시 띄운다. 요청이 도는 동안에는 내리지 않는다. 서버가 죽어 있으면 다음 요청에서 다시 띄운다.
- 띄우지 못하면 앱 안의 엔진으로 물러난다. 이미지는 지금도 앱 안의 엔진이 읽는다.
- 앱이 갑자기 꺼져도 서버가 남지 않게, 실행 파일이 작업 개체(Job Object)로 묶어 둔다(`app/windows/runner/main.cpp`).
- 상태는 설정 → AI 모델의 "엔진" 카드에 보인다.

같은 판의 Linux 실행 파일과 실제 모델로 확인했다(`GAGYEBU_TEST_LLAMA_SERVER=… GAGYEBU_TEST_MODEL=… flutter test test/integration/llama_server_test.dart`). Windows에서는 돌려 보지 못했다.

### 4.5 실패했을 때

| 무슨 일 | 앱이 하는 것 |
| --- | --- |
| 모델을 올리지 못했다, 추론이 실패했다 | 그 덩어리는 "읽지 못함"으로 두고 나머지는 계속 읽는다. 한 줄 글이면 규칙으로 다시 읽는다 |
| 답이 형식 · 검증에 어긋난다 | 까닭을 붙여 한 번 다시 묻는다. 또 어긋나면 포기한다 |
| 조회를 못 읽었다 | "조건을 읽지 못했습니다"와 예시를 보여 준다 |
| 총평이 검증에서 떨어졌다 | 문장 틀로 쓴다 |
| 모델이 없다 | 규칙만으로 돈다. 이미지 입력은 메뉴에 나오지 않는다 |

## 5. 잰 것 (Linux, 4코어 CPU, GPU 없음)

| 길 | 2B | 4B |
| --- | --- | --- |
| 모르는 형식의 문자 20건: 모든 항목이 맞음 | 14건, 건당 8–11초 | 이 런타임으로는 재지 않음 |
| 조회 20문(규칙 → 모델) | 15문 | 재지 않음 |
| 총평(쓴 돈이 있는 4달): 검증 통과 | 3달, 15–38초 | 4달, 24–38초 |
| 거래내역 화면 그림 1장 | 5줄 모두 맞음, 75초 | 5줄 모두 맞음, 126초 |
| 영수증 그림 1장 | 가게 · 합계만, 49초 | 품목 · 날짜까지 맞음, 85초 |

소형 모델의 한계는 그대로다. 2B는 조회에서 낱말을 분류에 잇는 것이 약하고, 총평에서 어색한 문장을 쓴다. 그래서 모델이 읽은 것은 모두 사용자가 확인하게 되어 있다(검토함, 조회 화면의 "조건이 맞는지 확인해 주세요").

## 6. 모델을 더하거나 바꾸는 절차

1. **파일을 고른다.** GGUF, Q4_K_M 양자화. 모델의 라이선스가 허용형(Apache-2.0 · MIT 등)인지 본다. 이미지에 쓰려면 같은 저장소의 `mmproj` 파일이 있어야 한다.
2. **주소를 특정 판에 고정한다.** Hugging Face라면 `…/resolve/main/…`이 아니라 `…/resolve/<커밋 해시>/…`로 적는다. `main`으로 적으면 저장소가 파일을 바꿨을 때 해시가 달라져 모두의 설치가 실패한다.

   ```bash
   curl -s https://huggingface.co/api/models/<저장소> | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])"
   ```

3. **크기와 해시를 구한다.** 저장소가 알려 주는 값과 직접 받은 파일의 값을 맞춰 본다.

   ```bash
   curl -s https://huggingface.co/api/models/<저장소>/tree/<커밋 해시>
   ```

   ```bash
   sha256sum 파일.gguf && stat -c %s 파일.gguf
   ```

4. **카탈로그 두 곳을 같게 고친다.** `catalog/models.json`과 `app/assets/catalog/models.json`. `min_memory_gb`는 지금 값(2B는 6GB, 4B는 16GB)을 기준으로 잡고 기기에서 확인해 고친다.
5. **실제로 받아 본다.**

   ```bash
   cd app && dart run tool/model_fetch.dart --id=<id> --dir=/tmp/models
   ```

6. **실제로 돌려 본다.** 수치가 지금보다 나쁘면 넣지 않는다.

   ```bash
   dart run tool/llm_eval.dart --model=/tmp/models/models/<id>.gguf --set=holdout
   ```

   ```bash
   GAGYEBU_TEST_MODEL=/tmp/models/models/<id>.gguf flutter test test/integration/local_model_runtime_test.dart
   ```

   조회는 `tool/query_eval.dart`, 총평은 `tool/narrative_eval.dart`, 이미지는 `tool/vision_eval.dart`로 본다.
7. **시험과 라이선스 검사를 돌린다.** `flutter test`, `dart run tool/check_licenses.dart`.
8. **기기에서 확인한다.** 화면에서 내려받기, 올리는 시간, 한 건에 걸리는 시간, 메모리, 다른 앱을 쓰다 돌아왔을 때.
9. **`main`에 올린다.** 올리는 순간 설치된 앱에 반영된다는 점을 기억한다(3.1절).

모델을 바꾸면 질문 형식도 다시 봐야 한다. 지금의 질문(`extraction_prompt.dart`의 v5)은 Qwen3.5-2B에 맞춰 다듬은 것이다.

## 7. 넓힐 때 고칠 곳

### 7.1 파일을 올려 둘 곳

| 방법 | 좋은 점 | 나쁜 점 |
| --- | --- | --- |
| 모델 저장소(Hugging Face)의 주소를 그대로 (지금) | 따로 올릴 것이 없다. 판에 고정하면 파일이 바뀌지 않는다 | 저장소가 지워지면 받을 수 없다 |
| 이 저장소의 GitHub Releases | 우리가 관리한다 | 파일 하나에 2GB까지라 4B는 올릴 수 없다 |
| 따로 마련한 저장소 | 크기 제한이 없다 | 비용과 관리 |

### 7.2 아직 없는 설치 방법

- **파일에서 가져오기**: 사용자가 이미 가진 GGUF를 골라 넣는 기능은 없다. 만들려면 파일을 `models/`로 옮기고 `model_files`에 적어야 하는데, 카탈로그에 없는 파일은 해시를 맞춰 볼 수 없고 종류(글 · 이미지)도 알 수 없다. "사용자가 넣은 파일"이라는 상태를 새로 두고, 올려 보아 되는지로 확인하는 방식이 필요하다.
- **설치 파일에 함께 넣기**: 하지 않는다. 설치 파일이 1.3GB 넘게 커지고, 모델을 쓰지 않는 사람도 받아야 한다.
- **모델 서버 주소**(3.4절)는 이미 된다.

### 7.3 웹에서 돌리기

지금은 웹에서 모델을 쓰지 않는다. `llamadart`는 지원 플랫폼에 웹도 적어 두고 있어 불가능한 것은 아니지만, 확인하지 않았다. 하려면 세 군데가 바뀌어야 한다.

- `local_model_runtime_stub.dart`: 웹용 런타임을 만들어 돌려준다.
- `model_file_store_stub.dart`: 브라우저에 1GB 넘는 파일을 둘 곳(OPFS 등)이 필요하다.
- `model_tier.dart`의 `runsLocalModels`와 카탈로그의 `platforms`에 웹을 더한다.

브라우저가 저장소를 지울 수 있다는 점(Safari는 7일)과 휴대폰 브라우저의 메모리 한도가 걸린다.

### 7.4 그 밖

- **다른 런타임**: `LocalModelRuntime`(올리기 · 생성 · 멈춤 · 내리기)을 구현하고 `local_model_runtime_io.dart`에서 그것을 돌려준다. 엔진과 그 위는 바뀌지 않는다.
- **카탈로그의 꼴을 바꾸기**: 칸을 더하는 것은 괜찮다(옛 앱은 모르는 칸을 무시한다). 뜻을 바꾸려면 `version`을 올린다. 옛 앱은 모르는 판을 받지 않고 앱에 든 사본을 쓴다.
- **Android에서 이미지**: 카탈로그의 mmproj에 `android`를 더하고 `engine_providers.dart`와 `image_input_available.dart`의 Windows 조건을 푼다. 휴대폰 메모리로 되는지 먼저 재야 한다.
