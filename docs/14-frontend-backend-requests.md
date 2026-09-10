# 프론트엔드 → 백엔드 요청 목록

Figma `Wireframe_v3`의 `07 Shared Detail`(게시글 상세 · 장소 상세 · 알림 · 설정),
`08 Error & Empty States`, `12 Comment CRUD Prototype`을 구현하면서 확인한
백엔드 부족분이다. 화면은 모두 만들었고, 아래 항목이 채워지기 전까지는 해당
영역만 값이 비거나 기기 로컬 저장으로 대체된다.

우선순위는 `P0` 화면이 기능을 못 함 · `P1` 값이 비어 보임 · `P2` 있으면 좋음이다.

---

## 1. 알림 — 컨트롤러 전체 부재 (P0)

명세 `API-NTF-001~004`와 ERD `notifications` 테이블은 있는데 백엔드에
`NotificationController`가 없다. 앱은 지금 `USE_FAKE_NOTIFICATIONS=true`로
목 데이터를 그린다 (`app/lib/src/features/notification/application/notification_providers.dart`).

| API ID | Method | Path | 응답 |
|---|---|---|---|
| API-NTF-001 | GET | `/api/v1/notifications` | `CursorPage<Notification>` |
| API-NTF-002 | GET | `/api/v1/notifications/unread-count` | `{ "count": int }` |
| API-NTF-003 | PATCH | `/api/v1/notifications/{notificationId}/read` | `Notification` |
| API-NTF-004 | POST | `/api/v1/notifications/read-all` | 204 |

앱이 기대하는 `Notification` 필드:

```json
{
  "notificationId": "ntf_1",
  "type": "POST_LIKE",
  "targetType": "POST",
  "targetId": "pst_1",
  "messageKey": "notification.post.like",
  "messageParams": { "actorNickname": "서울여행러" },
  "isRead": false,
  "createdAt": "2026-09-09T10:00:00+09:00"
}
```

문장은 앱이 조립한다 (NTF-009, SYS-010). 서버는 `messageKey`와 `messageParams`만
보내면 된다. 앱이 아는 키와 파라미터는
`app/lib/src/features/notification/domain/notification_messages.dart`에 있다.

### 1-1. `notification_type` 값 부족 (P0)

ERD는 `POST_LIKE · FOLLOW · BADGE_EARNED · SYSTEM` 네 가지인데 Figma
`07_알림_목록`은 여섯 줄을 그린다. **두 값이 없다.**

| 화면의 줄 | 필요한 type | 현재 ERD |
|---|---|---|
| `Emily님이 댓글을 남겼어요: "..."` | `COMMENT` | **없음** |
| `팔로잉하는 서울여행러님이 새 게시글을 올렸어요` | `NEW_POST` | **없음** |

`docs/12-db-schema.dbml`의 `enum notification_type`과 `02-feature-spec.md` 8.1
(현재 "좋아요 / 팔로우 / 뱃지 획득"만 적혀 있음)을 함께 고쳐야 한다.
앱은 두 값을 이미 받을 수 있고, 모르는 값은 `SYSTEM`으로 떨어뜨린다.

---

## 2. 댓글

### 2-1. `CommentResponse`에 `createdAt` 없음 (P1)

Figma `07_댓글_상세_목록`은 댓글마다 `방금 전`을 표시하는데
`com.snaphere.api.comment.dto.CommentResponse`에 시각 필드가 없다.
`CommentEntity.createdAt`은 이미 있으므로 응답에 노출만 하면 된다.
지금은 앱이 시각을 못 받아 그 줄을 통째로 숨긴다.

### 2-2. 댓글 좋아요 미구현 (P2)

명세 `API-CMU-009` / `API-CMU-010` (`PUT`·`DELETE /api/v1/comments/{commentId}/like`)이
`CommentThreadController`에 없다. 디자인의 `좋아요 3`은 지금 누를 수 없는
숫자 표시로만 그려 두었다.

---

## 3. 게시글

### 3-1. `PostDetailResponse.event`가 항상 null (P1)

`PostDetailResponse`의 `event` 필드가 `Object` 타입에 `of(...)`에서 `null`로 고정돼
있다. Figma `07_게시글_상세`는 `🏆 2026 전주 한옥마을 봄축제` 칩을 그리는데,
지금은 태그로만 대체하고 있다. `posts.event_id`는 이미 있으므로 이벤트 요약
(`eventId`, `title`, `status`)을 채워주면 칩을 행사 상세로 연결할 수 있다.

