# 단위 테스트 검증 기록

## 개요

- **일자**: 2026-09-11
- **대상**: SnapHere Flutter 앱 (`app/`)
- **목적**: 원스토어 제출을 앞두고 빌드 가능 여부와 단위 테스트 통과 여부 검증
- **환경**: Flutter 3.47.3 · Dart 3.13.3 · Linux (WSL2)

## 수행 절차

```bash
flutter pub get      # 의존성 설치
flutter analyze      # 정적 분석
flutter test         # 단위·위젯 테스트
```

## 발견 및 수정: 컴파일 차단 오류

`flutter analyze` 실행 시 `lib/src/features/upload/data/device_upload_repository.dart`
한 파일에서 오류 5개가 발생하여 **앱이 빌드되지 않는 상태**였다.

### 원인

`_numericId` 메서드가 반환 타입이 다른 두 버전으로 **중복 정의**되어 있었다(병합 흔적).

- `String _numericId(...)` — 접두사만 제거한 문자열 반환
- `int _numericId(...)` — `int.parse`까지 수행해 정수 반환 (중복)

이 중복 때문에 `duplicate_definition` 오류가 나고, 호출부 4곳의 타입도 어긋났다.

### 수정 내용

1. 중복된 `int _numericId(...)` 정의를 제거하고 `String` 버전만 남김.
2. `POST /posts` 요청 본문의 `placeId`·`eventId`를 `int.parse(...)`로 감싸 **정수(JSON number)**로 전송하도록 변경.

수정 근거는 백엔드 계약이다. 세 엔드포인트 모두 정수형으로 선언되어 있다.

| 엔드포인트 | 필드 | 백엔드 타입 |
| --- | --- | --- |
| `POST /posts` (`CreatePostRequest`) | `placeId`, `eventId` | `Long` |
| `POST /posts/tier-preview` (`TierPreviewRequest`) | `placeId`, `eventId` | `Long` |
| `GET /tags/suggestions` (`TagController`) | `placeId` / `eventId` | `long` / `Long` |

`tier-preview`는 이미 `int.parse`로 정수를 보내고 있었으나 `POST /posts`만 문자열로
보내고 있어, 계약과 어긋나는 잠재적 불일치를 함께 바로잡았다. 쿼리 파라미터
(`/tags/suggestions`)는 URL 문자열로 나가므로 문자열 그대로 유지했다.

**변경 파일**: `lib/src/features/upload/data/device_upload_repository.dart` (3 insertions, 5 deletions)

## 결과

### 정적 분석

```
flutter analyze  →  No issues found! (0 errors)
```

### 단위·위젯 테스트

```
flutter test  →  130 passed, 1 failed
```

#### 실패 1건 (사전 존재, 이번 수정과 무관)

- **테스트**: `test/profile_screen_test.dart` — `own post keeps the Figma 160px image and settings actions`
- **증상**: `"로그아웃"` 텍스트 위젯을 1개 기대했으나 0개 발견 (`Found 0 widgets with text "로그아웃"`)
- **성격**: 프로필 화면 UI와 테스트 기대값의 드리프트. 업로드 로직과 무관.
- **확인**: 이번 수정을 stash 하고 원본 상태에서 실행해도 동일하게 실패 → **기존부터 깨져 있던 테스트**임을 확인.
- **조치**: 별도 이슈로 분리 필요 (본 작업 범위 밖).

## 단위 테스트가 보장하지 않는 것

단위·위젯 테스트는 HTTP를 목(mock)으로 대체하므로 **실제 네트워크·백엔드·S3 연동은 검증하지 않는다.**
아래 항목은 실제 백엔드 구동 + 실기기에서 별도 확인이 필요하다.

- 실제 API 호출 성공 여부 (앱 기본 `API_BASE_URL`은 `https://snaphere.duckdns.org`; 로컬 서버 테스트 시 `--dart-define=API_BASE_URL=...` 지정)
- 이미지의 실제 S3 업로드 (백엔드 `MEDIA_PROVIDER` 기본값이 `stub` → 실제 업로드는 `MEDIA_PROVIDER=s3` + 버킷/자격증명 설정 시에만 동작)
- Google Maps · Google OAuth 실제 키 동작
- 카메라·위치·사진 권한의 실기기 동작
