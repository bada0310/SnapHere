# dev-mocks

개발용 목업 리소스 모음. **APK/IPA 번들에 포함되지 않습니다** (`pubspec.yaml`의 `flutter/assets`에 등록돼 있지 않음).

## upload/

`FakeEventRepository` / `FakeUploadRepository`가 참조하는 데모 썸네일 12장(`upload_01~12.png`).

- 원래 `assets/images/upload/`에 있었고 번들에 포함돼 릴리스 APK를 16MB 키웠음.
- 이 Fake 저장소들은 `USE_FAKE_EVENTS` / `USE_FAKE_UPLOAD` (기본값 `false`)일 때만 쓰이므로 실제 릴리스에서는 표시되지 않음 → 번들에서 제외하고 여기로 이동.
- 결과: 기본(프로덕션) 빌드는 영향 없음. `--dart-define=USE_FAKE_*=true` 개발 빌드에서는 이 썸네일 자리에 fallback 아이콘이 표시됨.

이 이미지를 개발 모드에서 다시 보고 싶으면, `pubspec.yaml`에 `- dev-mocks/upload/`를 assets로 추가하고 Fake 저장소 경로를 `dev-mocks/upload/...`로 바꾸면 됨(단, 그러면 다시 번들에 포함되니 주의).
