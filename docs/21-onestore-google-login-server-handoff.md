# 원스토어 Google 로그인 실패: 서버 확인 요청

작성일: 2026-09-19 (KST)

대상: 운영 API `https://snaphere.duckdns.org/api/v1/auth/google`
관련: AUTH-001~003, API-AUTH-001, DEC-20260919-001, [프론트엔드 PR #70](https://github.com/jsy002514/SnapHere/pull/70)

## 현상과 확인된 사실

- 원스토어 AAB에서 생성된 APK를 SM-S938N에 설치했다. 사용자가 Google 계정을 선택하면 로그인 화면에 `로그인 서버의 응답을 처리하지 못했어요`가 표시된다. 사용자는 이 계정으로 회원 탈퇴한 적이 없다고 확인했다.
- 기기 로그에서 두 번 모두 Google Credential Manager가 결과를 반환한 직후 앱의 서버 교환 단계에서 Dart `_TypeError`가 났다.

| 일시 (KST) | 기기 로그 |
| --- | --- |
| 2026-09-19 00:15:34.259 | `GetCredentialResponse returned from framework` |
| 2026-09-19 00:15:34.666 | `SnapHereAuth stage=exchange type=_TypeError` |
| 2026-09-19 00:16:24.224 | `GetCredentialResponse returned from framework` |
| 2026-09-19 00:16:24.272 | `SnapHereAuth stage=exchange type=_TypeError` |

- 운영 서버의 `/actuator/health`는 200 `UP`이다. 임의의 무효 ID 토큰으로 `POST /api/v1/auth/google`을 호출하면 구조화된 401 `AUTH_INVALID_GOOGLE_TOKEN` 응답이 나온다. **유효 토큰을 사용한 운영 서버의 성공 응답은 아직 확인하지 못했다.**
- 앱 AAB와 원스토어 배포 APK에 운영 HTTPS 주소 및 Web OAuth 클라이언트 ID가 포함된 것을 확인했다. 원스토어 배포 서명 SHA-1은 Google Cloud에 이미 등록돼 있다고 사용자가 밝혔다. 등록 프로젝트의 일치 여부는 확인하지 못했다.
- `_TypeError`는 앱이 서버 교환 중 받은 값을 기대한 형식으로 해석할 때도, 요청 전 기기 ID를 처리할 때도 발생할 수 있다. 현재 로그만으로 HTTP 요청 도달 여부나 실제 응답 상태를 단정하지 않는다.

## 서버 담당자 확인 요청

1. **요청 도달과 결과:** 위 두 시각 전후 1분의 프록시·애플리케이션 로그에서 `POST /api/v1/auth/google` 요청 도달 여부, HTTP 상태, `traceId`, 처리 시간, 예외 클래스·오류 코드를 확인해 주세요. 요청이 없다면 프록시 접근 로그에서 해당 경로의 요청·응답을 확인해 주세요.
2. **200 응답이라면 계약 확인:** 운영 배포본의 성공 응답에서 최상위 `success=true`, `data` 객체, `data.tokens` 객체의 `accessToken`·`refreshToken` 문자열, `data.user` 객체의 `userId` 문자열, `data.onboardingRequired` 불리언이 존재하는지 **값 없이 자료형과 존재 여부만** 확인해 주세요. 백엔드의 `AuthDtos.AuthResult`·`ApiResponse`와 프론트엔드 `ApiAuthRepository._sessionFromAuthResult`가 기대하는 구조입니다.
3. **복구 분기 확인:** `recoveryOffered=true`이면 현재 백엔드 구현은 `tokens=null`, `user=null`을 반환해 앱의 기존 세션 파싱에서 타입 오류가 날 수 있습니다. 해당 분기가 실행됐는지와 그 근거가 된 계정 상태를 확인해 주세요. 사용자는 탈퇴 이력이 없다고 답했습니다. 계정 식별 정보는 회신에 포함하지 않아도 됩니다.
4. **4xx/5xx 또는 예외라면:** 오류 코드, `traceId`, 서버 예외 원인과 배포된 백엔드 버전·이미지 태그를 알려주세요. Google 토큰의 audience 문제라면 운영 서버의 `GOOGLE_OAUTH_CLIENT_ID`가 앱이 사용하는 **같은 Google Cloud 프로젝트의 Web OAuth 클라이언트 ID**인지 확인해 주세요. 설정값 원문은 보내지 않아도 됩니다.
5. **응답 형식이 다르다면:** 운영 서버가 반환하는 필드명·자료형만 전달해 주세요. API 계약을 바꿔야 하는지, 배포본이 저장소 코드보다 오래됐는지 함께 확인하겠습니다.

## 회신 형식

- 두 시각 각각: 요청 도달 여부 / HTTP 상태 / `traceId` / 오류 코드 또는 예외 클래스
- 200인 경우: `data`, `tokens`, `user`, `onboardingRequired`, `recoveryOffered`의 **존재 여부와 자료형만**
- 운영 배포 버전 또는 이미지 태그, 확인된 원인과 조치 예정 내용

**ID 토큰, 액세스·리프레시 토큰, 이메일, 계정 ID, 요청·응답 원문은 공유하지 말아 주세요.**

## 앱 쪽 후속 진단

PR #70의 `e1d9eac`에는 서버 교환 내부의 `device-id`·`http`·`response-map`·`session-map` 단계와 필수 필드 자료형만 남기는 로그가 추가됐다. 해당 AAB를 원스토어에서 생성한 APK로 재시험하면 `SnapHereAuth exchangePhase=...`가 출력된다. 이 빌드의 실기기 재시험 결과는 아직 없다.
