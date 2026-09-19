# SnapHere Flutter App

지역 관광 사진과 공공 관광데이터를 연결하는 SnapHere 모바일 앱입니다.

## 시작하기

```bash
flutter pub get
flutter run
```

## 품질 확인

```bash
dart format .
flutter analyze
flutter test
```

## Android 스토어 빌드

`android/key.properties.example`을 `android/key.properties`로 복사한 뒤 팀의
Google Play 업로드 키 정보를 입력합니다. 실제 `key.properties`와 keystore는
Git에 포함되지 않습니다.

```bash
flutter build appbundle --release
```

기본 API 주소는 `https://snaphere.duckdns.org`이며 앱에서 `/api/v1`을 붙입니다. 다른 서버로 빌드할 때만 `--dart-define=API_BASE_URL=https://...`를 지정합니다.

키 설정이 없으면 로컬 릴리스 검증을 위해 debug 키로 서명되며, 생성된 AAB는
스토어에 제출하면 안 됩니다.

구조와 단계별 구현 계획은 [`docs/flutter-bootstrap-plan.md`](../docs/flutter-bootstrap-plan.md)를 참고합니다.
