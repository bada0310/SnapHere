# Android 인증 API 연결

앱은 기본적으로 `https://snaphere.duckdns.org`의 운영 API를 사용한다. 인증 대체 구현이 필요한 UI 테스트나 데모 실행에서는 `--dart-define=USE_FAKE_AUTH=true`를 전달한다.

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=000000000000-example.apps.googleusercontent.com
```

Android 에뮬레이터에서 호스트 PC의 백엔드에 접근할 때는 `10.0.2.2`를 명시한다. `API_BASE_URL`을 생략하면 운영 HTTPS 주소가 적용되며, 앱은 뒤에 `/api/v1`을 붙인다.

Android Google SDK의 `serverClientId`는 Web OAuth 클라이언트 ID다.
기존 앱 `.env`의 `GOOGLE_OAUTH_CLIENT_ID`도 자동으로 읽는다.
우선순위는 `--dart-define=GOOGLE_SERVER_CLIENT_ID` →
`--dart-define=GOOGLE_OAUTH_CLIENT_ID` → `.env`의 `GOOGLE_SERVER_CLIENT_ID` →
`.env`의 `GOOGLE_OAUTH_CLIENT_ID`다. 빈 값은 건너뛰며 모두 없으면 SDK의
네이티브 설정 동작을 유지한다. 백엔드의 `GOOGLE_OAUTH_CLIENT_ID`와 일치해야 하며,
OAuth client secret을 모바일 앱에 넣지 않는다. 설정값 변경 후에는 앱을 재빌드한다.

실기기에서 로컬 서버를 사용할 때는 기기를 다시 연결한 뒤 아래 포트 전달도 확인한다.
이 연결은 USB 재연결 등으로 사라질 수 있으며, 휴대폰의 `127.0.0.1`이 자동으로 PC를 뜻하지는 않는다.

```powershell
adb -s <device-serial> reverse tcp:8080 tcp:8080
flutter run -d <device-serial> --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

저장소 루트 `.env`의 OAuth ID를 바꿨다면 이미 실행 중인 Spring Boot도 재시작한다.
서버는 시작할 때 해당 설정을 읽으므로 파일 수정만으로 실행 중인 검증 대상 ID가 바뀌지 않는다.
로그인 교환은 서버 연결 실패·시간 초과·인증 설정 불일치·서버 오류를 구분해 안내한다.
디버그 로그에는 HTTP 상태와 제한된 오류 코드만 남기며 토큰·서버 응답 원문은 출력하지 않는다.

## 현재 백엔드 계약

- `POST /api/v1/auth/google`: `idToken`, 앱이 안전 저장소에 생성한 `deviceId`, `platform`을 보낸다.
- `POST /api/v1/auth/refresh`: `refreshToken`, 동일한 `deviceId`를 보내 토큰을 회전한다.
- `POST /api/v1/auth/onboarding`: Bearer 토큰과 `nickname`, `termsVersion`, `locale`을 보낸다.
- `POST /api/v1/auth/logout`: 현재 기기의 세션을 종료한다.
- `GET /api/v1/me`: 로그인 사용자의 공개 프로필과 통계를 조회한다.
- `POST /api/v1/me/deletion`: `contentAction`을 `KEEP_ANONYMIZED` 또는 `DELETE_ALL`로 보내 30일 유예 탈퇴를 요청한다.

서버의 인증 응답은 공통 `ApiResponse.data` 안에 `tokens`, `user`, `onboardingRequired`를 담는다. 앱의 `ApiAuthRepository`가 이를 로컬 `AuthSession`으로 변환하고 `flutter_secure_storage`에 저장한다.

현재 백엔드에는 법적 문서 조회 API가 없다. 개인정보처리방침, 서비스 이용약관, 개인정보 수집·이용 동의 문서는 `assets/legal/`에 앱 자산으로 포함하고 `AssetLegalDocumentRepository`에서 읽는다. 기존 `/legal/privacy-policy`, `/legal/terms`, `/legal/privacy-consent` 경로로 제공한다. 마케팅 정보 수신 동의는 서버에 저장·발송 기능이 없어 가입 화면에서 제거했다. 법적 문서를 개정할 때는 해당 자산을 수정하고 앱을 다시 배포해야 한다.

## 교체 경계

- 화면: `presentation/`
- 인증 흐름과 세션 상태: `application/auth_controller.dart`
- 서버 계약: `domain/auth_repository.dart`
- 실제 HTTP 구현: `data/api_auth_repository.dart`
- 암호화 세션·기기 ID 저장: `data/session_store.dart`, `flutter_secure_storage`
