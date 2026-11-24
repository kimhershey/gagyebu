# catalog/

앱(Windows · Android)이 읽어 가는 공개 파일이다. 앱은 공개 저장소 `main` 브랜치의 이 파일들을 그대로 내려받기만 하고, 아무것도 보내지 않는다(`docs/SPEC.md` 2.3). `main`에 올라간 내용이 곧 모든 사용자에게 보이는 값이므로 고칠 때 주의한다.

| 파일 | 내용 | 누가 고치는가 |
| --- | --- | --- |
| `version.json` | 최신 버전과 내려받기 주소(업데이트 확인, `docs/SPEC.md` 7.21) | 릴리스 작업이 태그마다 고친다 |
| `models.json` | 기기 안에서 돌리는 모델의 카탈로그(`docs/SPEC.md` 5.4) | 사람이 고친다. `app/assets/catalog/models.json`에도 같은 내용을 둔다 |

## version.json

```json
{
  "latest": "0.1.0",
  "min": "0.1.0",
  "notes": "첫 버전입니다.",
  "android": "https://github.com/kimhershey/gagyebu/releases/latest/download/gagyebu-android-arm64.apk",
  "windows": "https://github.com/kimhershey/gagyebu/releases/latest/download/gagyebu-setup.exe"
}
```

| 키 | 뜻 |
| --- | --- |
| `latest` | 가장 새 버전. 앱의 버전(`app/pubspec.yaml`의 `version`에서 `+` 앞부분)보다 높으면 앱이 새 버전이 있다고 알린다 |
| `min` | 이보다 낮은 버전은 꼭 올려야 한다고 알린다(막지는 않는다) |
| `notes` | 새 버전에서 달라진 것 한 줄. 앱 화면에 그대로 보이므로 "…습니다" 체로 적는다 |
| `android` · `windows` | 누르면 브라우저로 여는 내려받기 주소 |

- 릴리스 작업(`.github/workflows/release.yml`)이 `v*` 태그의 릴리스를 올린 뒤 `latest`와 두 주소를 그 태그의 것으로 고쳐 `main`에 커밋한다. 주소는 `https://github.com/<저장소>/releases/download/<태그>/<파일 이름>` 꼴이 된다. `notes`는 주석 달린 태그(`git tag -a`)의 첫 줄로 채우고, 주석이 없으면 비운다.
- 시험판 태그(`v0.2.0-beta.1`처럼 `-`가 든 것)와 지금의 `latest`보다 낮은 버전의 태그는 이 파일을 고치지 않는다.
- `min`은 릴리스 작업이 건드리지 않는다. 예전 버전을 더 쓰면 안 될 때(예: 동기화 규약이 바뀌었을 때) 사람이 올린다.
- 처음 값의 주소는 "가장 새 릴리스의 파일"을 가리키는 꼴이다. 첫 릴리스를 올리기 전에는 열리지 않는다.

## models.json

기기 안에서 돌리는 모델의 목록이다. 앱(Windows · Android)은 `main`의 이 파일을 읽어 "AI 모델" 화면에 보여 주고, 읽지 못하면 앱에 든 사본(`app/assets/catalog/models.json`)을 쓴다. **두 파일은 같아야 한다**(시험 `app/test/ai/model_manager_catalog_test.dart`가 확인한다). 이 파일을 고치면 사본에도 그대로 옮긴다.

```json
{
  "version": 1,
  "models": [
    {
      "id": "qwen3.5-2b-q4_k_m",
      "kind": "text",
      "name": "Qwen3.5-2B",
      "license": "Apache-2.0",
      "url": null,
      "size_bytes": null,
      "sha256": null,
      "min_memory_gb": 6,
      "platforms": ["android", "windows"],
      "mmproj": "qwen3.5-2b-mmproj"
    }
  ]
}
```

| 키 | 뜻 |
| --- | --- |
| `version` | 카탈로그의 판. 지금 앱은 1만 읽는다. 항목의 꼴을 바꾸면 올린다(옛 앱은 사본을 쓴다) |
| `id` | 모델의 이름표. 기기에 저장하는 파일 이름(`<id>.gguf`)과 거래의 `ai_model`에 쓰인다. 영문 · 숫자 · `.` · `_` · `-`만 쓴다. 한 번 정하면 바꾸지 않는다 |
| `kind` | `text`(글을 읽는 모델) · `vision`(이미지를 읽는 모델) · `mmproj`(이미지를 모델이 읽게 바꾸는 보조 파일) |
| `name` | 화면에 보이는 이름 |
| `license` | 모델의 라이선스. 허용형(Apache-2.0, MIT 등)만 넣는다 |
| `url` | GGUF 파일을 받는 주소. `https://`여야 한다 |
| `size_bytes` | 파일 크기(바이트). 받기 전에 크기와 저장 공간을 알리는 데 쓴다. 비워 두면 서버가 알려 주는 크기를 쓴다 |
| `sha256` | 파일의 SHA-256(16진수 64자). 다 받은 뒤에 맞춰 보고, 다르면 지운다 |
| `min_memory_gb` | 이 모델을 돌리는 데 필요한 기기 메모리(GB). 앱은 기기 메모리로 돌릴 수 있는 것 가운데 가장 큰 것을 권한다 |
| `platforms` | 쓸 수 있는 플랫폼: `android`, `windows` |
| `mmproj` | 이미지를 읽을 때 함께 쓰는 `mmproj` 항목의 `id`. 없으면 `null` |

- **`url`과 `sha256`이 둘 다 있어야 앱에서 내려받을 수 있다.** 하나라도 `null`이면 그 항목은 화면에 보이기만 하고 "내려받기"가 꺼져 있다. 해시 없이 받으면 받은 파일이 맞는지 확인할 길이 없어서다.
- 지금 파일의 `url` · `size_bytes` · `sha256`은 모두 `null`이다. 실제 값은 사람이 Hugging Face에서 확인해 채운다(지어내지 않는다). 채우는 법:
  1. 쓸 GGUF 파일을 정한다. 평가에 쓴 것은 Qwen3.5-2B의 Q4_K_M 양자화(약 1.28GB)다(`eval/README.md`). 이미지 입력에는 그 모델의 `mmproj` 파일도 필요하다.
  2. `url`에는 특정 커밋을 가리키는 주소(`https://huggingface.co/<소유자>/<저장소>/resolve/<커밋>/<파일>.gguf`)를 적는다. `main`을 가리키면 파일이 바뀌었을 때 해시가 어긋난다.
  3. 파일을 받아 `sha256sum <파일>`과 `stat -c %s <파일>`(바이트)로 `sha256`과 `size_bytes`를 적는다. Hugging Face의 파일 화면에 보이는 SHA256과 같은지 본다.
  4. 같은 내용을 `app/assets/catalog/models.json`에 옮기고 시험을 돌린다.
- 등급(`docs/SPEC.md` 5.4): 휴대폰 6GB 이상은 글 모델(2B), PC 8–15GB는 글 모델과 그 `mmproj`, PC 16GB 이상은 글 모델(2B)과 이미지 모델(4B) · 그 `mmproj`. 이 표는 `min_memory_gb`와 `platforms`로 적혀 있다.
- 모델을 바꿀 때는 새 `id`로 항목을 더한다. 옛 항목을 지우면 이미 받은 기기에서는 그 파일이 "카탈로그에 없는 모델"로 남고, 앱이 새 모델을 받은 뒤에 지울지 묻는다.
