# catalog/

앱(Windows · Android)이 읽어 가는 공개 파일이다. 앱은 공개 저장소 `main` 브랜치의 이 파일들을 그대로 내려받기만 하고, 아무것도 보내지 않는다(`docs/SPEC.md` 2.3). `main`에 올라간 내용이 곧 모든 사용자에게 보이는 값이므로 고칠 때 주의한다.

| 파일 | 내용 | 누가 고치는가 |
| --- | --- | --- |
| `version.json` | 최신 버전과 내려받기 주소(업데이트 확인, `docs/SPEC.md` 7.21) | 릴리스 작업이 태그마다 고친다 |
| `models.json` | 기기 안에서 돌리는 모델의 카탈로그(`docs/SPEC.md` 5.4) | 사람이 고친다 |

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