### 3-2. 게시글 제목 칼럼 부재 — 확인 필요 (P2)

`posts` 테이블에 `title`이 없다. 업로드가 `제목\n본문`을 `content` 하나로 합쳐
보내고 있어서(`device_upload_repository.dart`) 상세도 같은 규칙으로 첫 줄을
제목으로 잘라 쓴다. 지금은 동작하지만, 본문 첫 줄에 줄바꿈을 넣은 글에서
제목이 이상해진다. 다음 중 하나를 정해야 한다.

- 현행 관례 유지 (백엔드 변경 없음)
- `posts.title varchar(100)` 추가 후 `CreatePostRequest`·`PostSummaryResponse`에 반영

---

## 4. 장소 상세 — 응답에 없는 표시 항목 (P1)

Figma `07_장소_상세`가 요구하는데 `PlaceDtos.PlaceDetail`에 없는 값들이다.
현재는 이 줄들을 그리지 않고 `게시글 N개 · 방문자 N명 · 랭킹 N위`로 대체했다.

| 화면 요소 | 필요한 필드 | 비고 |
|---|---|---|
| `⭐ 4.9` | `rating`, `ratingCount` | 평점 출처 결정 필요 (TourAPI에 없음) |
| `매일 · 입장 무료` | `openingHours`, `admissionFee` | TourAPI 상세 항목에 있음 |
| `관련 행사` 카드 | `relatedEvents[]` | `events` 테이블과 장소 연결 |

평점은 데이터 출처 자체가 없어서, 넣지 않기로 정하고 Figma를 고치는 쪽도
선택지다. 결정되면 알려주면 화면에서 뺀다.

---

## 5. 설정

### 5-1. 전체 번역 — `translations`가 항상 null (P1)

`설정 > 표시 > 전체 번역` 스위치와 언어 선택(`ko-KR · en-US · zh-CN · ja-JP`)을
붙였다. 언어는 `PATCH /me`의 `locale`로 저장된다.

다만 `PostDetailResponse.translations`가 `Map<String, Object?>` 타입에
`of(...)`에서 `null`로 고정돼 있어서, 스위치를 켜도 보여줄 번역문이 없다.
원문 언어(`originalLanguageCode`)는 이미 오고 있으니 번역 파이프라인이 붙으면
`translations`에 `{ "en-US": {...} }` 형태로 채워주면 화면은 그대로 동작한다 (SYS-010).

### 5-2. 알림 설정 — 요청 없음 (해결됨)

`PATCH /me/notification-preferences`(`postLike` · `follow` · `badgeEarned`)와
`GET /me`의 `notificationPreferences`가 이미 있어서 그대로 붙였다.
화면은 Figma대로 `푸시 알림` 한 줄이라 세 값을 함께 켜고 끈다.
종류별로 나눠 보여줄지는 디자인 결정 사항이다.

---

## 6. 프론트엔드 쪽 후속 (백엔드 요청 아님)

기록용이다. 백엔드 작업은 필요 없다.

- `UploadScreen`이 `placeId` 프리필을 받지 않아 장소 상세의
  `이 장소에 사진 올리기`가 GPS 매칭에 의존한다.
- `MapScreen`이 좌표 파라미터를 받지 않아 `지도에서 보기`가 지도 첫 화면으로 간다.
- 게시글 수정 화면 미구현 (`PATCH /posts/{postId}`는 준비됨).

---

## 부록 — 앱이 실제로 부르는 엔드포인트

이번에 붙인 화면이 호출하는 목록이다. 계약 확인용.

| 화면 | 호출 |
|---|---|
| 게시글 상세 | `GET /posts/{id}` · `PUT`·`DELETE /posts/{id}/like` · `PUT`·`DELETE /posts/{id}/bookmark` · `POST /posts/{id}/reports` · `DELETE /posts/{id}` |
| 댓글 | `GET`·`POST /posts/{id}/comments` · `POST /comments/{id}/replies` · `PATCH`·`DELETE /comments/{id}` |
| 장소 상세 | `GET /places/{id}` · `GET /places/{id}/posts` · `PUT`·`DELETE /places/{id}/bookmark` |
| 알림 | `GET /notifications` · `GET /notifications/unread-count` · `PATCH /notifications/{id}/read` · `POST /notifications/read-all` |
| 설정 | `GET /me` · `PATCH /me` (locale) · `PATCH /me/notification-preferences` · `POST /me/deletion` |
