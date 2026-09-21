# API 명세서

> API 명세서 · ERD **v1.1.7** · REST/JSON · Base URL `/api/v1`
>
> 모든 엔드포인트는 요구사항 ID에 매핑돼 있다. 매핑되지 않은 엔드포인트는 없다(§7).

## 1. 엔드포인트 목록 (97개)

### 인증

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-AUTH-001 | 구글 로그인·가입 | POST | /api/v1/auth/google | Public | Must | Google ID Token을 검증하고 로그인·최초 가입·탈퇴 복구 제안을 처리한다. | GoogleLoginRequest | AuthResult | 200 | AUTH_INVALID_GOOGLE_TOKEN, AUTH_AUDIENCE_MISMATCH, USER_WITHDRAWN, COMMON_500 | - | - | AUTH-001~003, USER-020 | users, user_devices, refresh_tokens |
| API-AUTH-002 | 최초 온보딩 완료 | POST | /api/v1/auth/onboarding | Bearer | Must | 닉네임과 약관 동의를 저장하고 계정을 활성화한다. | OnboardingRequest | MyProfile | 201 | AUTH_REQUIRED, USER_NICKNAME_INVALID, AUTH_TERMS_REQUIRED, COMMON_409 | - | - | AUTH-004, USER-003, USER-006 | users |
| API-AUTH-003 | 토큰 재발급 | POST | /api/v1/auth/refresh | Public | Must | 리프레시 토큰을 1회 회전하고 새 토큰 묶음을 발급한다. | RefreshRequest | TokenBundle | 200 | AUTH_REFRESH_EXPIRED, AUTH_TOKEN_REUSED, AUTH_INVALID_REFRESH, COMMON_500 | - | - | AUTH-007~009 | refresh_tokens, user_devices |
| API-AUTH-004 | 현재 기기 로그아웃 | POST | /api/v1/auth/logout | Bearer | Must | 현재 기기의 리프레시 토큰을 폐기하고 FCM 토큰을 제거한다. | - | Empty | 204 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 | AUTH-005 | refresh_tokens, user_devices |
| API-AUTH-005 | 전체 기기 로그아웃 | POST | /api/v1/auth/logout-all | Bearer | Should | 사용자의 모든 리프레시 토큰을 폐기한다. | - | Empty | 204 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 | AUTH-006 | refresh_tokens |
| API-AUTH-006 | 탈퇴 계정 복구 | POST | /api/v1/auth/restore | Public | Should | 30일 유예 중인 계정을 복구하고 새 온보딩 정보를 받는다. | RestoreAccountRequest | AuthResult | 200 | USER_RECOVERY_EXPIRED, USER_RESTORE_KEY_INVALID, COMMON_409 | - | - | USER-020~021 | users, account_deletion_logs, refresh_tokens |

### 사용자

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-USER-001 | 내 프로필 조회 | GET | /api/v1/me | Bearer | Must | 내 프로필·통계·알림 설정을 조회한다. | - | MyProfile | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | USER-001, USER-009 | users |
| API-USER-002 | 내 프로필 수정 | PATCH | /api/v1/me | Bearer | Must | 닉네임·소개·프로필 이미지·표시 언어를 부분 수정한다. | UpdateProfileRequest | MyProfile | 200 | AUTH_REQUIRED, USER_NICKNAME_INVALID, MEDIA_NOT_FOUND, COMMON_409 | - | - | USER-002~003 | users<br>※ null은 필드 제거, 누락은 변경 없음 |
| API-USER-003 | 기기·FCM 토큰 등록 | PUT | /api/v1/me/device | Bearer | Must | 앱 시작 시 기기 정보와 FCM 토큰을 UPSERT한다. | DeviceUpsertRequest | DeviceResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 UPSERT | USER-007, NTF-010 | user_devices |
| API-USER-004 | 타 사용자 프로필 조회 | GET | /api/v1/users/{userId} | Bearer(optional) | Must | 공개 프로필·통계와 요청자 기준 팔로우 상태를 조회한다. | - | UserProfile | 200 | USER_NOT_FOUND, COMMON_500 | - | - | USER-005 | users, follows |
| API-USER-005 | 사용자 게시글 목록 | GET | /api/v1/users/{userId}/posts | Bearer(optional) | Must | 특정 사용자의 공개 게시글을 최신순으로 조회한다. | - | CursorPage<PostSummary> | 200 | USER_NOT_FOUND, COMMON_500 | cursor | - | USER-008, USER-010, SOC-013 | posts, post_images |
| API-USER-006 | 좋아요한 게시글 | GET | /api/v1/me/liked-posts | Bearer | Should | 내가 좋아요한 공개 게시글을 최신 반응순으로 조회한다. | - | CursorPage<PostSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | USER-011 | likes, posts, post_images |
| API-USER-007 | 저장함 조회 | GET | /api/v1/me/bookmarks | Bearer | Should | 저장한 게시글 또는 장소를 조회한다. | - | CursorPage<BookmarkItem> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | USER-012~013 | bookmarks, posts, places |
| API-USER-008 | 계정 삭제 미리보기 | GET | /api/v1/me/deletion-preview | Bearer | Should | 탈퇴 시 영향받는 데이터 개수를 조회한다. | - | DeletionPreview | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | USER-014 | users, posts, comments, follows, visits, user_badges |
| API-USER-009 | 계정 삭제 요청 | POST | /api/v1/me/deletion | Bearer | Must | 30일 유예 탈퇴를 접수하고 개인정보를 즉시 파기한다. | DeleteAccountRequest | DeletionReceipt | 202 | AUTH_REQUIRED, USER_ALREADY_WITHDRAWN, COMMON_409 | - | - | USER-015~019, BDG-014 | users, account_deletion_logs, follows, likes, bookmarks |
| API-USER-010 | 알림 수신 설정 | PATCH | /api/v1/me/notification-preferences | Bearer | Could | 좋아요·팔로우·뱃지 알림 수신 여부를 부분 수정한다. | NotificationPreferences | NotificationPreferences | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | USER-023 | users |
| API-USER-011 | 최근 본 장소 | GET | /api/v1/me/recent-places | Bearer | Could | 최근 본 장소를 사용자별로 조회한다. | - | CursorPage<PlaceSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | VST-006 | Redis 또는 별도 recent_place_views<br>※ 원본 26개 테이블에는 저장소가 없어 Redis/별도 테이블 결정 필요 |

### 소셜

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-SOC-001 | 팔로우 | PUT | /api/v1/users/{userId}/follow | Bearer | Must | 사용자를 멱등하게 팔로우하고 최신 카운터를 반환한다. | - | FollowResult | 200 | SOC_SELF_FOLLOW, SOC_DAILY_LIMIT, USER_NOT_FOUND, COMMON_500 | - | 멱등 PUT | SOC-001~007 | follows, users |
| API-SOC-002 | 언팔로우 | DELETE | /api/v1/users/{userId}/follow | Bearer | Must | 팔로우를 멱등하게 해제하고 최신 카운터를 반환한다. | - | FollowResult | 200 | USER_NOT_FOUND, COMMON_500 | - | 멱등 DELETE | SOC-001~004, SOC-007 | follows, users |
| API-SOC-003 | 팔로워 목록 | GET | /api/v1/users/{userId}/followers | Bearer(optional) | Must | 팔로워 목록과 요청자 기준 맞팔 상태를 조회한다. | - | CursorPage<UserSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | SOC-010, SOC-012 | follows, users |
| API-SOC-004 | 팔로잉 목록 | GET | /api/v1/users/{userId}/following | Bearer(optional) | Must | 팔로잉 목록과 요청자 기준 팔로우 상태를 조회한다. | - | CursorPage<UserSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | SOC-011~012 | follows, users |
| API-SOC-005 | 추천 사용자 | GET | /api/v1/users/recommendations | Bearer | Could | 팔로잉 빈 상태에 노출할 추천 사용자를 조회한다. | - | UserSummary[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | SOC-014, CMU-001 | users, follows |

### 장소

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-PLC-001 | 시도 목록 | GET | /api/v1/regions | Public | Must | 17개 시도와 대표 이미지·기본 이벤트 반경을 조회한다. | - | Region[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 24h | PLC-001, MAP-004, MAP-006 | regions |
| API-PLC-002 | 시군구 목록 | GET | /api/v1/regions/{areaCode}/sigungu | Public | Must | 시도에 속한 시군구 마스터를 조회한다. | - | Sigungu[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 24h | PLC-002 | sigungu, regions |
| API-PLC-003 | 장소 목록 | GET | /api/v1/places | Bearer(optional) | Must | 지역·타입·키워드로 장소를 검색한다. | - | CursorPage<PlaceSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | PLC-011, SYS-018 | places |
| API-PLC-004 | 주변 장소 | GET | /api/v1/places/nearby | Bearer(optional) | Must | 좌표와 반경으로 주변 장소를 거리순 조회하고 인증 가능 여부를 표시한다. | - | NearbyPlaceResult | 200 | PLACE_INVALID_COORDINATE, PLACE_RADIUS_TOO_LARGE, COMMON_500 | - | - | MAP-026~030 | places |
| API-PLC-005 | 장소 상세 | GET | /api/v1/places/{placeId} | Bearer(optional) | Must | 장소 정보·통계·조회수·랭킹·주변 장소를 조회하고 상세가 없으면 요청 언어로 지연 적재한다. | - | PlaceDetail | 200 | PLACE_NOT_FOUND, COMMON_503 | - | 10m, 조회수는 비동기 | PLC-006, PLC-012, PLC-014, SYS-012 | places, place_details, place_rankings / ※ place_details는 (place_id, language_code) 단위 |
| API-PLC-006 | 장소 게시글 | GET | /api/v1/places/{placeId}/posts | Bearer(optional) | Must | 해당 장소의 공개 게시글을 조회한다. | - | CursorPage<PostSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | PLC-013 | posts, post_images |
| API-PLC-007 | 사용자 장소 생성 | POST | /api/v1/places | Bearer | Must | 대한민국 내 새 장소를 생성하거나 100m 내 동일 장소를 재사용한다. | CreatePlaceRequest | CreatePlaceResult | 201 / 200 | PLACE_OUT_OF_SERVICE_AREA, PLACE_DAILY_LIMIT, PLACE_INVALID_COORDINATE, COMMON_422 | - | Idempotency-Key 권장 | PLC-016~020 | places, sigungu, regions / ※ 신규 201 created=true, 100m 내 중복 재사용 200 created=false + duplicateOfPlaceId |
| API-PLC-008 | 장소 저장 | PUT | /api/v1/places/{placeId}/bookmark | Bearer | Should | 장소를 저장함에 멱등 추가한다. | - | BookmarkResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 PUT | PLC-015, CMU-024 | bookmarks, places |
| API-PLC-009 | 장소 저장 해제 | DELETE | /api/v1/places/{placeId}/bookmark | Bearer | Should | 장소 저장을 멱등 해제한다. | - | BookmarkResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 DELETE | PLC-015 | bookmarks |

### 게시글

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-PST-001 | 업로드 주소 발급 | POST | /api/v1/media/presigned-urls | Bearer | Must | 게시글 원본은 비공개 `originals/` 키로, 프로필 이미지는 `profile/` 키로 5분 Presigned URL을 발급한다. jpeg·png·heic·webp, 장당 10MB 이하. | PresignRequest | UploadUrl[] | 201 | MEDIA_COUNT_INVALID, MEDIA_TOO_LARGE, MEDIA_TYPE_UNSUPPORTED, COMMON_429 | - | URL 5분 | USER-004, PST-013~015, SYS-020 | S3, post_images<br>※ 게시글 원본은 공개 URL로 변환하지 않는다. |
| API-PST-002 | 신뢰도 미리보기 | 앱 내부 | - | - | Should | 앱이 대표 사진과 선택 장소 좌표로 기기 안에서 예상 신뢰도를 계산한다. 사진·기기 원 좌표와 촬영 시각을 전송하지 않는다. | - | LocalTierResult | - | - | - | PST-022~028, PST-048~049 | 서버 호출 없음 |
| API-PST-003 | 게시글 생성 | POST | /api/v1/posts | Bearer | Must | 게시글을 만들고 `postId`와 `mediaStatus=PROCESSING`을 반환한다. 정제본 준비 전에는 공개하지 않는다. | CreatePostRequest | CreatePostResult | 201 | POST_IMAGE_REQUIRED, POST_PLACE_REQUIRED, POST_TAG_REQUIRED, POST_DAILY_LIMIT, POST_PLACE_DAILY_LIMIT, POST_DUPLICATE_IMAGE, POST_UPLOAD_SUSPENDED, COMMON_422 | - | Idempotency-Key 필수 | PST-001~006, PST-008~011, PST-016~032, EVT-016~023, VST-001~002, BDG-005~006 | `localTier`만 수신하며 사진·기기 원 좌표와 정확한 촬영 시각은 수신하지 않음 |
| API-PST-004 | 게시글 목록 | GET | /api/v1/posts | Bearer(optional) | Must | 지역·장소·태그·기간으로 공개 게시글을 조회한다. | - | CursorPage<PostSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | PST-021, PST-034, SYS-018 | posts, post_images, post_tags |
| API-PST-005 | 인기 게시글 | GET | /api/v1/posts/popular | Bearer(optional) | Must | 지도·탐색용 기간별 인기 게시글을 사전 집계(post_rankings)에서 조회한다. 커뮤니티 인기 탭은 API-CMU-001을 쓴다. | - | CursorPage<PostSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | 집계 테이블 조회, 요청 시 계산 금지 | PST-035, CMU-008 | post_rankings, posts, post_images / ※ 지도·탐색 진입점. 커뮤니티 인기 탭과 역할 분리(B-2) |
| API-PST-006 | 게시글 상세 | GET | /api/v1/posts/{postId} | Bearer(optional) | Must | 사진·캡션·태그·장소·작성자·신뢰도 근거를 조회한다. | - | PostDetail | 200 | POST_NOT_FOUND, POST_NOT_VISIBLE, POST_MEDIA_PROCESSING, POST_MEDIA_FAILED, COMMON_500 | - | 공개 60s; 조회수 24h 중복 제거 | PST-033, PST-042, PST-046~047, SYS-010, SYS-021 | posts, post_images, post_tags, users, places<br>※ 작성자만 처리 상태 409, 그 외에는 404 |
| API-PST-007 | 게시글 수정 | PATCH | /api/v1/posts/{postId} | Bearer | Should | 작성자가 캡션·태그·사진 순서만 수정한다. | UpdatePostRequest | PostDetail | 200 | POST_NOT_AUTHOR, POST_NOT_FOUND, POST_TAG_REQUIRED, COMMON_422 | - | - | AUTH-013, PST-036~037, CMU-032 | posts, post_images, post_tags<br>※ placeId, lat/lng, tier, source는 수정 불가 |
| API-PST-008 | 게시글 삭제 | DELETE | /api/v1/posts/{postId} | Bearer | Must | 작성자가 게시글을 논리 삭제하고 미디어 30일 후 삭제를 예약한다. | - | Empty | 204 | POST_NOT_AUTHOR, POST_NOT_FOUND, COMMON_409 | - | - | AUTH-013, PST-038~039, SYS-006 | posts, post_images<br>※ 방문·기지급 뱃지는 유지 |
| API-PST-009 | 게시글 좋아요 | PUT | /api/v1/posts/{postId}/like | Bearer | Must | 게시글 좋아요를 멱등 등록한다. | - | LikeResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 PUT | PST-040~041 | likes, posts |
| API-PST-010 | 게시글 좋아요 해제 | DELETE | /api/v1/posts/{postId}/like | Bearer | Must | 게시글 좋아요를 멱등 해제한다. | - | LikeResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 DELETE | PST-040 | likes, posts |
| API-PST-011 | 게시글 저장 | PUT | /api/v1/posts/{postId}/bookmark | Bearer | Should | 게시글을 저장함에 멱등 추가한다. | - | BookmarkResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 PUT | CMU-023~024 | bookmarks, posts |
| API-PST-012 | 게시글 저장 해제 | DELETE | /api/v1/posts/{postId}/bookmark | Bearer | Should | 게시글 저장을 멱등 해제한다. | - | BookmarkResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 DELETE | CMU-023 | bookmarks |
| API-PST-013 | 게시글 신고 | POST | /api/v1/posts/{postId}/reports | Bearer | Should | 게시글을 사유 코드와 함께 신고한다. | CreateReportRequest | ReportReceipt | 201 | REPORT_DUPLICATE, POST_NOT_FOUND, COMMON_422 | - | - | PST-043~045 | reports, posts<br>※ 누적 3회 시 자동 블라인드 후 운영자 검토 |
| API-PST-014 | 공유 메타데이터 | GET | /api/v1/public/posts/{postId}/share-metadata | Public | Must | 공개 웹 공유 페이지의 OG 제목·설명·썸네일·딥링크를 반환한다. | - | ShareMetadata | 200 | POST_NOT_FOUND, POST_NOT_VISIBLE | - | 5m | CMU-019~022 | posts, post_images |

### 커뮤니티

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-CMU-001 | 인기 피드 | GET | /api/v1/feeds/popular | Bearer(optional) | Must | 커뮤니티 인기 탭 피드를 사전 집계(post_rankings) 기준으로 조회하고 팔로잉 가중치를 적용한다. | - | CursorPage<PostSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | 1m, 집계 테이블 조회 | CMU-002, CMU-004, CMU-007~010 | post_rankings, posts, follows / ※ 커뮤니티 탭 전용. 지도·탐색은 API-PST-005 |
| API-CMU-002 | 팔로잉 피드 | GET | /api/v1/feeds/following | Bearer | Must | 팔로우한 사용자의 게시글을 조회하며 빈 경우 추천 사용자를 함께 준다. | - | FollowingFeedResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | CMU-001, CMU-004, CMU-010, SOC-014 | posts, follows, users |
| API-CMU-003 | 최근 피드 | GET | /api/v1/feeds/recent | Bearer(optional) | Must | 최신 공개 게시글을 시간순으로 조회한다. | - | CursorPage<PostSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | CMU-003~004, CMU-010 | posts, post_images |
| API-CMU-004 | 댓글 목록 | GET | /api/v1/posts/{postId}/comments | Bearer(optional) | Must | 부모 댓글을 커서 페이징하고 각 부모의 대댓글을 함께 조회한다. | - | CursorPage<CommentThread> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | 부모 댓글 cursor | - | CMU-013, CMU-015 | comments, users, likes |
| API-CMU-005 | 댓글 작성 | POST | /api/v1/posts/{postId}/comments | Bearer | Must | 게시글에 최상위 댓글을 작성한다. | CreateCommentRequest | Comment | 201 | COMMENT_LENGTH_INVALID, POST_NOT_FOUND, COMMON_422 | - | - | CMU-012 | comments, posts |
| API-CMU-006 | 대댓글 작성 | POST | /api/v1/comments/{commentId}/replies | Bearer | Must | 댓글 스레드에 깊이 1단계 대댓글을 작성한다. | CreateCommentRequest | Comment | 201 | COMMENT_LENGTH_INVALID, COMMENT_NOT_FOUND, COMMON_422 | - | - | CMU-014~015 | comments<br>※ commentId가 대댓글이면 최상위 parent_id로 정규화 |
| API-CMU-007 | 댓글 수정 | PATCH | /api/v1/comments/{commentId} | Bearer | Should | 작성자가 댓글 내용을 수정한다. | UpdateCommentRequest | Comment | 200 | COMMENT_NOT_AUTHOR, COMMENT_NOT_FOUND, COMMENT_LENGTH_INVALID | - | - | AUTH-013, CMU-016 | comments |
| API-CMU-008 | 댓글 삭제 | DELETE | /api/v1/comments/{commentId} | Bearer | Must | 댓글을 논리 삭제하고 자식이 있으면 자리표시자를 남긴다. | - | Empty | 204 | COMMENT_NOT_AUTHOR, COMMENT_NOT_FOUND | - | - | AUTH-013, CMU-017 | comments |
| API-CMU-009 | 댓글 좋아요 | PUT | /api/v1/comments/{commentId}/like | Bearer | Could | 댓글 좋아요를 멱등 등록한다. | - | LikeResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 PUT | CMU-018 | likes, comments |
| API-CMU-010 | 댓글 좋아요 해제 | DELETE | /api/v1/comments/{commentId}/like | Bearer | Could | 댓글 좋아요를 멱등 해제한다. | - | LikeResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 DELETE | CMU-018 | likes, comments |
| API-CMU-011 | 태그 추천 | GET | /api/v1/tags/suggestions | Bearer | Must | 장소 지역·콘텐츠 유형·진행 이벤트 기준 태그를 추천한다. | - | TagSuggestion[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | PLC-021, CMU-025~029, EVT-017~020 | tags, events, places |
| API-CMU-012 | 인기 태그 | GET | /api/v1/tags/popular | Public | Could | 지역별 인기 태그를 사용 횟수 순으로 조회한다. | - | TagSummary[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 10m | CMU-031 | tags, post_tags |
| API-CMU-013 | 태그 게시글 | GET | /api/v1/tags/{tagId}/posts | Bearer(optional) | Should | 태그가 붙은 공개 게시글을 조회한다. | - | CursorPage<PostSummary> | 200 | TAG_NOT_FOUND, COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | CMU-030, SCH-007 | tags, post_tags, posts |

### 지도

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-MAP-001 | 지역 레이어 | GET | /api/v1/map/regions | Public | Must | 시도별 게시글 수와 대표 이미지 마커를 조회한다. | - | MapRegion[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 10m | MAP-004~007 | region_stats, regions / ※ period는 heatmap_period 공유 |
| API-MAP-002 | 히트맵 | GET | /api/v1/map/heatmap | Public | Must | 화면 범위·줌·기간에 맞는 정규화 히트맵 셀을 반환한다. | - | HeatmapResult | 200 | MAP_INVALID_BOUNDS, COMMON_500 | - | nextRefreshAt까지 | MAP-008~019 | heatmap_cells<br>※ LAST_1H 5건 미만이면 LAST_24H 폴백. 게시글 수 상위 500셀을 반환하고 초과 시 truncated=true |
| API-MAP-003 | 사진 마커 | GET | /api/v1/map/photo-markers | Public | Must | 축소 시 최대 10개 후보, 확대 시 단일 사진의 지도 마커를 반환한다. | - | PhotoMarker[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 10m | MAP-020~025 | heatmap_cells, posts, post_images<br>※ 클라이언트가 후보를 3초 간격으로 교체하며 재요청하지 않음 |
| API-MAP-004 | 히트맵 셀 상세 | GET | /api/v1/map/cells/{cellKey} | Public | Should | 선택한 셀의 대표 장소와 집계값을 반환한다. | - | HeatmapCellDetail | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | MAP-017 | heatmap_cells, places |

### 방문

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-VST-001 | 내 방문 기록 | GET | /api/v1/me/visits | Bearer | Should | 방문한 장소를 최신순으로 조회한다. | - | CursorPage<Visit> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | VST-003 | visits, places |
| API-VST-002 | 방문 통계 | GET | /api/v1/me/visit-stats | Bearer | Should | 17개 시도 진행률과 지역별 방문 분포를 조회한다. | - | VisitStats | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | VST-004, VST-008~009 | visits, places, regions |
| API-VST-003 | 방문 지도 | GET | /api/v1/me/visit-map | Bearer | Must | 지도 마커·방문 지역 채색·하단 뱃지 요약을 한 번에 반환한다. | - | VisitMap | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | VST-007~010 | visits, places, user_badges, badges |
| API-VST-004 | 장소 방문자 | GET | /api/v1/places/{placeId}/visitors | Bearer(optional) | Could | 장소 방문 사용자를 공개 프로필 기준으로 조회한다. | - | CursorPage<UserSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | VST-005 | visits, users |

### 이벤트

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-EVT-001 | 이벤트 목록 | GET | /api/v1/events | Public | Must | 이벤트를 진행 중 → 임박(7일 내 시작) → 예정 → 종료 순으로 정렬해 조회한다. 같은 그룹 안에서는 시작일 오름차순. | - | CursorPage<EventSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | 10m | EVT-002, EVT-005~010 | events, regions / ※ status를 명시하면 includeEnded보다 우선. 미지정 시 ONGOING+UPCOMING |
| API-EVT-002 | 주변 이벤트 | GET | /api/v1/events/nearby | Public | Should | 현재 위치 주변에서 진행·예정 이벤트를 조회한다. | - | EventSummary[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | EVT-015 | events, places |
| API-EVT-003 | 이벤트 상세 | GET | /api/v1/events/{eventId} | Bearer(optional) | Must | 이미지·정보·기간·장소·뱃지·적용 인증 반경을 조회한다. | - | EventDetail | 200 | EVENT_NOT_FOUND, COMMON_500 | - | 10m | EVT-011~013 | events, places, badges |
| API-EVT-004 | 이벤트 참여 게시글 | GET | /api/v1/events/{eventId}/posts | Bearer(optional) | Must | 이벤트에 연결된 공개 게시글을 조회한다. | - | CursorPage<PostSummary> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | EVT-014 | posts, post_images |
| API-EVT-005 | 이벤트 업로드 컨텍스트 | GET | /api/v1/events/{eventId}/upload-context | Bearer | Must | 업로드 장소·고정 태그·뱃지·적용 반경을 프리필한다. | - | EventUploadContext | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | EVT-012, EVT-016~020 | events, places, tags, badges |
| API-EVT-006 | 시도별 이벤트 요약 | GET | /api/v1/events/region-summary | Public | Should | 시도별 진행·예정 이벤트 수와 최근 N일 내 추가된 신규 이벤트 수를 조회한다. | - | EventRegionSummary[] | 200 | COMMON_400, COMMON_500 | - | 10m | EVT-007~009 | events, regions / ※ newCount>0이면 앱이 시도 칩을 강조. 읽음 해제는 앱 로컬(EVT-009) |

### 뱃지

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-BDG-001 | 사용자 뱃지 수집함 | GET | /api/v1/users/{userId}/badges | Bearer(optional) | Must | 획득·미획득 뱃지와 획득 가능한 전체 분모의 진행률을 조회한다. | - | BadgeCollection | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | BDG-001~004, BDG-009~012 | badges, user_badges |
| API-BDG-002 | 뱃지 상세 | GET | /api/v1/badges/{badgeId} | Public | Could | 뱃지 조건·획득자 수·관련 이벤트·장소를 조회한다. | - | BadgeDetail | 200 | BADGE_NOT_FOUND, COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | BDG-013 | badges, user_badges, events, places |

### 알림

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-NTF-001 | 알림 목록 | GET | /api/v1/notifications | Bearer | Could | 문구 키와 파라미터로 구성된 알림을 최신순 조회한다. | - | CursorPage<Notification> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | NTF-009, NTF-011 | notifications |
| API-NTF-002 | 안읽은 알림 수 | GET | /api/v1/notifications/unread-count | Bearer | Could | 탭 배지용 안읽은 알림 수를 조회한다. | - | UnreadCount | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 30s | NTF-012 | notifications |
| API-NTF-003 | 개별 알림 읽음 | PATCH | /api/v1/notifications/{notificationId}/read | Bearer | Could | 알림 한 건을 읽음 처리한다. | - | Notification | 200 | NOTIFICATION_NOT_FOUND, COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 | NTF-013 | notifications |
| API-NTF-004 | 전체 알림 읽음 | POST | /api/v1/notifications/read-all | Bearer | Could | 현재 사용자의 모든 알림을 읽음 처리한다. | - | Empty | 204 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 멱등 | NTF-013 | notifications |

### 랭킹·추천

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-RNK-001 | 장소 랭킹 | GET | /api/v1/rankings/places | Public | Must | 전국·지역·기간·테마·장소 유형별 사전 집계 랭킹을 조회한다. | - | CursorPage<RankingEntry> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | 10m | RNK-001~010 | place_rankings, places |
| API-RNK-002 | 장소 추천 | GET | /api/v1/recommendations/places | Bearer(optional) | Should | 현재 볼 만한 장소와 추천 사유 코드를 반환한다. | - | Recommendation[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 5m | RNK-011~013 | place_rankings, places |

### 검색

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-SCH-001 | 통합 검색 | GET | /api/v1/search | Bearer(optional) | Must | 장소·게시글·사용자·태그를 통합 검색하고 타입별 상위를 반환한다. | - | SearchResult | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | 단일 types 지정 시 불투명 keyset cursor | - | SCH-001, SCH-003~009 | places, posts, users, tags, search_logs(커서 없는 첫 페이지 검색만 기록) |
| API-SCH-002 | 인기 검색어 | GET | /api/v1/search/popular | Public | Could | 최근 7일 검색 로그 집계 기반 인기 검색어를 반환한다. | - | PopularKeyword[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | 10m | SCH-002, SCH-010 | search_logs(30일 보존), Redis(10분 캐시) |
| API-SCH-003 | 최근 검색어 | GET | /api/v1/me/recent-searches | Bearer | Could | 사용자의 최근 검색어를 조회한다. | - | RecentSearch[] | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | SCH-002, SCH-011 | Redis(사용자별 최대 20개, TTL 30일, 동일 검색어 최신화) |
| API-SCH-004 | 최근 검색어 삭제 | DELETE | /api/v1/me/recent-searches | Bearer | Could | 최근 검색어 한 건 또는 전체를 삭제한다. | - | Empty | 204 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | SCH-011 | Redis(검색어 1건 또는 전체 삭제) |

### 관리자·운영

| API ID | API 이름 | Method | Path | 인증 | 중요도 | 설명 | 요청 스키마 | 응답 스키마 | 성공 | 주요 에러 | 페이징 | 캐시·멱등 | 관련 요구사항 | 관련 테이블·비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| API-ADM-001 | 배치 수동 실행 | POST | /api/v1/admin/batches/{jobType} | ADMIN | Should | 장소·이벤트·랭킹·히트맵·카운터 배치를 비동기 실행한다. | - | BatchRun | 202 | ADMIN_REQUIRED, BATCH_ALREADY_RUNNING, COMMON_500 | - | - | PLC-010, SYS-015 | sync_logs<br>※ jobType=PLACE_SYNC\|EVENT_SYNC\|RANKING_RECALC\|HEATMAP_RECALC\|COUNTER_RECONCILE |
| API-ADM-002 | 배치 실행 상태 | GET | /api/v1/admin/batches/{runId} | ADMIN | Should | 비동기 배치의 상태·건수·오류를 조회한다. | - | BatchRun | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | PLC-009, SYS-015~016 | sync_logs |
| API-ADM-003 | 동기화 로그 | GET | /api/v1/admin/sync-logs | ADMIN | Should | 장소·이벤트 동기화 조합별 로그를 조회한다. | - | CursorPage<SyncLog> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | PLC-009 | sync_logs |
| API-ADM-004 | 이벤트 직접 등록 | POST | /api/v1/admin/events | ADMIN | Could | 운영자가 이벤트를 직접 등록한다. | AdminEventRequest | EventDetail | 201 | ADMIN_REQUIRED, EVENT_DATE_INVALID, PLACE_NOT_FOUND | - | - | EVT-004 | events, badges |
| API-ADM-005 | 이벤트 수정 | PATCH | /api/v1/admin/events/{eventId} | ADMIN | Could | 운영자가 이벤트 정보·기간·반경을 부분 수정한다. | AdminEventRequest | EventDetail | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | EVT-004, PLC-022 | events |
| API-ADM-006 | 장소 인증 반경 수정 | PATCH | /api/v1/admin/places/{placeId}/verify-radius | ADMIN | Must | 장소별 인증 반경 예외값을 설정한다. | - | PlaceDetail | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | PLC-022, PST-027 | places |
| API-ADM-007 | 이벤트 인증 반경 수정 | PATCH | /api/v1/admin/events/{eventId}/verify-radius | ADMIN | Must | 이벤트별 인증 반경 예외값을 설정한다. | - | EventDetail | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | PLC-022, PST-027, EVT-023 | events |
| API-ADM-008 | 지역 이벤트 반경 수정 | PATCH | /api/v1/admin/regions/{areaCode}/event-radius | ADMIN | Must | 지역별 기본 이벤트 인증 반경을 설정한다. | - | Region | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | PLC-022, PST-027 | regions |
| API-ADM-009 | 신고 목록 | GET | /api/v1/admin/reports | ADMIN | Should | 대상·상태별 신고를 조회한다. | - | CursorPage<Report> | 200 | COMMON_400, AUTH_REQUIRED, COMMON_500 | cursor | - | SYS-017, PST-043~045 | reports |
| API-ADM-010 | 신고 처리 | PATCH | /api/v1/admin/reports/{reportId} | ADMIN | Should | 신고 대상을 복구·숨김·삭제하고 처리 결과를 기록한다. | ResolveReportRequest | Report | 200 | REPORT_NOT_FOUND, ADMIN_REQUIRED, COMMON_409 | - | - | SYS-017, PLC-023, PST-045 | reports, posts, places |
| API-ADM-011 | 회원 강제 삭제 | DELETE | /api/v1/admin/users/{userId} | ADMIN | Could | 유예 없이 계정과 콘텐츠를 즉시 삭제한다. | - | Empty | 204 | ADMIN_REQUIRED, USER_NOT_FOUND, COMMON_409 | - | - | USER-022 | users 및 연관 테이블<br>※ 복구 불가·감사 로그 필수 |
| API-ADM-012 | 시스템 공지 알림 | POST | /api/v1/admin/notifications | ADMIN | Could | 문구 키·파라미터 기반 시스템 공지를 비동기 발송한다. | - | BatchRun | 202 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | NTF-004~010 | notifications, user_devices |
| API-ADM-013 | 장소 신고 조치 | POST | /api/v1/admin/places/{placeId}/moderation | ADMIN | Could | 장소를 숨기고 게시글을 가장 가까운 공식 장소로 재배치한다. | - | BatchRun | 202 | COMMON_400, AUTH_REQUIRED, COMMON_500 | - | - | PLC-023 | places, posts, reports |


## 2. 공통 규약

| 구분 | 항목 | 규칙·형식 | 설명 | 관련 요구사항 |
|---|---|---|---|---|
| 기본 경로 | Base URL | /api/v1 | 모든 앱 API의 버전 접두어 | SYS-013 |
| 인증 | Authorization | Bearer {accessToken} | 액세스 토큰 유효시간 2시간 | AUTH-001, AUTH-011 |
| 선택 인증 | Bearer(optional) | 토큰이 있으면 isLiked·isFollowing 등 개인화 필드 추가 | 토큰 오류는 401, 미전송은 공개 응답 | AUTH-010 |
| 응답 | 성공 봉투 | {success:true,data,traceId,timestamp} | HTTP 상태와 success를 함께 사용 | SYS-001 |
| 응답 | 실패 봉투 | {success:false,error:{code,messageKey,messageParams,violations},traceId,timestamp} | 앱은 code로 분기하고 문구는 i18n 조립 | SYS-001, SYS-002, NTF-009 |
| 페이징 | 커서 | cursor+size / items+nextCursor+hasNext | 기본 20, 최대 50; 커서는 불투명 | SYS-003, SYS-004, CMU-010 |
| 시간 | 타임존 | Asia/Seoul | ISO-8601 오프셋 포함; 날짜는 yyyy-mm-dd | SYS-005 |
| 시간 | 기간 어휘 | 히트맵·지역집계 LAST_1H\|LAST_24H\|WEEKLY\|MONTHLY / 인기 게시글 HOURS_24\|WEEKLY\|MONTHLY\|ALL / 장소 랭킹 DAILY\|WEEKLY\|MONTHLY\|ALL | 데이터 설계 DBML의 heatmap_period · post_popularity_period · ranking_period 세 enum을 그대로 쓴다. 전부 롤링 윈도우 | MAP-011, PST-035, RNK-004 |
| 언어 | Accept-Language | ko-KR\|en-US\|zh-CN\|ja-JP | 지원하지 않으면 ko-KR 폴백 | SYS-010, SYS-012 |
| 언어 | 관광정보 다국어 | place_details는 (place_id, language_code) 단위 저장 | 요청 언어의 상세가 없으면 해당 언어로 지연 적재 후 반환, 실패 시 ko-KR 폴백 | SYS-012, PLC-006 |
| 원문 | 사용자 작성 글 | content+originalLanguageCode+translations(null 허용) | 원문이 진실의 원천; 번역은 후속 확장 | SYS-010 |
| 식별자 | ID | 내부 PK는 bigint(auto increment), API는 불투명 string으로 노출. users 만 uuid (v1.1.4 정정) | 클라이언트는 형식을 가정하지 않는다. regions는 area_code, sigungu는 (area_code, sigungu_code)가 식별자 users 는 구글 OAuth 기반이라 순번을 노출하지 않고 uuid 를 쓴다. | SYS-009, PLC-001~002 |
| 좌표 | 공간 기준 | WGS84 lat/lng | mapx=경도, mapy=위도; 서버가 지역 역산 | PLC-005, PST-018 |
| 멱등 | PUT/DELETE | 동일 요청 반복 시 같은 200 결과 | 팔로우·좋아요·저장 | SOC-002, SOC-007 |
| 멱등 | POST 생성 | Idempotency-Key 헤더 | 게시글·장소 생성에서 네트워크 재시도 안전성 확보 | SYS-001 |
| 업로드 | 직접 S3 업로드 | Presigned URL 5분 · 게시글 원본은 비공개 `originals/` 경로 | 서버는 원본 바이트를 중계하거나 공개 URL로 반환하지 않음 | PST-013~015, SYS-020, SYS-021 |
| 보안 | 신뢰 금지 필드 | tier·areaCode·sigunguCode·fixedTags·장소명 태그는 서버 재계산·주입 | 클라이언트 값을 직접 저장하지 않는다. 장소명 태그는 placeId로부터 서버가 주입해 태그 최소 1개를 보장 | PST-018, PST-022, PLC-021, EVT-019 |
| 삭제 | 논리 삭제 | 상태 변경 후 배치 물리 삭제 | 공개 조회는 404로 동일 처리 | SYS-006 |
| 추적 | X-Trace-Id | 요청 헤더 수용 또는 서버 생성 | 응답 traceId와 로그에 동일 값 | SYS-016 |
| 호출 제한 | 429 | retryAfterSec 반환 | 팔로우 200/일·게시글 30/일·장소 5/일 | SOC-006, PLC-018, PST-029 |
| 캐시 | 공개 조회 | 시도·시군구 24시간, 언어별 장소 상세 10분 | 개인화·실시간 필드는 제외하고 Redis 장애 시 DB 폴백 | MAP-013, SYS-019 |
| CORS | 허용 출처 | 환경별 allowlist | 와일드카드 금지 | SYS-014 |

## 3. 요청 파라미터 (235개)

### API-AUTH-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/auth/google | body | idToken | string | Y | Google OIDC ID Token | eyJhbGci... | 서명·exp·iss·aud 검증 대상 |
| POST | /api/v1/auth/google | body | deviceId | string | Y | 기기별 안정 식별자 | device-8f2a | 세션·FCM 토큰 연결 |
| POST | /api/v1/auth/google | body | platform | enum | Y | IOS\|ANDROID | ANDROID | 기기 플랫폼 |
| POST | /api/v1/auth/google | body | fcmToken | string | N | 빈 값 허용 | fcm-... | 푸시 토큰 |

### API-AUTH-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/auth/onboarding | body | nickname | string | Y | 2~20자, 금칙어 제외 | 여행하는콩 | 표시 닉네임 |
| POST | /api/v1/auth/onboarding | body | termsVersion | string | Y | 현재 약관 버전과 일치 | 예: 2026-08-01 | 동의 약관 버전 |
| POST | /api/v1/auth/onboarding | body | locale | enum | Y | ko-KR\|en-US\|zh-CN\|ja-JP | ko-KR | 표시 언어 |

### API-AUTH-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/auth/refresh | body | refreshToken | string | Y | 원문은 전송 후 서버에서 해시 비교 | rt_... | 1회용 리프레시 토큰 |
| POST | /api/v1/auth/refresh | body | deviceId | string | Y | 발급 기기와 일치 | device-8f2a | 토큰 소유 기기 |

### API-AUTH-006

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/auth/restore | body | restoreKey | string | Y | 로그인 응답에서 받은 1회용 키 | restore_... | 복구 확인 키 |
| POST | /api/v1/auth/restore | body | nickname | string | Y | 2~20자 | 다시여행 | 파기된 닉네임 대체 |
| POST | /api/v1/auth/restore | body | confirmDataLoss | boolean | Y | true 필수 | true | 이메일·프로필 이미지 미복구 확인 |

### API-USER-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/me | body | nickname | string | N | 2~20자, 금칙어 제외 | 여행하는콩 | 닉네임 |
| PATCH | /api/v1/me | body | bio | string | N | 최대 200자 | 주말마다 떠나요 | 소개 |
| PATCH | /api/v1/me | body | profileImageKey | string\|null | N | 발급된 업로드 키 | profile/u1/a.webp | 프로필 이미지 |
| PATCH | /api/v1/me | body | locale | enum | N | ko-KR\|en-US\|zh-CN\|ja-JP | en-US | 표시 언어 |

### API-USER-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PUT | /api/v1/me/device | body | deviceId | string | Y | 사용자 기기 내 유일 | device-8f2a | 기기 ID |
| PUT | /api/v1/me/device | body | fcmToken | string | N | 빈 값이면 푸시 해제 | fcm-... | FCM 토큰 |
| PUT | /api/v1/me/device | body | platform | enum | Y | IOS\|ANDROID | ANDROID | 플랫폼 |
| PUT | /api/v1/me/device | body | appVersion | string | Y | semver 권장 | 1.0.0 | 앱 버전 |

### API-USER-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/users/{userId} | path | userId | uuid\|string | Y | URL encode | userId_01 | userId 경로 식별자 |

### API-USER-005

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/users/{userId}/posts | path | userId | uuid\|string | Y | URL encode | userId_01 | userId 경로 식별자 |
| GET | /api/v1/users/{userId}/posts | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/users/{userId}/posts | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-USER-006

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/me/liked-posts | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/me/liked-posts | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-USER-007

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/me/bookmarks | query | type | enum | Y | POST\|PLACE | POST | 저장 대상 종류 |
| GET | /api/v1/me/bookmarks | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/me/bookmarks | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-USER-009

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/me/deletion | body | contentAction | enum | Y | KEEP_ANONYMIZED\|DELETE_ALL | KEEP_ANONYMIZED | 게시글 처리 방식 |
| POST | /api/v1/me/deletion | body | reason | string | N | 최대 500자 | 서비스를 더 쓰지 않음 | 탈퇴 사유 |

### API-USER-010

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/me/notification-preferences | body | postLike | boolean | N | - | true | 좋아요 알림 |
| PATCH | /api/v1/me/notification-preferences | body | follow | boolean | N | - | true | 팔로우 알림 |
| PATCH | /api/v1/me/notification-preferences | body | badgeEarned | boolean | N | - | true | 뱃지 알림 |

### API-USER-011

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/me/recent-places | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/me/recent-places | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-SOC-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PUT | /api/v1/users/{userId}/follow | path | userId | uuid\|string | Y | URL encode | userId_01 | userId 경로 식별자 |

### API-SOC-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| DELETE | /api/v1/users/{userId}/follow | path | userId | uuid\|string | Y | URL encode | userId_01 | userId 경로 식별자 |

### API-SOC-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/users/{userId}/followers | path | userId | uuid\|string | Y | URL encode | userId_01 | userId 경로 식별자 |
| GET | /api/v1/users/{userId}/followers | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/users/{userId}/followers | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-SOC-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/users/{userId}/following | path | userId | uuid\|string | Y | URL encode | userId_01 | userId 경로 식별자 |
| GET | /api/v1/users/{userId}/following | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/users/{userId}/following | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-SOC-005

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/users/recommendations | query | limit | integer | N | 기본 10, 최대 30 | 10 | 추천 수 |

### API-PLC-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/regions/{areaCode}/sigungu | path | areaCode | integer | Y | TourAPI 시도 코드 1~8, 31~39 | areaCode_01 | areaCode 경로 식별자 |

### API-PLC-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/places | query | areaCode | integer | N | TourAPI areaCode | 1 | 시도 코드 |
| GET | /api/v1/places | query | sigunguCode | integer | N | areaCode와 함께 사용 | 1 | 시군구 코드 |
| GET | /api/v1/places | query | contentTypeId | integer | N | 12\|14\|15\|28\|38\|39 | 12 | 콘텐츠 유형 |
| GET | /api/v1/places | query | keyword | string | N | 최대 100자 | 경복궁 | 장소명·주소 검색 |
| GET | /api/v1/places | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/places | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-PLC-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/places/nearby | query | lat | number | Y | WGS84 -90~90 | 37.5796 | 위도 |
| GET | /api/v1/places/nearby | query | lng | number | Y | WGS84 -180~180 | 126.977 | 경도 |
| GET | /api/v1/places/nearby | query | radiusM | integer | N | 기본 500, 최대 20000 | 500 | 검색 반경 |

### API-PLC-005

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/places/{placeId} | path | placeId | uuid\|string | Y | URL encode | placeId_01 | placeId 경로 식별자 |

### API-PLC-006

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/places/{placeId}/posts | path | placeId | uuid\|string | Y | URL encode | placeId_01 | placeId 경로 식별자 |
| GET | /api/v1/places/{placeId}/posts | query | sort | enum | N | RECENT\|POPULAR | RECENT | 정렬 |
| GET | /api/v1/places/{placeId}/posts | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/places/{placeId}/posts | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-PLC-007

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/places | body | title | string | Y | 1~100자 | 드라마 촬영지 전망대 | 장소명 |
| POST | /api/v1/places | body | lat | number | Y | 대한민국 영역 | 37.55 | 위도 |
| POST | /api/v1/places | body | lng | number | Y | 대한민국 영역 | 126.99 | 경도 |
| POST | /api/v1/places | body | addr1 | string | N | 최대 300자 | 서울특별시 ... | 사용자 입력 주소 |

### API-PLC-008

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PUT | /api/v1/places/{placeId}/bookmark | path | placeId | uuid\|string | Y | URL encode | placeId_01 | placeId 경로 식별자 |

### API-PLC-009

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| DELETE | /api/v1/places/{placeId}/bookmark | path | placeId | uuid\|string | Y | URL encode | placeId_01 | placeId 경로 식별자 |

### API-PST-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/media/presigned-urls | body | purpose | enum | Y | POST_IMAGE\|PROFILE_IMAGE | POST_IMAGE | 업로드 용도 |
| POST | /api/v1/media/presigned-urls | body | files | array | Y | POST_IMAGE 1~4개 / PROFILE_IMAGE 1개; mimeType image/jpeg\|png\|heic\|webp; sizeBytes ≤ 10MB | [{mimeType:'image/webp',sizeBytes:1200000}] | 파일 메타데이터 |

### API-PST-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| 앱 내부 | - | - | 대표 사진·선택 장소 | - | Y | 사진 위치가 200m 이내인지와 촬영 후 10분·30일 경과를 기기에서 계산 | - | 원 좌표·정확한 촬영 시각은 서버에 전송하지 않는다 |

### API-PST-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/posts | body | placeId | uuid | Y | - | plc_01 | 장소 ID |
| POST | /api/v1/posts | body | eventId | uuid\|null | N | 이벤트 참여 시 | evt_01 | 이벤트 ID |
| POST | /api/v1/posts | body | content | string | N | 최대 5000자 | 야경이 멋져요 | 캡션 원문 |
| POST | /api/v1/posts | body | originalLanguageCode | string | Y | BCP 47 | ko | 원문 언어 |
| POST | /api/v1/posts | body | images | array | Y | 1~4개, 발급 imageKey | [{imageKey:'originals/posts/...',sortOrder:1}] | 업로드 완료 이미지. 원소는 imageKey · sortOrder · aspectRatio · imageHash 네 필드다. |
| POST | /api/v1/posts | body | images[].imageKey | string | Y | presigned-urls 발급 키 | originals/posts/{userId}/{uuid}.webp | 서버가 접두어로 발급 소유자를 확인한다. 남의 키는 MEDIA_NOT_FOUND (PST-014) |
| POST | /api/v1/posts | body | images[].sortOrder | integer | Y | 1~4, 중복 불가 | 1 | 1부터다. 게시글당 1~4장이므로 값이 곧 몇 번째 사진인지를 뜻한다 (PST-001) |
| POST | /api/v1/posts | body | images[].aspectRatio | number\|null | N | 0 초과 | 1.3333 | 메이슨리가 이미지 도착 전에 카드 높이를 잡아야 하는데 후처리 전까지 값이 없어 클라이언트가 아는 값을 함께 받는다. 후처리(JOB-003)가 실제 값으로 덮어쓴다 (PST-021, v1.1.4 추가) |
| POST | /api/v1/posts | body | images[].imageHash | string\|null | N | SHA-256 소문자 16진수 64자 | a1b2... | 중복 409 를 등록 응답 전에 내리기 위한 값. 서버가 이 시점에 원본을 내려받아 계산하면 PST-019 와 어긋난다. 비우면 검사를 건너뛰고 후처리가 실제 해시로 덮어쓴다 (PST-031, v1.1.4 추가) |
| POST | /api/v1/posts | body | tagNames | array<string> | Y | 고정 포함 1~10개 | ['서울','드라마촬영지'] | 사용자·추천 태그 |
| POST | /api/v1/posts | body | source | enum | Y | CAMERA\|ALBUM | ALBUM | 업로드 경로 |
| POST | /api/v1/posts | body | localTier | enum | Y | HIGH\|MEDIUM\|LOW | MEDIUM | 기기 안에서 계산한 사진 인증 결과 |
| POST | /api/v1/posts | body | localWithinRadius | boolean | Y | 200m 이내 여부 | true | 기기 판정 결과. 거리값·좌표는 보내지 않는다 |

### API-PST-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/posts | query | areaCode | integer | N | - | 1 | 지역 |
| GET | /api/v1/posts | query | placeId | uuid | N | - | plc_01 | 장소 |
| GET | /api/v1/posts | query | tag | string | N | 정규화 태그 | kpop | 태그 |
| GET | /api/v1/posts | query | period | enum | N | HOURS_24\|WEEKLY\|MONTHLY\|ALL, 기본 WEEKLY | WEEKLY | 기간 |
| GET | /api/v1/posts | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/posts | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-PST-005

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/posts/popular | query | period | enum | Y | HOURS_24\|WEEKLY\|MONTHLY\|ALL | WEEKLY | 기간 |
| GET | /api/v1/posts/popular | query | areaCode | integer | N | - | 1 | 지역 |
| GET | /api/v1/posts/popular | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/posts/popular | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-PST-006

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/posts/{postId} | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |

### API-PST-007

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/posts/{postId} | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |
| PATCH | /api/v1/posts/{postId} | body | content | string | N | 최대 5000자 | 수정된 캡션 | 캡션 |
| PATCH | /api/v1/posts/{postId} | body | tagNames | array<string> | N | 1~10개; 전체 교체 | ['서울','야경'] | 태그 |
| PATCH | /api/v1/posts/{postId} | body | imageOrder | array<uuid> | N | 기존 이미지 ID 전체 순서 | ['img2','img1'] | 이미지 순서 |

### API-PST-008

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| DELETE | /api/v1/posts/{postId} | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |

### API-PST-009

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PUT | /api/v1/posts/{postId}/like | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |

### API-PST-010

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| DELETE | /api/v1/posts/{postId}/like | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |

### API-PST-011

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PUT | /api/v1/posts/{postId}/bookmark | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |

### API-PST-012

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| DELETE | /api/v1/posts/{postId}/bookmark | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |

### API-PST-013

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/posts/{postId}/reports | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |
| POST | /api/v1/posts/{postId}/reports | body | reason | enum | Y | INAPPROPRIATE\|COPYRIGHT\|PLACE_MISMATCH\|SPAM\|OTHER | PLACE_MISMATCH | 신고 사유 |
| POST | /api/v1/posts/{postId}/reports | body | detail | string | N | 최대 1000자 | 실제 위치와 다름 | 상세 설명 |

### API-PST-014

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/public/posts/{postId}/share-metadata | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |

### API-CMU-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/feeds/popular | query | period | enum | N | WEEKLY\|MONTHLY, 기본 WEEKLY | WEEKLY | 기간 |
| GET | /api/v1/feeds/popular | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/feeds/popular | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-CMU-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/feeds/following | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/feeds/following | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-CMU-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/feeds/recent | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/feeds/recent | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-CMU-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/posts/{postId}/comments | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |
| GET | /api/v1/posts/{postId}/comments | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/posts/{postId}/comments | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-CMU-005

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/posts/{postId}/comments | path | postId | uuid\|string | Y | URL encode | postId_01 | postId 경로 식별자 |
| POST | /api/v1/posts/{postId}/comments | body | content | string | Y | 1~1000자 | 좋은 정보예요! | 댓글 내용 |

### API-CMU-006

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/comments/{commentId}/replies | path | commentId | uuid\|string | Y | URL encode | commentId_01 | commentId 경로 식별자 |
| POST | /api/v1/comments/{commentId}/replies | body | content | string | Y | 1~1000자 | 저도 다녀왔어요 | 대댓글 내용 |

### API-CMU-007

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/comments/{commentId} | path | commentId | uuid\|string | Y | URL encode | commentId_01 | commentId 경로 식별자 |
| PATCH | /api/v1/comments/{commentId} | body | content | string | Y | 1~1000자 | 수정한 댓글 | 댓글 내용 |

### API-CMU-008

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| DELETE | /api/v1/comments/{commentId} | path | commentId | uuid\|string | Y | URL encode | commentId_01 | commentId 경로 식별자 |

### API-CMU-009

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PUT | /api/v1/comments/{commentId}/like | path | commentId | uuid\|string | Y | URL encode | commentId_01 | commentId 경로 식별자 |

### API-CMU-010

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| DELETE | /api/v1/comments/{commentId}/like | path | commentId | uuid\|string | Y | URL encode | commentId_01 | commentId 경로 식별자 |

### API-CMU-011

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/tags/suggestions | query | placeId | uuid | Y | - | plc_01 | 장소 |
| GET | /api/v1/tags/suggestions | query | eventId | uuid | N | - | evt_01 | 이벤트 |
| GET | /api/v1/tags/suggestions | query | query | string | N | 최대 50자 | 드라마 | 사용자 입력 접두어 |

### API-CMU-012

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/tags/popular | query | areaCode | integer | N | - | 1 | 지역 |
| GET | /api/v1/tags/popular | query | limit | integer | N | 기본 20, 최대 50 | 20 | 개수 |

### API-CMU-013

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/tags/{tagId}/posts | path | tagId | uuid\|string | Y | URL encode | tagId_01 | tagId 경로 식별자 |
| GET | /api/v1/tags/{tagId}/posts | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/tags/{tagId}/posts | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-MAP-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/map/regions | query | period | enum | N | LAST_1H\|LAST_24H\|WEEKLY\|MONTHLY, 기본 WEEKLY | WEEKLY | 집계 기간. region_stats는 heatmap_period를 공유한다 |

### API-MAP-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/map/heatmap | query | west | number | Y | 경도 | 126.7 | 서쪽 경계 |
| GET | /api/v1/map/heatmap | query | south | number | Y | 위도 | 37.3 | 남쪽 경계 |
| GET | /api/v1/map/heatmap | query | east | number | Y | 경도 | 127.2 | 동쪽 경계 |
| GET | /api/v1/map/heatmap | query | north | number | Y | 위도 | 37.8 | 북쪽 경계 |
| GET | /api/v1/map/heatmap | query | zoom | number | Y | 지도 줌 | 11 | 줌 단계 |
| GET | /api/v1/map/heatmap | query | period | enum | N | LAST_1H\|LAST_24H\|WEEKLY\|MONTHLY, 기본 WEEKLY | WEEKLY | 기간(MAP-011). 자정 기준이 아니라 조회 시점 기준 롤링 윈도우 |
| GET | /api/v1/map/heatmap | query | forceRefresh | boolean | N | 게시 직후 true | false | 응답 캐시만 우회해 PostgreSQL 집계 스냅샷을 즉시 조회 |

### API-MAP-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/map/photo-markers | query | west | number | Y | - | 126.7 | 서쪽 경계 |
| GET | /api/v1/map/photo-markers | query | south | number | Y | - | 37.3 | 남쪽 경계 |
| GET | /api/v1/map/photo-markers | query | east | number | Y | - | 127.2 | 동쪽 경계 |
| GET | /api/v1/map/photo-markers | query | north | number | Y | - | 37.8 | 북쪽 경계 |
| GET | /api/v1/map/photo-markers | query | zoom | number | Y | - | 9 | 줌 단계 |
| GET | /api/v1/map/photo-markers | query | period | enum | N | LAST_1H\|LAST_24H\|WEEKLY\|MONTHLY, 기본 WEEKLY | WEEKLY | 기간. heatmap_cells 집계를 그대로 읽는다 |

### API-MAP-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/map/cells/{cellKey} | path | cellKey | string | Y | hmc_ 접두어의 Base64URL 키 | hmc_V0VFS0xZfDJ8Mzc1MHwxMjY5MA | 기간·격자 단계·좌표 인덱스를 포함한 셀 식별자 |

### API-VST-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/me/visits | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/me/visits | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-VST-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/places/{placeId}/visitors | path | placeId | uuid\|string | Y | URL encode | placeId_01 | placeId 경로 식별자 |
| GET | /api/v1/places/{placeId}/visitors | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/places/{placeId}/visitors | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-EVT-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/events | query | areaCode | integer | N | - | 1 | 지역 |
| GET | /api/v1/events | query | status | enum | N | ONGOING\|UPCOMING\|ENDED, 기본 ONGOING+UPCOMING | ONGOING | 진행 상태 |
| GET | /api/v1/events | query | includeEnded | boolean | N | 기본 false; status를 명시하면 status가 우선 | false | 종료 행사 포함 |
| GET | /api/v1/events | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/events | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-EVT-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/events/nearby | query | lat | number | Y | WGS84 | 37.57 | 위도 |
| GET | /api/v1/events/nearby | query | lng | number | Y | WGS84 | 126.98 | 경도 |
| GET | /api/v1/events/nearby | query | radiusM | integer | N | 기본 20000, 최대 50000 (장소 탐색 MAP-027의 20km와 별도 기준) | 20000 | 반경 |

### API-EVT-006

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/events/region-summary | query | newWithinDays | integer | N | 기본 7, 최대 30 | 7 | 신규 판정 기준 일수 |

### API-EVT-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/events/{eventId} | path | eventId | uuid\|string | Y | URL encode | eventId_01 | eventId 경로 식별자 |

### API-EVT-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/events/{eventId}/posts | path | eventId | uuid\|string | Y | URL encode | eventId_01 | eventId 경로 식별자 |
| GET | /api/v1/events/{eventId}/posts | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/events/{eventId}/posts | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-EVT-005

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/events/{eventId}/upload-context | path | eventId | uuid\|string | Y | URL encode | eventId_01 | eventId 경로 식별자 |

### API-BDG-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/users/{userId}/badges | path | userId | uuid\|string | Y | URL encode | userId_01 | userId 경로 식별자 |
| GET | /api/v1/users/{userId}/badges | query | category | enum | N | EVENT\|AREA\|COMPLETION\|RECORD\|ALL | ALL | 뱃지 분류 |

### API-BDG-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/badges/{badgeId} | path | badgeId | uuid\|string | Y | URL encode | badgeId_01 | badgeId 경로 식별자 |

### API-NTF-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/notifications | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/notifications | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-NTF-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/notifications/{notificationId}/read | path | notificationId | uuid\|string | Y | URL encode | notificationId_01 | notificationId 경로 식별자 |

### API-RNK-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/rankings/places | query | scope | enum | Y | NATIONAL\|REGION | REGION | 랭킹 범위 |
| GET | /api/v1/rankings/places | query | areaCode | integer | N | scope=REGION이면 필수 | 1 | 지역 |
| GET | /api/v1/rankings/places | query | period | enum | N | DAILY\|WEEKLY\|MONTHLY\|ALL, 기본 WEEKLY | WEEKLY | 기간 |
| GET | /api/v1/rankings/places | query | theme | string | N | 정규화 테마 코드 | KPOP | 테마 |
| GET | /api/v1/rankings/places | query | placeType | enum | N | ALL\|OFFICIAL\|USER | ALL | 장소 유형 |
| GET | /api/v1/rankings/places | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/rankings/places | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-RNK-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/recommendations/places | query | lat | number | N | 위치 동의 시 | 37.57 | 현재 위도 |
| GET | /api/v1/recommendations/places | query | lng | number | N | 위치 동의 시 | 126.98 | 현재 경도 |
| GET | /api/v1/recommendations/places | query | areaCode | integer | N | - | 1 | 선호 지역 |
| GET | /api/v1/recommendations/places | query | limit | integer | N | 기본 10, 최대 30 | 10 | 추천 수 |

### API-SCH-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/search | query | q | string | Y | 1~100자 | 경복궁 | 검색어 |
| GET | /api/v1/search | query | types | array<enum> | N | PLACE\|POST\|USER\|TAG, cursor 사용 시 정확히 1개 | PLACE,POST | 검색 대상 |
| GET | /api/v1/search | query | areaCode | integer | N | 지역명과 정확히 일치하면 해당 지역 코드가 우선 | 1 | 지역 필터 |
| GET | /api/v1/search | query | cursor | string | N | 단일 검색 타입용 불투명 keyset cursor | eyJ... | 페이지 커서 |
| GET | /api/v1/search | query | size | integer | N | 타입별 기본 5, 더보기 최대 50 | 5 | 결과 수 |

### API-SCH-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/search/popular | query | areaCode | integer | N | - | 1 | 지역 |
| GET | /api/v1/search/popular | query | limit | integer | N | 기본 10, 최대 50 | 10 | 개수 |

### API-SCH-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| DELETE | /api/v1/me/recent-searches | query | keyword | string | N | 누락 시 전체 삭제 | 경복궁 | 삭제할 검색어 |

### API-ADM-001

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/admin/batches/{jobType} | path | jobType | enum | Y | PLACE_SYNC\|EVENT_SYNC\|RANKING_RECALC\|HEATMAP_RECALC\|COUNTER_RECONCILE | PLACE_SYNC | jobType 경로 식별자 |
| POST | /api/v1/admin/batches/{jobType} | body | areaCode | integer | N | 장소·이벤트 배치 필터 | 1 | 지역 |
| POST | /api/v1/admin/batches/{jobType} | body | contentTypeId | integer | N | 장소 동기화 필터 | 12 | 콘텐츠 유형 |

### API-ADM-002

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/admin/batches/{runId} | path | runId | uuid\|string | Y | URL encode | runId_01 | runId 경로 식별자 |

### API-ADM-003

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/admin/sync-logs | query | jobType | string | N | - | PLACE_SYNC | 작업 유형 |
| GET | /api/v1/admin/sync-logs | query | result | enum | N | SUCCESS\|FAIL\|PARTIAL | FAIL | 결과 |
| GET | /api/v1/admin/sync-logs | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/admin/sync-logs | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-ADM-004

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/admin/events | body | title | string | Y | 1~200자 | 서울 야간 축제 | 이벤트명 |
| POST | /api/v1/admin/events | body | placeId | uuid | Y | - | plc_01 | 장소 |
| POST | /api/v1/admin/events | body | startDate | date | Y | yyyy-mm-dd | 예: 2026-09-10 | 시작일 |
| POST | /api/v1/admin/events | body | endDate | date | Y | startDate 이상 | 예: 2026-09-15 | 종료일 |
| POST | /api/v1/admin/events | body | verifyRadiusM | integer\|null | N | 누락 시 지역 기본/2000 | 2500 | 인증 반경 |
| POST | /api/v1/admin/events | body | fixedTags | array<string> | Y | 지역+행사 2개 | ['서울','서울야간축제'] | 고정 태그 |

### API-ADM-005

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/admin/events/{eventId} | path | eventId | uuid\|string | Y | URL encode | eventId_01 | eventId 경로 식별자 |

### API-ADM-006

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/admin/places/{placeId}/verify-radius | path | placeId | uuid\|string | Y | URL encode | placeId_01 | placeId 경로 식별자 |
| PATCH | /api/v1/admin/places/{placeId}/verify-radius | body | verifyRadiusM | integer | Y | 1~20000 | 500 | 인증 반경 |

### API-ADM-007

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/admin/events/{eventId}/verify-radius | path | eventId | uuid\|string | Y | URL encode | eventId_01 | eventId 경로 식별자 |
| PATCH | /api/v1/admin/events/{eventId}/verify-radius | body | verifyRadiusM | integer\|null | Y | null이면 지역 기본값 사용 | 2000 | 인증 반경 |

### API-ADM-008

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/admin/regions/{areaCode}/event-radius | path | areaCode | integer | Y | TourAPI 시도 코드 1~8, 31~39 | 1 | areaCode 경로 식별자 |
| PATCH | /api/v1/admin/regions/{areaCode}/event-radius | body | defaultEventVerifyRadiusM | integer | Y | 1~20000 | 2000 | 지역 기본 반경 |

### API-ADM-009

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/admin/reports | query | status | enum | N | PENDING\|RESOLVED\|REJECTED | PENDING | 처리 상태 |
| GET | /api/v1/admin/reports | query | targetType | enum | N | POST\|PLACE | POST | 대상 종류 |
| GET | /api/v1/admin/reports | query | cursor | string | N | 서버가 발급한 불투명 커서 | eyJ... | 다음 페이지 커서 |
| GET | /api/v1/admin/reports | query | size | integer | N | 기본 20, 최대 50 | 20 | 페이지 크기 |

### API-ADM-010

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| PATCH | /api/v1/admin/reports/{reportId} | path | reportId | uuid\|string | Y | URL encode | reportId_01 | reportId 경로 식별자 |
| PATCH | /api/v1/admin/reports/{reportId} | body | action | enum | Y | RESTORE\|HIDE\|DELETE\|REJECT | HIDE | 처리 액션 |

### API-ADM-011

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| DELETE | /api/v1/admin/users/{userId} | path | userId | uuid\|string | Y | URL encode | userId_01 | userId 경로 식별자 |

### API-ADM-012

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/admin/notifications | body | recipientUserIds | array<uuid>\|ALL | Y | - | ALL | 수신 대상 |
| POST | /api/v1/admin/notifications | body | messageKey | string | Y | i18n 키 | notification.system.maintenance | 문구 키 |
| POST | /api/v1/admin/notifications | body | messageParams | object | N | JSON | {startAt:'02:00'} | 문구 변수 |

### API-ADM-013

| Method | Path | 위치 | 파라미터 | 타입 | 필수 | 제약·기본값 | 예시 | 설명 |
|---|---|---|---|---|---|---|---|---|
| POST | /api/v1/admin/places/{placeId}/moderation | path | placeId | uuid\|string | Y | URL encode | placeId_01 | placeId 경로 식별자 |
| POST | /api/v1/admin/places/{placeId}/moderation | body | action | enum | Y | HIDE_AND_REASSIGN\|RESTORE | HIDE_AND_REASSIGN | 조치 |
| POST | /api/v1/admin/places/{placeId}/moderation | body | targetPlaceId | uuid | N | 재배치 공식 장소 | plc_official_01 | 대체 장소 |


## 4. 응답 스키마 (328개 필드)

### ApiEnvelope<T>

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| success | boolean | Y | 요청 성공 여부 | true | - |
| data | T\|null | Y | 성공 데이터 | {...} | - |
| error | ErrorBody\|null | Y | 실패 정보 |  | - |
| traceId | string | Y | 요청 추적 ID | tr_01H... | 로그 |
| timestamp | datetime | Y | KST ISO-8601 | 예: 2026-09-01T10:00:00+09:00 | - |

### CursorPage<T>

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| items | array<T> | Y | 현재 페이지 항목 | [...] | - |
| nextCursor | string\|null | Y | 다음 페이지 커서 | eyJ... | - |
| hasNext | boolean | Y | 다음 페이지 존재 | true | - |

### TokenBundle

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| accessToken | string | Y | 2시간 액세스 토큰 | at_... | - |
| accessTokenExpiresIn | integer | Y | 초 단위 | 7200 | - |
| refreshToken | string | Y | 30일 1회용 리프레시 토큰 | rt_... | refresh_tokens |
| refreshTokenExpiresIn | integer | Y | 초 단위 | 2592000 | - |

### AuthResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| tokens | TokenBundle\|null | Y | 복구 제안 시 null | {...} | refresh_tokens |
| user | MyProfile\|null | Y | 회원 프로필 | {...} | users |
| onboardingRequired | boolean | Y | 최초 가입 온보딩 필요 | true | users |
| recoveryOffered | boolean | Y | 탈퇴 유예 복구 가능 | false | users |
| restoreKey | string\|null | Y | 복구 확인용 1회 키 | restore_... | users |

### UserSummary

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| userId | uuid | Y | 사용자 ID | usr_01 | users |
| nickname | string | Y | 닉네임 | 여행하는콩 | users |
| profileImageUrl | url\|null | Y | 프로필 이미지 | https://cdn/... | users |
| bio | string\|null | N | 소개 | 주말 여행자 | users |
| isFollowing | boolean\|null | N | 로그인 요청자 기준 | true | follows |
| isFollowedBy | boolean\|null | N | 상대가 나를 팔로우 중인지 (맞팔 표시용, USER-005·SOC-012) | true | follows |

### UserProfile

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| user | UserSummary | Y | 공개 사용자 정보 | {...} | users |
| stats.postCount | integer | Y | 게시글 수 | 12 | users |
| stats.followerCount | integer | Y | 팔로워 수 | 31 | users |
| stats.followingCount | integer | Y | 팔로잉 수 | 20 | users |
| stats.badgeCount | integer | Y | 획득 뱃지 수 | 7 | users |

### MyProfile

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| profile | UserProfile | Y | 공개 프로필+통계 | {...} | users |
| email | string\|null | Y | 본인만 노출 | user@example.com | users |
| locale | string | Y | 표시 언어 | ko-KR | users |
| status | enum | Y | ACTIVE\|SUSPENDED\|WITHDRAWN | ACTIVE | users |
| role | enum | Y | USER\|ADMIN | USER | users |
| notificationPreferences | NotificationPreferences | Y | 알림 설정 | {...} | users |

### Region

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| areaCode | integer | Y | TourAPI 시도 코드(PK). 1~8, 31~39로 비연속 | 1 | regions |
| nameKo | string | Y | 한국어명 | 서울 | regions |
| nameEn | string | Y | 영문명 | Seoul | regions |
| representativeImageUrl | url\|null | Y | 지역 선택 이미지 | https://cdn/... | regions |
| defaultEventVerifyRadiusM | integer | Y | 기본 2000 | 2000 | regions |

### Sigungu

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| areaCode | integer | Y | 소속 시도 코드 | 1 | sigungu |
| sigunguCode | integer | Y | TourAPI 시군구 코드. (areaCode, sigunguCode)가 식별자 | 1 | sigungu |
| nameKo | string | Y | 한국어명 | 종로구 | sigungu |
| nameEn | string | Y | 영문명 | Jongno-gu | sigungu |

### PlaceSummary

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| placeId | uuid | Y | 장소 ID | plc_01 | places |
| placeType | enum | Y | OFFICIAL\|USER | OFFICIAL | places |
| title | string | Y | 장소명 | 경복궁 | places |
| addr1 | string\|null | Y | 주소 | 서울 종로구 ... | places |
| lat | number\|null | Y | 위도 | 37.5796 | places.geom |
| lng | number\|null | Y | 경도 | 126.977 | places.geom |
| postCount | integer | Y | 게시글 수 | 120 | places |
| visitCount | integer | Y | 방문자 수 | 88 | places |
| distanceM | integer\|null | N | 주변 검색 거리 | 320 | 계산 |
| isVerifiable | boolean\|null | N | 현재 위치가 반경 내 | true | 계산 |

### PlaceDetail

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| place | PlaceSummary | Y | 장소 기본 정보 | {...} | places |
| overview | string\|null | Y | 상세 설명 | 조선 왕조의 궁궐 | place_details |
| languageCode | string | Y | 상세 정보 언어 (SYS-012, place_details 복합 PK) | ko | place_details |
| tel | string\|null | Y | 전화 | 02-... | place_details |
| homepage | url\|null | Y | 홈페이지 | https://... | place_details |
| verifyRadiusM | integer | Y | 적용 인증 반경 | 500 | places |
| viewCount | integer | Y | 장소 조회 수 (PLC-014) | 1024 | places |
| ranking | RankingEntry\|null | Y | 대표 랭킹 | {...} | place_rankings |
| nearbyPlaces | PlaceSummary[] | Y | 주변 장소 | [...] | places |

### UploadUrl

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| imageKey | string | Y | 서버 발급 비공개 원본 객체 키 | originals/posts/u1/uuid.webp | S3 |
| uploadUrl | url | Y | S3 PUT URL | https://s3/... | S3 |
| headers | object | Y | 업로드 필수 헤더 | {Content-Type:'image/webp'} | - |
| expiresAt | datetime | Y | 5분 만료 | 예: 2026-09-01T10:05:00+09:00 | - |

### TierResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| tier | enum | Y | HIGH\|MEDIUM\|LOW | MEDIUM | posts |
| distanceM | number\|null | Y | 장소 중심 거리 | 120 | posts/places |
| verifyRadiusM | integer | Y | 적용 반경 | 500 | places/events/regions |
| reasonCode | string | Y | 판정 이유 코드 | WITHIN_RADIUS_30D | 계산값 |
| reasonParams | object | Y | 다국어 문구 변수 | {days:2} | 계산값 |
| improvementHints | string[] | Y | 낮음 개선 힌트 코드 | [] | - |

### PostSummary

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| postId | uuid | Y | 게시글 ID | pst_01 | posts |
| author | UserSummary | Y | 작성자 | {...} | users |
| place | PlaceSummary | Y | 장소 | {...} | places |
| thumbnailUrl | url | Y | 대표 썸네일 | https://cdn/... | post_images |
| imageCount | integer | Y | 첨부 사진 수 1~4 (SOC-013, 캐러셀 인디케이터) | 3 | post_images |
| aspectRatio | number | Y | 메이슨리 비율 | 1.333 | post_images |
| tier | enum | Y | HIGH\|MEDIUM\|LOW | MEDIUM | posts |
| likeCount | integer | Y | 좋아요 수 | 32 | posts |
| commentCount | integer | Y | 댓글 수 | 4 | posts |
| createdAt | datetime | Y | 작성 시각 | 예: 2026-09-01T09:00:00+09:00 | posts |
| isLiked | boolean\|null | N | 요청자 상태 | true | likes |
| isBookmarked | boolean\|null | N | 요청자 상태 | false | bookmarks |

### PostDetail

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| summary | PostSummary | Y | 목록 공통 필드 | {...} | posts |
| images | PostImage[] | Y | 1~4장 | [...] | post_images |
| content | string\|null | Y | 원문 캡션 | 야경이 멋져요 | posts |
| originalLanguageCode | string | Y | 원문 언어 | ko | posts |
| translations | object\|null | Y | 후속 번역 확장 필드 |  | 향후 |
| tags | TagSummary[] | Y | 해시태그 | [...] | tags/post_tags |
| event | EventSummary\|null | Y | 이벤트 참여 정보 | {...} | events |
| tierResult | TierResult | Y | 등급 근거 | {...} | posts/places |
| viewCount | integer | Y | 조회 수 | 100 | posts |

### Comment

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| commentId | uuid | Y | 댓글 ID | cmt_01 | comments |
| postId | uuid | Y | 게시글 ID | pst_01 | comments |
| author | UserSummary | Y | 작성자 | {...} | users |
| parentId | uuid\|null | Y | 최상위 댓글 ID |  | comments |
| content | string\|null | Y | 삭제 댓글은 null | 좋아요 | comments |
| status | enum | Y | ACTIVE\|DELETED | ACTIVE | comments |
| likeCount | integer | Y | 좋아요 수 | 2 | comments |
| isLiked | boolean\|null | N | 요청자 상태 | false | likes |

### CommentThread

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| parent | Comment | Y | 최상위 댓글 | {...} | comments |
| replies | Comment[] | Y | 대댓글 전체 | [...] | comments |

### TagSummary

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| tagId | uuid | Y | 태그 ID | tag_01 | tags |
| name | string | Y | 표시 태그 | 드라마촬영지 | tags |
| themeCode | string\|null | Y | 랭킹 테마 코드 | KDRAMA | tags |
| usageCount | integer | Y | 사용 횟수 | 321 | tags |

### MapRegion

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| region | Region | Y | 지역 | {...} | regions |
| postCount | integer | Y | 기간 게시글 수 | 1320 | region_stats |
| contributorCount | integer | Y | 기여 사용자 수 | 402 | region_stats |
| representativePost | PostSummary\|null | Y | 대표 이미지 클릭 대상 | {...} | posts |

### HeatmapResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| cells | HeatmapCell[] | Y | 히트맵 셀 | [...] | heatmap_cells |
| maxCount | integer | Y | 응답 범위 내 최대 게시글 수 (정규화 분모, MAP-010) | 420 | 계산 |
| requestedPeriod | enum | Y | 요청 기간 LAST_1H\|LAST_24H\|WEEKLY\|MONTHLY | LAST_1H | - |
| effectivePeriod | enum | Y | 실제 집계 기간 (폴백 시 LAST_24H) | LAST_24H | heatmap_cells |
| fallbackApplied | boolean | Y | LAST_1H → LAST_24H 폴백 여부 (MAP-014) | true | - |
| nextRefreshAt | datetime | Y | 다음 허용 조회 시각 | 예: 2026-09-01T10:01:00+09:00 | heatmap_cells |
| truncated | boolean | Y | 셀 수 제한 여부 | false | - |

### PhotoMarker

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| cellKey | string | Y | 기간·격자 단계·좌표 인덱스를 포함한 불투명 키 | hmc_V0VFS0xZfDJ8Mzc1MHwxMjY5MA | heatmap_cells |
| lat | number | Y | 마커 위도 | 37.55 | heatmap_cells |
| lng | number | Y | 마커 경도 | 126.99 | heatmap_cells |
| candidates | PostSummary[] | Y | 축소 최대 10장·확대 1장 | [...] | posts |
| rotationIntervalMs | integer | Y | 클라이언트 교체 간격 | 3000 | 고정 정책 |

### VisitStats

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| visitedRegionCount | integer | Y | 방문 시도 수 | 7 | visits |
| totalRegionCount | integer | Y | 고정 17 | 17 | regions |
| progress | number | Y | 0~1 | 0.412 | 계산 |
| regions | VisitRegionStat[] | Y | 지역별 방문 수 | [...] | visits |

### EventSummary

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| eventId | uuid | Y | 이벤트 ID | evt_01 | events |
| title | string | Y | 이벤트명 | 서울 야간 축제 | events |
| thumbnailUrl | url\|null | Y | 대표 이미지 | https://cdn/... | events |
| areaCode | integer | Y | 시도 | 1 | events |
| startDate | date | Y | 시작일 | 예: 2026-09-10 | events |
| endDate | date | Y | 종료일 | 예: 2026-09-15 | events |
| status | enum | Y | UPCOMING\|ONGOING\|ENDED | ONGOING | 계산 |
| dday | integer\|null | Y | 시작까지 남은 일수 (진행 중이면 0) | 3 | 계산 |
| isNew | boolean | Y | 최근 7일 내 추가된 이벤트 (EVT-008) | true | events |
| createdAt | datetime | Y | 적재 시각 (신규 판정 기준) | 예: 2026-08-28T04:30:00+09:00 | events |
| participantCount | integer | Y | 참여 게시글 수 | 32 | events |

### EventDetail

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| event | EventSummary | Y | 목록 필드 | {...} | events |
| overview | string\|null | Y | 설명 | 야간 문화 행사 | events |
| place | PlaceSummary | Y | 행사 장소 | {...} | places |
| fixedTags | TagSummary[] | Y | 수정 불가 2개 | [...] | events/tags |
| badge | BadgeSummary\|null | Y | 참여 뱃지 | {...} | badges |
| verifyRadiusM | integer | Y | 이벤트→지역→2000 | 2000 | events/regions |

### EventRegionSummary

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| areaCode | integer | Y | TourAPI 시도 코드 | 1 | regions |
| areaName | string | Y | 표시용 지역명 | 서울 | regions |
| eventCount | integer | Y | 진행·예정 이벤트 수 | 12 | events |
| newCount | integer | Y | 최근 N일 내 추가 수. 0보다 크면 칩 강조 (EVT-008) | 2 | events |
| latestAddedAt | datetime\|null | Y | 가장 최근 추가 시각 | 예: 2026-08-30T04:30:00+09:00 | events |

### BadgeSummary

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| badgeId | uuid | Y | 뱃지 ID | bdg_01 | badges |
| type | enum | Y | EVENT\|AREA\|COMPLETION\|RECORD | EVENT | badges |
| name | string | Y | locale별 이름 | 서울 축제 참여 | badges |
| description | string | Y | 조건 설명 | 현장에서 게시글 1개 | badges |
| iconUrl | url | Y | 아이콘 | https://cdn/... | badges |
| isObtainable | boolean | Y | 진행률 분모 포함 | true | badges |
| earned | boolean | Y | 사용자 획득 여부 | false | user_badges |
| earnedAt | datetime\|null | Y | 획득 시각 |  | user_badges |

### BadgeCollection

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| earnedCount | integer | Y | 획득 수 | 7 | user_badges |
| obtainableCount | integer | Y | 현재 획득 가능 전체 | 20 | badges |
| progress | number | Y | earned/obtainable | 0.35 | 계산 |
| items | BadgeSummary[] | Y | 획득·미획득 전체 | [...] | badges/user_badges |

### Notification

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| notificationId | uuid | Y | 알림 ID | ntf_01 | notifications |
| type | enum | Y | POST_LIKE\|FOLLOW\|BADGE_EARNED\|SYSTEM | FOLLOW | notifications |
| actor | UserSummary\|null | Y | 행위자 | {...} | users |
| targetType | enum | Y | POST\|USER\|BADGE\|NONE | USER | notifications |
| targetId | string\|null | Y | 대상 ID | usr_02 | notifications |
| messageKey | string | Y | i18n 문구 키 | notification.follow | notifications |
| messageParams | object | Y | 문구 변수 | {nickname:'콩'} | notifications |
| isRead | boolean | Y | 읽음 여부 | false | notifications |

### RankingEntry

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| rank | integer | Y | 현재 순위 | 1 | place_rankings |
| previousRank | integer\|null | Y | 직전 순위 | 3 | place_rankings |
| change | integer\|null | Y | 상승 양수 | 2 | 계산 |
| score | number | Y | 집계 점수 | 812.5 | place_rankings |
| place | PlaceSummary | Y | 장소 | {...} | places |
| period | enum | Y | DAILY\|WEEKLY\|MONTHLY\|ALL | WEEKLY | place_rankings |
| theme | string\|null | Y | 테마 | KPOP | place_rankings |

### SearchResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| query | string | Y | 검색어 | 경복궁 | search_logs |
| places | SearchSection<PlaceSummary> | Y | 장소 상위 결과 | {...} | places |
| posts | SearchSection<PostSummary> | Y | 게시글 상위 결과 | {...} | posts |
| users | SearchSection<UserSummary> | Y | 사용자 상위 결과 | {...} | users |
| tags | SearchSection<TagSummary> | Y | 태그 상위 결과 | {...} | tags |
| matchedRegion | Region\|null | Y | 검색어가 지역명과 일치하면 필터 칩으로 전환할 지역 (SCH-008) | {...} | regions |

### BatchRun

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| runId | uuid | Y | 실행 ID | run_01 | sync_logs |
| jobType | string | Y | 작업 유형 | PLACE_SYNC | sync_logs |
| status | enum | Y | QUEUED\|RUNNING\|SUCCESS\|FAIL | RUNNING | sync_logs |
| processedCount | integer | Y | 처리 수 | 1200 | sync_logs |
| failedCount | integer | Y | 실패 수 | 2 | sync_logs |
| startedAt | datetime\|null | Y | 시작 시각 | 예: 2026-09-01T05:00:00+09:00 | sync_logs |

### Report

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| reportId | uuid | Y | 신고 ID | rpt_01 | reports |
| reporterId | uuid | Y | 신고자 | usr_01 | reports |
| targetType | enum | Y | POST\|PLACE\|COMMENT\|USER | POST | reports |
| targetId | string | Y | 대상 ID | pst_01 | reports |
| reason | enum | Y | 신고 사유 | SPAM | reports |
| status | enum | Y | PENDING\|RESOLVED\|REJECTED | PENDING | reports |

### ErrorBody

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| code | string | Y | 분기용 안정 에러 코드 | POST_IMAGE_REQUIRED | 에러 코드 |
| messageKey | string | Y | i18n 문구 키 | error.post.imageRequired | i18n |
| messageParams | object | Y | 문구 치환 변수 | {min:1,max:4} | - |
| violations | array<object>\|null | Y | 필드별 검증 오류 | [{field:'imageKeys'}] | - |
| retryAfterSec | integer\|null | Y | 429 재시도 대기 초 | 60 | - |
| details | object\|null | Y | 도메인별 추가 정보 |  | - |

### NotificationPreferences

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| postLike | boolean | Y | 게시글 좋아요 알림 | true | users |
| follow | boolean | Y | 팔로우 알림 | true | users |
| badgeEarned | boolean | Y | 뱃지 획득 알림 | true | users |
| system | boolean | Y | 시스템 공지 | true | users |

### DeviceResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| deviceId | uuid | Y | 등록된 기기 ID | dev_01 | user_devices |
| platform | enum | Y | ANDROID\|IOS | ANDROID | user_devices |
| pushEnabled | boolean | Y | 유효 FCM 토큰 존재 | true | user_devices |
| updatedAt | datetime | Y | 마지막 갱신 시각 | 예: 2026-09-01T10:00:00+09:00 | user_devices |

### BookmarkItem

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| targetType | enum | Y | POST\|PLACE | POST | bookmarks |
| targetId | string | Y | 대상 ID | pst_01 | bookmarks |
| savedAt | datetime | Y | 저장 시각 | 예: 2026-09-01T09:00:00+09:00 | bookmarks |
| post | PostSummary\|null | Y | 게시글 대상이면 값 | {...} | posts |
| place | PlaceSummary\|null | Y | 장소 대상이면 값 |  | places |

### DeletionPreview

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| postCount | integer | Y | 영향 게시글 수 | 12 | posts |
| imageCount | integer | Y | 삭제될 사진 수 (USER-014) | 31 | post_images |
| commentCount | integer | Y | 영향 댓글 수 | 31 | comments |
| followerCount | integer | Y | 해제될 팔로워 수 | 8 | follows |
| badgeCount | integer | Y | 삭제될 사용자 뱃지 수 | 7 | user_badges |
| visitCount | integer | Y | 삭제될 방문 기록 수 | 20 | visits |
| gracePeriodDays | integer | Y | 복구 유예 일수 | 30 | 정책 |

### DeletionReceipt

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| status | enum | Y | WITHDRAWN | WITHDRAWN | users |
| withdrawnAt | datetime | Y | 탈퇴 시각 | 예: 2026-09-01T10:00:00+09:00 | users |
| purgeScheduledAt | datetime | Y | 물리 삭제 예정 시각 | 예: 2026-10-01T10:00:00+09:00 | users |
| restoreKey | string | Y | 복구 확인 1회 키 | restore_... | users |

### FollowResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| followingUserId | uuid | Y | 팔로우 대상 | usr_02 | follows |
| isFollowing | boolean | Y | 요청 후 상태 | true | follows |
| followerCount | integer | Y | 대상의 최신 팔로워 수 | 31 | users |

### NearbyPlaceResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| exactMatch | PlaceSummary\|null | Y | 선택 좌표의 최우선 장소 | {...} | places |
| candidates | PlaceSummary[] | Y | 거리순 후보 | [...] | places |
| createAllowed | boolean | Y | 사용자 장소 생성 가능 | true | places |
| searchedRadiusM | integer | Y | 적용 탐색 반경 | 500 | 계산 |
| nearestDistanceM | integer\|null | Y | 반경 내 후보가 없을 때 전체 장소 중 최근접 거리(m) | 1250 | places |

### CreatePlaceResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| place | PlaceSummary | Y | 생성·재사용 장소 | {...} | places |
| created | boolean | Y | 신규 생성 여부 | true | places |
| duplicateOfPlaceId | uuid\|null | Y | 중복 판정 시 기존 장소 |  | places |

### BookmarkResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| targetType | enum | Y | POST\|PLACE | PLACE | bookmarks |
| targetId | string | Y | 대상 ID | plc_01 | bookmarks |
| isBookmarked | boolean | Y | 요청 후 상태 | true | bookmarks |
| savedAt | datetime\|null | Y | 저장 해제 시 null | 예: 2026-09-01T10:00:00+09:00 | bookmarks |

### CreatePostResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| postId | string | Y | 생성된 게시글 ID | pst_01 | posts |
| mediaStatus | enum | Y | PROCESSING\|READY\|FAILED | PROCESSING | Redis/post_images |
| tierResult | TierResult | Y | 서버 판정 등급 | {...} | posts/places |
| visitRecorded | boolean | Y | 방문 기록 생성 여부 | true | visits |
| earnedBadges | BadgeSummary[] | Y | 이번 요청으로 획득한 뱃지 | [...] | user_badges |

### LikeResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| targetType | enum | Y | POST\|COMMENT | POST | likes |
| targetId | string | Y | 대상 ID | pst_01 | likes |
| isLiked | boolean | Y | 요청 후 상태 | true | likes |
| likeCount | integer | Y | 대상의 최신 좋아요 수 | 33 | posts/comments |

### ReportReceipt

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| reportId | uuid | Y | 접수 ID | rpt_01 | reports |
| status | enum | Y | PENDING | PENDING | reports |
| createdAt | datetime | Y | 접수 시각 | 예: 2026-09-01T10:00:00+09:00 | reports |

### ShareMetadata

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| shareUrl | url | Y | 공유·딥링크 URL | https://snaphere.app/p/pst_01 | - |
| title | string | Y | 공유 제목 | 경복궁에서 | posts/places |
| description | string | Y | 공유 설명 | SnapHere에서 사진을 확인하세요 | i18n |
| imageUrl | url\|null | Y | Open Graph 이미지 | https://cdn/... | post_images |

### FollowingFeedResult

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| page | CursorPage<PostSummary> | Y | 팔로잉 게시글 페이지 | {...} | posts/follows |
| empty | boolean | Y | 피드 비어 있음 | false | 계산 |
| suggestedUsers | UserSummary[] | Y | 빈 상태 추천 사용자 | [...] | users/follows |

### TagSuggestion

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| name | string | Y | 추천 표시명 | 드라마촬영지 | tags |
| normalizedName | string | Y | 중복 판정명 | 드라마촬영지 | tags |
| tagId | uuid\|null | Y | 기존 태그이면 ID | tag_01 | tags |
| source | enum | Y | EXISTING\|NEW\|EVENT_FIXED | EXISTING | tags/events |

### HeatmapCellDetail

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| cell | HeatmapCell | Y | 선택 셀 집계 | {...} | heatmap_cells |
| topPlace | PlaceSummary\|null | Y | 대표 장소 | {...} | places |
| samplePosts | PostSummary[] | Y | 최대 10개 후보 사진 | [...] | posts |
| rotationIntervalMs | integer | Y | 클라이언트 교체 간격 | 3000 | 정책 |

### Visit

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| visitId | uuid | Y | 방문 ID | vst_01 | visits |
| place | PlaceSummary | Y | 방문 장소 | {...} | places |
| postId | uuid | Y | 근거 게시글 | pst_01 | visits |
| visitedOn | date | Y | 방문 일자 | 예: 2026-09-01 | visits |

### VisitMap

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| points | array<object> | Y | 지도 마커 {placeId,lat,lng,visitCount} | [...] | visits/places |
| bounds | object\|null | Y | 전체 마커 경계 | {west:126.8,east:127.2} | 계산 |
| badges | BadgeSummary[] | Y | 지도 하단 수집 뱃지 | [...] | user_badges |

### EventUploadContext

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| event | EventSummary | Y | 참여 이벤트 | {...} | events |
| place | PlaceSummary | Y | 고정 행사 장소 | {...} | places |
| fixedTags | TagSummary[] | Y | 수정 불가 태그 | [...] | events/tags |
| verifyRadiusM | integer | Y | 이벤트→지역→2000 적용값 | 2000 | events/regions |
| badge | BadgeSummary\|null | Y | 획득 가능 뱃지 | {...} | badges |

### BadgeDetail

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| badge | BadgeSummary | Y | 뱃지 기본 정보 | {...} | badges |
| condition | object | Y | 해석된 획득 조건 | {type:'EVENT_POST',count:1} | badges.condition_json |
| currentValue | integer | Y | 현재 진행값 | 0 | visits/posts |
| targetValue | integer | Y | 목표값 | 1 | badges.condition_json |
| sourcePostId | uuid\|null | Y | 획득 근거 게시글 |  | user_badges |

### UnreadCount

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| count | integer | Y | 안읽은 알림 수 | 3 | notifications |
| hasUnread | boolean | Y | 탭 배지 표시 여부 | true | 계산 |

### Recommendation

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| place | PlaceSummary | Y | 추천 장소 | {...} | places |
| reasonCode | string | Y | 추천 사유 코드 | TRENDING_NEARBY | 계산 |
| reasonParams | object | Y | 사유 문구 변수 | {distanceM:850} | 계산 |
| score | number | Y | 내부 정렬 점수 | 0.91 | place_rankings |

### PopularKeyword

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| rank | integer | Y | 현재 순위 | 1 | 집계 |
| keyword | string | Y | 검색어 | 경복궁 | search_logs |
| searchCount | integer | Y | 집계 검색 수 | 1024 | search_logs |
| areaCode | integer\|null | Y | 지역별 집계면 코드 | 1 | search_logs |

### RecentSearch

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| searchLogId | uuid | Y | 검색 로그 ID | 550e8400-e29b-41d4-a716-446655440000 | Redis |
| keyword | string | Y | 검색어 | 경복궁 | Redis |
| searchedAt | datetime | Y | 검색 시각 | 예: 2026-09-01T09:00:00+09:00 | Redis |

### SyncLog

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| syncId | uuid | Y | 동기화 실행 ID | sync_01 | sync_logs |
| jobType | string | Y | 작업 유형 | PLACE_SYNC | sync_logs |
| areaCode | integer\|null | Y | 처리 지역 | 1 | sync_logs |
| contentTypeId | integer\|null | Y | 콘텐츠 유형 | 12 | sync_logs |
| result | enum | Y | SUCCESS\|FAIL\|PARTIAL | SUCCESS | sync_logs |
| count | integer | Y | 처리 건수 | 1200 | sync_logs |
| message | string\|null | Y | 오류·요약 |  | sync_logs |
| startedAt | datetime | Y | 시작 시각 | 예: 2026-09-01T05:00:00+09:00 | sync_logs |
| finishedAt | datetime\|null | Y | 종료 시각 | 예: 2026-09-01T05:03:00+09:00 | sync_logs |

### PostImage

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| postImageId | uuid | Y | 이미지 ID | img_01 | post_images |
| imageUrl | url | Y | 원본·최적화 이미지 URL | https://cdn/... | post_images |
| thumbnailUrl | url | Y | 썸네일 URL | https://cdn/thumb/... | post_images |
| aspectRatio | number | Y | 가로/세로 비율 | 1.333 | post_images |
| sortOrder | integer | Y | 1부터 정렬 순서 (1~4) | 0 | post_images |

### HeatmapCell

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| cellKey | string | Y | 기간·격자 단계·좌표 인덱스를 포함한 불투명 키 | hmc_V0VFS0xZfDJ8Mzc1MHwxMjY5MA | heatmap_cells |
| lat | number | Y | 셀 중심 위도 | 37.55 | heatmap_cells |
| lng | number | Y | 셀 중심 경도 | 126.99 | heatmap_cells |
| postCount | integer | Y | 게시글 수 | 42 | heatmap_cells |
| intensity | number | Y | 0~1 로그 정규화 밀집도 log(count+1)/log(maxCount+1) (MAP-010) | 0.62 | 계산 |
| visitCount | integer | Y | 기간 방문 수. VST 방문 저장 구현 전까지 0 | 0 | heatmap_cells |
| userCount | integer | Y | 중복 제거 사용자 수 | 20 | heatmap_cells |
| topPlaceId | uuid\|null | Y | 대표 장소 | plc_01 | heatmap_cells |
| samplePostIds | uuid[] | Y | 최대 10개 후보 | [...] | heatmap_cells |
| lastPostedAt | datetime\|null | Y | 마지막 게시 시각 | 예: 2026-09-01T09:00:00+09:00 | heatmap_cells |

### VisitRegionStat

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| region | Region | Y | 지역 | {...} | regions |
| visitCount | integer | Y | 방문 횟수 | 12 | visits |
| placeCount | integer | Y | 방문 장소 수 | 8 | visits |
| lastVisitedOn | date\|null | Y | 최근 방문일 | 예: 2026-09-01 | visits |

### SearchSection<T>

| 필드 경로 | 타입 | 필수 | 설명 | 예시 | 원천 |
|---|---|---|---|---|---|
| items | array<T> | Y | 타입별 상위 결과 | [...] | 검색 대상 |
| nextCursor | string\|null | Y | 더보기 커서 | eyJ... | - |
| hasNext | boolean | Y | 추가 결과 존재 | true | - |
| totalApproximate | integer\|null | Y | 근사 결과 수 | 120 | 검색 인덱스 |


## 5. 에러 코드 (56개)

> 앱은 HTTP 상태가 아니라 `error.code` 로 분기한다.

| 에러 코드 | HTTP | 도메인 | 의미 | 발생 조건 | 클라이언트 처리 |
|---|---|---|---|---|---|
| COMMON_400 | 400 | 공통 | 요청 형식이 잘못됨 | 필드별 violations 반환 | 요청값 수정 |
| AUTH_REQUIRED | 401 | 인증 | 로그인 필요 | Authorization 누락·만료 | 로그인 시트/토큰 재발급 |
| AUTH_INVALID_GOOGLE_TOKEN | 401 | 인증 | Google 토큰 검증 실패 | 서명·exp·iss 실패 | 다시 로그인 |
| AUTH_AUDIENCE_MISMATCH | 401 | 인증 | 다른 앱용 Google 토큰 | aud 불일치 | 클라이언트 설정 확인 |
| AUTH_INVALID_REFRESH | 401 | 인증 | 리프레시 토큰 무효 | 해시 미일치·폐기됨 | 재로그인 |
| AUTH_REFRESH_EXPIRED | 401 | 인증 | 리프레시 토큰 만료 | 30일 경과 | 재로그인 |
| AUTH_TOKEN_REUSED | 401 | 인증 | 폐기 토큰 재사용 감지 | 탈취 가능성으로 전 토큰 폐기 | 전 기기 재로그인 |
| AUTH_TERMS_REQUIRED | 403 | 인증 | 약관 동의 필요 | 온보딩 미완료 | 온보딩 이동 |
| ADMIN_REQUIRED | 403 | 권한 | 관리자 권한 필요 | ADMIN 역할 아님 | 접근 차단 |
| COMMON_404 | 404 | 공통 | 대상을 찾을 수 없음 | ID 없음 또는 비공개 | 목록으로 이동 |
| COMMON_409 | 409 | 공통 | 현재 상태와 충돌 | 중복·상태 전이 불가 | 최신 상태 재조회 |
| COMMON_422 | 422 | 공통 | 업무 규칙 검증 실패 | 입력 형식은 맞으나 규칙 위반 | 안내 문구 표시 |
| COMMON_429 | 429 | 공통 | 호출 한도 초과 | retryAfterSec 포함 | 대기 후 재시도 |
| COMMON_500 | 500 | 공통 | 서버 내부 오류 | traceId 포함 | 일시 오류 안내 |
| USER_NOT_FOUND | 404 | 사용자 | 사용자 없음 | 탈퇴·삭제 포함 | 프로필 닫기 |
| USER_NICKNAME_INVALID | 422 | 사용자 | 닉네임 규칙 위반 | 2~20자·금칙어 | 필드 오류 표시 |
| USER_WITHDRAWN | 409 | 사용자 | 탈퇴 유예 계정 | recoveryOffered 제공 | 복구 선택 |
| USER_RECOVERY_EXPIRED | 410 | 사용자 | 복구 기한 만료 | 30일 초과 | 신규 가입 안내 |
| USER_RESTORE_KEY_INVALID | 401 | 사용자 | 복구 키 무효 | 만료·사용됨 | 다시 로그인 |
| USER_ALREADY_WITHDRAWN | 409 | 사용자 | 이미 탈퇴 처리됨 | 중복 요청 | 상태 안내 |
| SOC_SELF_FOLLOW | 400 | 소셜 | 자기 자신 팔로우 | path userId=본인 | 버튼 상태 복원 |
| SOC_DAILY_LIMIT | 429 | 소셜 | 일일 팔로우 200회 초과 | retryAfterSec 제공 | 다음 날 재시도 |
| PLACE_NOT_FOUND | 404 | 장소 | 장소 없음·숨김 | - | 장소 재선택 |
| PLACE_INVALID_COORDINATE | 422 | 장소 | 좌표 형식 오류 | WGS84 범위 위반 | 좌표 재확인 |
| PLACE_OUT_OF_SERVICE_AREA | 422 | 장소 | 대한민국 밖 좌표 | 서비스 범위 밖 | 생성 차단 |
| PLACE_RADIUS_TOO_LARGE | 422 | 장소 | 탐색 반경 초과 | 20km 초과 | 반경 축소 |
| PLACE_DAILY_LIMIT | 429 | 장소 | 사용자 장소 일일 5개 초과 | - | 다음 날 재시도 |
| POST_NOT_FOUND | 404 | 게시글 | 게시글 없음 | 삭제 포함 | 목록으로 이동 |
| POST_NOT_VISIBLE | 404 | 게시글 | 삭제·블라인드 게시글 | 공개 공유 차단 | 접근 차단 |
| POST_NOT_AUTHOR | 403 | 게시글 | 작성자 권한 없음 | - | 수정·삭제 차단 |
| POST_IMAGE_REQUIRED | 422 | 게시글 | 사진 1장 이상 필요 | 1~4장 | 사진 선택 이동 |
| POST_PLACE_REQUIRED | 422 | 게시글 | 장소 필수 | - | 장소 단계 이동 |
| POST_TAG_REQUIRED | 422 | 게시글 | 태그 1개 이상 필요 | 1~10개 | 태그 입력 이동 |
| POST_INVALID_TAKEN_AT | 422 | 게시글 | 촬영 시각 오류 | 미래 시각 등 | 앨범 정보 재확인 |
| POST_DAILY_LIMIT | 429 | 게시글 | 일일 게시글 30개 초과 | - | 다음 날 재시도 |
| POST_PLACE_DAILY_LIMIT | 429 | 게시글 | 같은 장소 일일 3개 초과 | - | 다른 장소/다음 날 |
| POST_DUPLICATE_IMAGE | 409 | 게시글 | 본인 계정 중복 이미지 | image_hash 중복 | 다른 사진 선택 |
| POST_UPLOAD_SUSPENDED | 403 | 게시글 | 신고 누적 24시간 업로드 정지 | suspendedUntil 제공 | 남은 시간 표시 |
| MEDIA_COUNT_INVALID | 422 | 미디어 | 파일 수 오류 | 게시글 1~4장 | 파일 수 조정 |
| MEDIA_TOO_LARGE | 413 | 미디어 | 장당 10MB 초과 | - | 압축·다른 파일 |
| MEDIA_TYPE_UNSUPPORTED | 415 | 미디어 | 지원하지 않는 형식 | jpeg/png/heic/webp | 파일 변환 |
| MEDIA_NOT_FOUND | 422 | 미디어 | 업로드 키 없음 | S3 업로드 미완료 | 재업로드 |
| COMMENT_NOT_FOUND | 404 | 댓글 | 댓글 없음 | - | 스레드 새로고침 |
| COMMENT_NOT_AUTHOR | 403 | 댓글 | 댓글 작성자 아님 | - | 수정·삭제 차단 |
| COMMENT_LENGTH_INVALID | 422 | 댓글 | 댓글 길이 오류 | 1~1000자 | 입력 수정 |
| REPORT_DUPLICATE | 409 | 신고 | 동일 대상 중복 신고 | 사용자+대상 unique | 접수 완료 상태 표시 |
| REPORT_NOT_FOUND | 404 | 신고 | 신고 없음 | - | 목록 새로고침 |
| EVENT_NOT_FOUND | 404 | 이벤트 | 이벤트 없음 | - | 목록으로 이동 |
| EVENT_DATE_INVALID | 422 | 이벤트 | 종료일이 시작일보다 빠름 | - | 날짜 수정 |
| BADGE_NOT_FOUND | 404 | 뱃지 | 뱃지 없음 | 비활성·삭제 포함 | 수집함으로 이동 |
| TAG_NOT_FOUND | 404 | 태그 | 태그 없음 | 병합·삭제된 태그 | 검색으로 이동 |
| NOTIFICATION_NOT_FOUND | 404 | 알림 | 알림 없음 | 삭제·타 사용자 알림 | 알림함 새로고침 |
| MAP_INVALID_BOUNDS | 422 | 지도 | 지도 경계값 오류 | west<east, south<north | 현재 화면 재요청 |
| BATCH_ALREADY_RUNNING | 409 | 운영 | 같은 배치 실행 중 | runId 제공 | 기존 실행 확인 |
| POST_MEDIA_PROCESSING | 409 | 게시글 | 이미지 정제 처리 중 | 작성자 상세 조회 | 잠시 후 재시도 |
| POST_MEDIA_FAILED | 409 | 게시글 | 이미지 정제 최종 실패 | 작성자 상세 조회 | 이미지 재업로드 |

## 6. 배치 · 비동기 작업 (13개)

| JOB ID | 작업 유형 | 주기·트리거 | 처리 내용 | 정합성·실패 정책 | 관련 테이블 | 관련 요구사항 | 호출 방식 |
|---|---|---|---|---|---|---|---|
| JOB-001 | PLACE_SYNC | 매일 + 수동 | 지역×콘텐츠 타입별 UPSERT·좌표 검증 | 조합 실패 격리 | places, place_details, sigungu, sync_logs | PLC-003~010 | 관리자 API 202 |
| JOB-002 | EVENT_SYNC | 매일 04:30 KST + 수동 | TourAPI 행사를 실행일 -30일~+1년 범위로 지역별 UPSERT | 지역 실패 격리 | events, places, sync_logs | EVT-001~003, SYS-015 | 관리자 API 202 |
| JOB-003 | IMAGE_POSTPROCESS | 게시글 생성 후 + 5분 재시도 | 비공개 원본의 EXIF 제거·재인코딩, 공개 정제본·썸네일·해시 생성 | 준비 전 게시글 비공개, Redis 상태·최대 5회, 최종 실패 비공개 유지 | post_images, Redis | PST-019~021, SYS-021 | 커밋 후 비동기 |
| JOB-004 | BADGE_EVALUATION | 게시글 커밋 후 | 행사·지역·완주·기록 조건 평가 | UNIQUE로 중복 방지 | badges, user_badges, visits | BDG-001~007 | 비동기 큐 |
| JOB-005 | NOTIFICATION_DISPATCH | 트랜잭션 커밋 후 | 좋아요·팔로우·뱃지·시스템 알림 발송 | 자기 자신·중복 제외 | notifications, user_devices | BDG-008, NTF-001~010 | 비동기 큐 |
| JOB-006 | HEATMAP_REALTIME | 1분 | 최근 1시간(LAST_1H) 히트맵 셀 집계 · intensity 정규화 분모(maxCount) 산출 | 데이터 부족 시 LAST_24H 폴백 | heatmap_cells | MAP-008~016 | 스케줄러 |
| JOB-007 | HEATMAP_PERIODIC | 10분 | LAST_24H·WEEKLY·MONTHLY 히트맵 및 후보 사진 최대 10장 집계 | 작성자 연속 중복 제거 | heatmap_cells | MAP-012, MAP-022~025 | 스케줄러 |
| JOB-008 | RANKING_RECALC | 주기 + 수동 | 장소 점수·기간·테마·이전 순위 집계 | 결정적 보조 정렬 | place_rankings | RNK-001~010 | 스케줄러 |
| JOB-013 | POST_RANKING_RECALC | 10분 + 수동 | 기간(DAY/WEEK/MONTH/ALL)별 게시글 인기 점수·순위 집계 | 결정적 보조 정렬(score DESC, post_id ASC); 조회 시 계산 금지 | post_rankings, posts, likes, comments | PST-035, CMU-002, CMU-008~009 | 스케줄러 |
| JOB-009 | COUNTER_RECONCILE | 매일 05:10 KST + 수동 | 팔로워·게시글·장소·댓글·태그·뱃지·행사 카운터 보정 | 원본 관계 COUNT와 대조 | users, places, posts, comments, tags, badges, events | SOC-008, SYS-007, SYS-015 | 스케줄러·관리자 API 202 |
| JOB-010 | ACCOUNT_PURGE | 매일 05:00 | 탈퇴 30일 경과 계정·S3 객체 물리 삭제 | 감사 로그 보존 | users, account_deletion_logs | USER-019 | 스케줄러 |
| JOB-011 | POST_MEDIA_PURGE | 매일 | 게시글 삭제 30일 경과 미디어 삭제 | 방문·뱃지 유지 | posts, post_images | PST-038~039 | 스케줄러 |
| JOB-012 | NOTIFICATION_PURGE | 매일 | 읽은 지 90일 지난 알림 삭제 | 보존기간 90일 고정 (NTF-014) | notifications | NTF-014 | 스케줄러 |

## 7. 요구사항 추적 (291건 · 미매핑 0)

### 인증 및 권한 관리

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| AUTH-001 | 구글 로그인 | 회원·비회원 | Must | API 직접 | API-AUTH-001 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-002 | 구글 회원가입 | 비회원 | Must | API 직접 | API-AUTH-001 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-003 | ID Token 검증 | 시스템 | Must | API 직접 | API-AUTH-001 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-004 | 가입 온보딩 | 회원 | Must | API 직접 | API-AUTH-002 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-005 | 로그아웃 | 회원 | Must | API 직접 | API-AUTH-004 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-006 | 전체 기기 로그아웃 | 회원 | Should | API 직접 | API-AUTH-005 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-007 | 토큰 재발급 | 회원 | Must | API 직접 | API-AUTH-003 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-008 | 리프레시 토큰 회전 | 시스템 | Must | API 직접 | API-AUTH-003 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-009 | 토큰 해시 저장 | 시스템 | Must | API 직접 | API-AUTH-003 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-010 | 비로그인 조회 허용 | 비회원 | Must | API 내부 | - | - | 공통 인증·인가 미들웨어 정책 |
| AUTH-011 | 쓰기 동작 로그인 요구 | 회원 | Must | API 내부 | - | - | 공통 인증·인가 미들웨어 정책 |
| AUTH-012 | 로그인 시트 유도 | 비회원 | Must | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| AUTH-013 | 작성자 권한 확인 | 회원 | Must | API 직접 | API-PST-007, API-PST-008, API-CMU-007, API-CMU-008 |  | 엔드포인트 계약에 직접 반영 |
| AUTH-014 | 관리자 권한 확인 | 관리자 | Must | API 내부 | - | - | 공통 인증·인가 미들웨어 정책 |

### 사용자 정보 및 계정

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| USER-001 | 내 프로필 조회 | 회원 | Must | API 직접 | API-USER-001 |  | 엔드포인트 계약에 직접 반영 |
| USER-002 | 프로필 수정 | 회원 | Must | API 직접 | API-USER-002 |  | 엔드포인트 계약에 직접 반영 |
| USER-003 | 닉네임 규칙 검증 | 시스템 | Should | API 직접 | API-AUTH-002, API-USER-002 |  | 엔드포인트 계약에 직접 반영 |
| USER-004 | 프로필 이미지 업로드 | 회원 | Should | API 직접 | API-PST-001 |  | 엔드포인트 계약에 직접 반영 |
| USER-005 | 타 사용자 프로필 조회 | 회원·비회원 | Must | API 직접 | API-USER-004 |  | 엔드포인트 계약에 직접 반영 |
| USER-006 | 이용 약관 동의 | 회원 | Must | API 직접 | API-AUTH-002 |  | 엔드포인트 계약에 직접 반영 |
| USER-007 | FCM 토큰 등록·갱신 | 회원 | Must | API 직접 | API-USER-003 |  | 엔드포인트 계약에 직접 반영 |
| USER-008 | 정적 그리드 레이아웃 | 회원 | Must | API 직접 | API-USER-005 |  | 엔드포인트 계약에 직접 반영 |
| USER-009 | 통계 4종 표시 | 회원 | Must | API 직접 | API-USER-001 |  | 엔드포인트 계약에 직접 반영 |
| USER-010 | 내 게시글 목록 | 회원·비회원 | Must | API 직접 | API-USER-005 |  | 엔드포인트 계약에 직접 반영 |
| USER-011 | 좋아요한 게시글 | 회원 | Should | API 직접 | API-USER-006 |  | 엔드포인트 계약에 직접 반영 |
| USER-012 | 저장함 조회 | 회원 | Should | API 직접 | API-USER-007 |  | 엔드포인트 계약에 직접 반영 |
| USER-013 | 하위 메뉴 구성 | 회원 | Must | API 직접 | API-USER-007 |  | 엔드포인트 계약에 직접 반영 |
| USER-014 | 삭제 전 미리보기 | 회원 | Should | API 직접 | API-USER-008 |  | 엔드포인트 계약에 직접 반영 |
| USER-015 | 계정 삭제 요청 | 회원 | Must | API 직접 | API-USER-009 |  | 엔드포인트 계약에 직접 반영 |
| USER-016 | 콘텐츠 처리 선택 | 회원 | Should | API 직접 | API-USER-009 |  | 엔드포인트 계약에 직접 반영 |
| USER-017 | 개인식별정보 즉시 파기 | 시스템 | Must | API 직접 | API-USER-009 |  | 엔드포인트 계약에 직접 반영 |
| USER-018 | 연관 데이터 즉시 정리 | 시스템 | Must | API 직접 | API-USER-009 |  | 엔드포인트 계약에 직접 반영 |
| USER-019 | 계정 파기 배치 | 시스템 | Must | API 직접 | API-USER-009 | JOB-010 | 엔드포인트 계약에 직접 반영 |
| USER-020 | 탈퇴 계정 복구 | 회원 | Should | API 직접 | API-AUTH-001, API-AUTH-006 |  | 엔드포인트 계약에 직접 반영 |
| USER-021 | 복구 한계 안내 | 회원 | Must | API 직접 | API-AUTH-006 |  | 엔드포인트 계약에 직접 반영 |
| USER-022 | 관리자 강제 삭제 | 관리자 | Could | API 직접 | API-ADM-011 |  | 엔드포인트 계약에 직접 반영 |
| USER-023 | 알림 수신 설정 | 회원 | Could | API 직접 | API-USER-010 |  | 엔드포인트 계약에 직접 반영 |

### 소셜 (팔로우)

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| SOC-001 | 팔로우 / 언팔로우 | 회원 | Must | API 직접 | API-SOC-001, API-SOC-002 |  | 엔드포인트 계약에 직접 반영 |
| SOC-002 | 멱등 처리 | 시스템 | Must | API 직접 | API-SOC-001, API-SOC-002 |  | 엔드포인트 계약에 직접 반영 |
| SOC-003 | 카운터 정합 | 시스템 | Must | API 직접 | API-SOC-001, API-SOC-002 |  | 엔드포인트 계약에 직접 반영 |
| SOC-004 | 최신 상태 반환 | 시스템 | Must | API 직접 | API-SOC-001, API-SOC-002 |  | 엔드포인트 계약에 직접 반영 |
| SOC-005 | 자기 자신 팔로우 차단 | 시스템 | Must | API 직접 | API-SOC-001 |  | 엔드포인트 계약에 직접 반영 |
| SOC-006 | 일일 팔로우 한도 | 시스템 | Should | API 직접 | API-SOC-001 |  | 엔드포인트 계약에 직접 반영 |
| SOC-007 | 동시성 처리 | 시스템 | Must | API 직접 | API-SOC-001, API-SOC-002 |  | 엔드포인트 계약에 직접 반영 |
| SOC-008 | 카운터 보정 배치 | 시스템 | Must | 배치 | - | JOB-009 | 스케줄·비동기 작업으로 구현 |
| SOC-009 | 탈퇴 시 관계 삭제 | 시스템 | Must | API 내부 | - | - | 공통 미들웨어·도메인 서비스·저장 규칙 |
| SOC-010 | 팔로워 목록 조회 | 회원·비회원 | Must | API 직접 | API-SOC-003 |  | 엔드포인트 계약에 직접 반영 |
| SOC-011 | 팔로잉 목록 조회 | 회원·비회원 | Must | API 직접 | API-SOC-004 |  | 엔드포인트 계약에 직접 반영 |
| SOC-012 | 맞팔 상태 표시 | 회원 | Should | API 직접 | API-SOC-003, API-SOC-004 |  | 엔드포인트 계약에 직접 반영 |
| SOC-013 | 사용자 게시글 목록 | 회원·비회원 | Must | API 직접 | API-USER-005 |  | 엔드포인트 계약에 직접 반영 |
| SOC-014 | 추천 사용자 조회 | 회원 | Could | API 직접 | API-SOC-005, API-CMU-002 |  | 엔드포인트 계약에 직접 반영 |

### 장소

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| PLC-001 | 지역 마스터 관리 | 시스템 | Must | API 직접 | API-PLC-001 |  | 엔드포인트 계약에 직접 반영 |
| PLC-002 | 시군구 마스터 관리 | 시스템 | Must | API 직접 | API-PLC-002 |  | 엔드포인트 계약에 직접 반영 (Sigungu[] 반환) |
| PLC-003 | 관광지 데이터 연동 | 시스템 | Must | 배치 | - | JOB-001 | 스케줄·비동기 작업으로 구현 |
| PLC-004 | 관광지 증분 갱신 | 시스템 | Must | 배치 | - | JOB-001 | 스케줄·비동기 작업으로 구현 |
| PLC-005 | 좌표 변환·검증 | 시스템 | Must | 배치 | - | JOB-001 | 스케줄·비동기 작업으로 구현 |
| PLC-006 | 상세 정보 지연 적재 | 시스템 | Should | API 직접 | API-PLC-005 | JOB-001 | 엔드포인트 계약에 직접 반영 |
| PLC-007 | 좌표 없는 데이터 처리 | 시스템 | Must | 배치 | - | JOB-001 | 스케줄·비동기 작업으로 구현 |
| PLC-008 | 조합 단위 트랜잭션 분리 | 시스템 | Must | 배치 | - | JOB-001 | 스케줄·비동기 작업으로 구현 |
| PLC-009 | 배치 실행 로그 | 관리자 | Should | API 직접 | API-ADM-002, API-ADM-003 | JOB-001 | 엔드포인트 계약에 직접 반영 |
| PLC-010 | 수동 동기화 트리거 | 관리자 | Should | API 직접 | API-ADM-001 | JOB-001 | 엔드포인트 계약에 직접 반영 |
| PLC-011 | 지역별 장소 목록 | 회원·비회원 | Must | API 직접 | API-PLC-003 |  | 엔드포인트 계약에 직접 반영 |
| PLC-012 | 장소 상세 조회 | 회원·비회원 | Must | API 직접 | API-PLC-005 |  | 엔드포인트 계약에 직접 반영 |
| PLC-013 | 장소별 게시글 목록 | 회원·비회원 | Must | API 직접 | API-PLC-006 |  | 엔드포인트 계약에 직접 반영 |
| PLC-014 | 장소 조회수 집계 | 시스템 | Could | API 직접 | API-PLC-005 |  | 엔드포인트 계약에 직접 반영 |
| PLC-015 | 장소 저장 | 회원 | Should | API 직접 | API-PLC-008, API-PLC-009 |  | 엔드포인트 계약에 직접 반영 |
| PLC-016 | 사용자 장소 생성 | 회원 | Must | API 직접 | API-PLC-007 |  | 엔드포인트 계약에 직접 반영 |
| PLC-017 | 중복 장소 방지 | 시스템 | Must | API 직접 | API-PLC-007 |  | 엔드포인트 계약에 직접 반영 |
| PLC-018 | 장소 생성 한도 | 시스템 | Should | API 직접 | API-PLC-007 |  | 엔드포인트 계약에 직접 반영 |
| PLC-019 | 서비스 범위 검증 | 시스템 | Should | API 직접 | API-PLC-007 |  | 엔드포인트 계약에 직접 반영 |
| PLC-020 | 지역 자동 판정 | 시스템 | Should | API 직접 | API-PLC-007 |  | 엔드포인트 계약에 직접 반영 |
| PLC-021 | 장소명 태그 자동 생성 | 시스템 | Must | API 직접 | API-CMU-011 |  | 엔드포인트 계약에 직접 반영 |
| PLC-022 | 인증 반경 개별 설정 | 관리자 | Must | API 직접 | API-ADM-005, API-ADM-006, API-ADM-007, API-ADM-008 |  | 엔드포인트 계약에 직접 반영 |
| PLC-023 | 장소 신고 처리 | 관리자 | Could | API 직접 | API-ADM-010, API-ADM-013 |  | 엔드포인트 계약에 직접 반영 |

### 게시글

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| PST-001 | 사진 필수 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-002 | 위치 필수 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-003 | 캡션 선택 입력 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-004 | 해시태그 최소 1개 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-005 | 앨범 선택 업로드 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-006 | 카메라 촬영 업로드 | 회원 | Should | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-007 | 사진 위 텍스트·이모티콘 | 회원 | Could | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| PST-008 | ① 장소 설정 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-009 | ② 위치 확인 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-010 | ③ 사진·캡션·태그 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-011 | ④ 게시 후 홈 복귀 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-012 | ⑤ 완료 모달 | 회원 | Should | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| PST-013 | 이미지 업로드 URL 발급 | 회원 | Must | API 직접 | API-PST-001 |  | 엔드포인트 계약에 직접 반영 |
| PST-014 | 클라이언트 직접 업로드 | 회원 | Must | API 직접 | API-PST-001 |  | 엔드포인트 계약에 직접 반영 |
| PST-015 | 미디어 형식·용량 검증 | 시스템 | Must | API 직접 | API-PST-001 |  | 엔드포인트 계약에 직접 반영 |
| PST-016 | 게시글 생성 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-017 | 필수값 검증 | 시스템 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-018 | 서버 지역 산출 | 시스템 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-019 | 이미지 후처리 | 시스템 | Must | API 직접 | API-PST-003 | JOB-003 | 엔드포인트 계약에 직접 반영 |
| PST-020 | EXIF 개인정보 제거 | 시스템 | Must | API 직접 | API-PST-003 | JOB-003 | 엔드포인트 계약에 직접 반영 |
| PST-021 | 대표 미디어 비율 제공 | 시스템 | Must | API 직접 | API-PST-003, API-PST-004 | JOB-003 | 엔드포인트 계약에 직접 반영 |
| PST-022 | 위치 신뢰도 판정 | 시스템 | Must | API 직접 | API-PST-002, API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-023 | 신뢰도 높음 | 시스템 | Should | API 직접 | API-PST-002, API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-024 | 신뢰도 보통 | 시스템 | Must | API 직접 | API-PST-002, API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-025 | 신뢰도 낮음 | 시스템 | Must | API 직접 | API-PST-002, API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-026 | 신뢰도 낮음 혜택 제외 | 시스템 | Must | API 직접 | API-PST-002, API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-027 | 인증 반경 기준값 | 관리자 | Should | API 직접 | API-PST-002, API-PST-003, API-ADM-006, API-ADM-007, API-ADM-008 |  | 엔드포인트 계약에 직접 반영 |
| PST-028 | 판정 근거 로깅 | 시스템 | Should | API 직접 | API-PST-002, API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-029 | 일일 게시글 한도 | 시스템 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-030 | 장소별 게시글 한도 | 시스템 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-031 | 중복 이미지 차단 | 시스템 | Should | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-032 | 업로드 정지 | 시스템 | Should | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| PST-033 | 게시글 상세 조회 | 회원·비회원 | Must | API 직접 | API-PST-006 |  | 엔드포인트 계약에 직접 반영 |
| PST-034 | 게시글 목록 조회 | 회원·비회원 | Must | API 직접 | API-PST-004 |  | 엔드포인트 계약에 직접 반영 |
| PST-035 | 기간별 인기 게시글 | 회원·비회원 | Must | API 직접 | API-PST-005 | JOB-013 | 엔드포인트 계약에 직접 반영 |
| PST-036 | 게시글 수정 | 회원 | Should | API 직접 | API-PST-007 |  | 엔드포인트 계약에 직접 반영 |
| PST-037 | 위치·등급 수정 금지 | 시스템 | Must | API 직접 | API-PST-007 |  | 엔드포인트 계약에 직접 반영 |
| PST-038 | 게시글 삭제 | 회원 | Must | API 직접 | API-PST-008 | JOB-011 | 엔드포인트 계약에 직접 반영 |
| PST-039 | 삭제 후 방문·뱃지 유지 | 시스템 | Must | API 직접 | API-PST-008 | JOB-011 | 엔드포인트 계약에 직접 반영 |
| PST-040 | 좋아요 | 회원 | Must | API 직접 | API-PST-009, API-PST-010 |  | 엔드포인트 계약에 직접 반영 |
| PST-041 | 자기 좋아요 랭킹 제외 | 시스템 | Should | API 직접 | API-PST-009 |  | 엔드포인트 계약에 직접 반영 |
| PST-042 | 조회수 집계 | 시스템 | Could | API 직접 | API-PST-006 |  | 엔드포인트 계약에 직접 반영 |
| PST-043 | 게시글 신고 | 회원 | Should | API 직접 | API-PST-013, API-ADM-009 |  | 엔드포인트 계약에 직접 반영 |
| PST-044 | 중복 신고 차단 | 시스템 | Should | API 직접 | API-PST-013, API-ADM-009 |  | 엔드포인트 계약에 직접 반영 |
| PST-045 | 자동 블라인드 | 시스템 | Should | API 직접 | API-PST-013, API-ADM-009, API-ADM-010 |  | 엔드포인트 계약에 직접 반영 |
| PST-046 | 신뢰 등급 배지 표시 | 회원·비회원 | Should | API 직접 | API-PST-006 |  | 엔드포인트 계약에 직접 반영 |
| PST-047 | 신뢰 등급 기준 안내 | 회원·비회원 | Should | API 직접 | API-PST-006 |  | 엔드포인트 계약에 직접 반영 |
| PST-048 | 업로드 전 등급 미리보기 | 회원 | Should | API 직접 | API-PST-002 |  | 엔드포인트 계약에 직접 반영 |
| PST-049 | 등급 향상 안내 | 회원 | Could | API 직접 | API-PST-002 |  | 엔드포인트 계약에 직접 반영 |

### 커뮤니티 · 댓글 · 태그

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| CMU-001 | 팔로잉 피드 | 회원 | Must | API 직접 | API-SOC-005, API-CMU-002 |  | 엔드포인트 계약에 직접 반영 |
| CMU-002 | 인기 피드 | 회원·비회원 | Must | API 직접 | API-CMU-001 | JOB-013 | 엔드포인트 계약에 직접 반영 |
| CMU-003 | 최근 피드 | 회원·비회원 | Must | API 직접 | API-CMU-003 |  | 엔드포인트 계약에 직접 반영 |
| CMU-004 | 탭 구성 | 회원·비회원 | Must | API 직접 | API-CMU-001, API-CMU-002, API-CMU-003 |  | 엔드포인트 계약에 직접 반영 |
| CMU-005 | 검색바 영역 | 회원·비회원 | Must | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| CMU-006 | 메이슨리 레이아웃 | 회원·비회원 | Must | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| CMU-007 | 기간 필터 | 회원·비회원 | Should | API 직접 | API-CMU-001 |  | 엔드포인트 계약에 직접 반영 |
| CMU-008 | 인기 점수 산출 | 시스템 | Must | API 직접 | API-PST-005, API-CMU-001 | JOB-013 | 엔드포인트 계약에 직접 반영 |
| CMU-009 | 팔로잉 가중치 정렬 | 회원 | Should | API 직접 | API-CMU-001 | JOB-013 | 엔드포인트 계약에 직접 반영 |
| CMU-010 | 커서 페이징 | 시스템 | Must | API 직접 | API-CMU-001, API-CMU-002, API-CMU-003 |  | 엔드포인트 계약에 직접 반영 |
| CMU-011 | 마지막 탭 기억 | 회원 | Could | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| CMU-012 | 댓글 작성 | 회원 | Must | API 직접 | API-CMU-005 |  | 엔드포인트 계약에 직접 반영 |
| CMU-013 | 댓글 조회 | 회원·비회원 | Must | API 직접 | API-CMU-004 |  | 엔드포인트 계약에 직접 반영 |
| CMU-014 | 대댓글 작성 | 회원 | Must | API 직접 | API-CMU-006 |  | 엔드포인트 계약에 직접 반영 |
| CMU-015 | 대댓글 깊이 1단계 | 시스템 | Must | API 직접 | API-CMU-004, API-CMU-006 |  | 엔드포인트 계약에 직접 반영 |
| CMU-016 | 댓글 수정 | 회원 | Should | API 직접 | API-CMU-007 |  | 엔드포인트 계약에 직접 반영 |
| CMU-017 | 댓글 삭제 | 회원 | Must | API 직접 | API-CMU-008 |  | 엔드포인트 계약에 직접 반영 |
| CMU-018 | 댓글 좋아요 | 회원 | Could | API 직접 | API-CMU-009, API-CMU-010 |  | 엔드포인트 계약에 직접 반영 |
| CMU-019 | 외부 공유 링크 생성 | 회원·비회원 | Must | API 직접 | API-PST-014 |  | 엔드포인트 계약에 직접 반영 |
| CMU-020 | 링크 미리보기 정보 제공 | 시스템 | Must | API 직접 | API-PST-014 |  | 엔드포인트 계약에 직접 반영 |
| CMU-021 | 앱 딥링크 연결 | 회원·비회원 | Should | API 직접 | API-PST-014 |  | 엔드포인트 계약에 직접 반영 |
| CMU-022 | 비공개 게시글 차단 | 시스템 | Must | API 직접 | API-PST-014 |  | 엔드포인트 계약에 직접 반영 |
| CMU-023 | 게시글 저장 | 회원 | Should | API 직접 | API-PST-011, API-PST-012 |  | 엔드포인트 계약에 직접 반영 |
| CMU-024 | 저장 대상 검증 | 시스템 | Must | API 직접 | API-PLC-008, API-PST-011 |  | 엔드포인트 계약에 직접 반영 |
| CMU-025 | 해시태그 추출·정규화 | 시스템 | Should | API 직접 | API-CMU-011 |  | 엔드포인트 계약에 직접 반영 |
| CMU-026 | 지역 태그 자동 추천 | 시스템 | Must | API 직접 | API-CMU-011 |  | 엔드포인트 계약에 직접 반영 |
| CMU-027 | 카테고리 태그 자동 추천 | 시스템 | Should | API 직접 | API-CMU-011 |  | 엔드포인트 계약에 직접 반영 |
| CMU-028 | 진행중 행사 태그 자동 추천 | 시스템 | Should | API 직접 | API-CMU-011 |  | 엔드포인트 계약에 직접 반영 |
| CMU-029 | 추천 태그 채택 구분 | 시스템 | Could | API 직접 | API-CMU-011 |  | 엔드포인트 계약에 직접 반영 |
| CMU-030 | 태그로 게시글 검색 | 회원·비회원 | Should | API 직접 | API-CMU-013 |  | 엔드포인트 계약에 직접 반영 |
| CMU-031 | 인기 태그 조회 | 회원·비회원 | Could | API 직접 | API-CMU-012 |  | 엔드포인트 계약에 직접 반영 |
| CMU-032 | 수정 시 태그 재설정 | 시스템 | Must | API 직접 | API-PST-007 |  | 엔드포인트 계약에 직접 반영 |

### 지도 및 탐색

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| MAP-001 | 홈 = 지도 화면 | 회원·비회원 | Must | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| MAP-002 | 상단 탭 전환 | 회원·비회원 | Must | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| MAP-003 | 탭 전환 시 카메라 유지 | 회원·비회원 | Must | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| MAP-004 | 시도 영역 표시 | 회원·비회원 | Must | API 직접 | API-PLC-001, API-MAP-001 |  | 엔드포인트 계약에 직접 반영 |
| MAP-005 | 시도별 게시글 수 표시 | 회원·비회원 | Must | API 직접 | API-MAP-001 |  | 엔드포인트 계약에 직접 반영 |
| MAP-006 | 시도 대표 이미지 선택 | 시스템 | Should | API 직접 | API-PLC-001, API-MAP-001 |  | 엔드포인트 계약에 직접 반영 |
| MAP-007 | 지역 선택 시 커뮤니티 이동 | 회원·비회원 | Must | API 직접 | API-MAP-001 |  | 엔드포인트 계약에 직접 반영 |
| MAP-008 | 히트맵 조회 | 회원·비회원 | Must | API 직접 | API-MAP-002 | JOB-006 | 엔드포인트 계약에 직접 반영 |
| MAP-009 | 줌 레벨별 격자 | 시스템 | Must | API 직접 | API-MAP-002 | JOB-006 | 엔드포인트 계약에 직접 반영 |
| MAP-010 | 밀집도 로그 정규화 | 시스템 | Must | API 직접 | API-MAP-002 | JOB-006 | 엔드포인트 계약에 직접 반영 |
| MAP-011 | 기간 선택 | 회원·비회원 | Must | API 직접 | API-MAP-002 | JOB-006 | 엔드포인트 계약에 직접 반영 |
| MAP-012 | 히트맵 집계 배치 | 시스템 | Must | API 직접 | API-MAP-002 | JOB-006, JOB-007 | 엔드포인트 계약에 직접 반영 |
| MAP-013 | 갱신 주기 서버 제어 | 시스템 | Must | API 직접 | API-MAP-002 | JOB-006 | 엔드포인트 계약에 직접 반영 |
| MAP-014 | 데이터 부족 폴백 | 시스템 | Must | API 직접 | API-MAP-002 | JOB-006 | 엔드포인트 계약에 직접 반영 |
| MAP-015 | 업로드 직후 즉시 반영 | 회원 | Must | API 직접 | API-MAP-002 | JOB-006 | 엔드포인트 계약에 직접 반영 |
| MAP-016 | 최근 게시 시각 제공 | 시스템 | Should | API 직접 | API-MAP-002 | JOB-006 | 엔드포인트 계약에 직접 반영 |
| MAP-017 | 격자 대표 장소 | 회원·비회원 | Should | API 직접 | API-MAP-002, API-MAP-004 |  | 엔드포인트 계약에 직접 반영 |
| MAP-018 | 응답 크기 제한 | 시스템 | Should | API 직접 | API-MAP-002 |  | 엔드포인트 계약에 직접 반영 |
| MAP-019 | 드래그 재조회 제어 | 시스템 | Should | API 직접 | API-MAP-002 |  | 엔드포인트 계약에 직접 반영 |
| MAP-020 | 사진 마커 표시 | 회원·비회원 | Must | API 직접 | API-MAP-003 |  | 엔드포인트 계약에 직접 반영 |
| MAP-021 | 마커 선택 시 상세 이동 | 회원·비회원 | Must | API 직접 | API-MAP-003 |  | 엔드포인트 계약에 직접 반영 |
| MAP-022 | 마커 후보 배열 제공 | 시스템 | Should | API 직접 | API-MAP-003 | JOB-007 | 엔드포인트 계약에 직접 반영 |
| MAP-023 | 확대 시 단일 사진 | 시스템 | Should | API 직접 | API-MAP-003 | JOB-007 | 엔드포인트 계약에 직접 반영 |
| MAP-024 | 작성자 중복 제거 | 시스템 | Should | API 직접 | API-MAP-003 | JOB-007 | 엔드포인트 계약에 직접 반영 |
| MAP-025 | 썸네일 사전 저장 | 시스템 | Should | API 직접 | API-MAP-003 | JOB-007 | 엔드포인트 계약에 직접 반영 |
| MAP-026 | 주변 장소 탐색 | 회원·비회원 | Must | API 직접 | API-PLC-004 |  | 엔드포인트 계약에 직접 반영 |
| MAP-027 | 반경 조정 | 회원·비회원 | Should | API 직접 | API-PLC-004 |  | 엔드포인트 계약에 직접 반영 |
| MAP-028 | 최근접 거리 안내 | 회원·비회원 | Should | API 직접 | API-PLC-004 |  | 엔드포인트 계약에 직접 반영 |
| MAP-029 | 인증 가능 여부 표시 | 회원 | Should | API 직접 | API-PLC-004 |  | 엔드포인트 계약에 직접 반영 |
| MAP-030 | 공간 인덱스 사용 | 시스템 | Must | API 직접 | API-PLC-004 |  | 엔드포인트 계약에 직접 반영 |

### 방문 기록

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| VST-001 | 게시글 방문 자동 기록 | 시스템 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| VST-002 | 일 1회 중복 방지 | 시스템 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| VST-003 | 내 방문 기록 조회 | 회원 | Should | API 직접 | API-VST-001 |  | 엔드포인트 계약에 직접 반영 |
| VST-004 | 방문 통계 조회 | 회원 | Should | API 직접 | API-VST-002 |  | 엔드포인트 계약에 직접 반영 |
| VST-005 | 장소 방문자 조회 | 회원·비회원 | Could | API 직접 | API-VST-004 |  | 엔드포인트 계약에 직접 반영 |
| VST-006 | 최근 본 장소 | 회원 | Could | API 직접 | API-USER-011 |  | 엔드포인트 계약에 직접 반영 |
| VST-007 | 방문 지도 화면 | 회원 | Must | API 직접 | API-VST-003 |  | 엔드포인트 계약에 직접 반영 |
| VST-008 | 시도 채색 | 회원 | Should | API 직접 | API-VST-002, API-VST-003 |  | 엔드포인트 계약에 직접 반영 |
| VST-009 | 방문 진행률 | 회원 | Should | API 직접 | API-VST-002, API-VST-003 |  | 엔드포인트 계약에 직접 반영 |
| VST-010 | 뱃지 병행 표시 | 회원 | Should | API 직접 | API-VST-003 |  | 엔드포인트 계약에 직접 반영 |

### 이벤트

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| EVT-001 | 지자체 행사 데이터 연동 | 시스템 | Must | 배치 | - | JOB-002 | 스케줄·비동기 작업으로 구현 |
| EVT-002 | 행사 기간 관리 | 시스템 | Must | API 직접 | API-EVT-001 | JOB-002 | 엔드포인트 계약에 직접 반영 |
| EVT-003 | 행사 동기화 배치 | 시스템 | Must | 배치 | - | JOB-002 | 스케줄·비동기 작업으로 구현 |
| EVT-004 | 행사 직접 등록 | 관리자 | Could | API 직접 | API-ADM-004, API-ADM-005 |  | 엔드포인트 계약에 직접 반영 |
| EVT-005 | 첫 화면 정렬 규칙 | 회원·비회원 | Must | API 직접 | API-EVT-001 |  | 엔드포인트 계약에 직접 반영 |
| EVT-006 | 종료 행사 기본 숨김 | 회원·비회원 | Should | API 직접 | API-EVT-001 |  | 엔드포인트 계약에 직접 반영 |
| EVT-007 | 시도별 카테고리 | 회원·비회원 | Must | API 직접 | API-EVT-001, API-EVT-006 |  | 엔드포인트 계약에 직접 반영 |
| EVT-008 | 신규 행사 강조 | 회원·비회원 | Should | API 직접 | API-EVT-006 |  | 엔드포인트 계약에 직접 반영 |
| EVT-009 | 열람 시 강조 해제 | 회원·비회원 | Could | API 직접 | API-EVT-006 |  | 서버는 newCount·createdAt만 제공, 읽음 해제는 앱 로컬 |
| EVT-010 | 메이슨리 레이아웃 | 회원·비회원 | Should | API 직접 | API-EVT-001 |  | 엔드포인트 계약에 직접 반영 |
| EVT-011 | 행사 상세 조회 | 회원·비회원 | Must | API 직접 | API-EVT-003 |  | 엔드포인트 계약에 직접 반영 |
| EVT-012 | 사진 올리기 진입 | 회원 | Must | API 직접 | API-EVT-003, API-EVT-005 |  | 엔드포인트 계약에 직접 반영 |
| EVT-013 | 지도 버튼 | 회원·비회원 | Should | API 직접 | API-EVT-003 |  | 엔드포인트 계약에 직접 반영 |
| EVT-014 | 참여 게시글 목록 | 회원·비회원 | Must | API 직접 | API-EVT-004 |  | 엔드포인트 계약에 직접 반영 |
| EVT-015 | 주변 행사 조회 | 회원·비회원 | Should | API 직접 | API-EVT-002 |  | 엔드포인트 계약에 직접 반영 |
| EVT-016 | 업로드 장소 프리필 | 회원 | Must | API 직접 | API-PST-003, API-EVT-005 |  | 엔드포인트 계약에 직접 반영 |
| EVT-017 | 고정 태그 부여 | 시스템 | Must | API 직접 | API-PST-003, API-CMU-011, API-EVT-005 |  | 엔드포인트 계약에 직접 반영 |
| EVT-018 | 고정 태그 수정 불가 | 시스템 | Must | API 직접 | API-PST-003, API-CMU-011, API-EVT-005 |  | 엔드포인트 계약에 직접 반영 |
| EVT-019 | 고정 태그 서버 재주입 | 시스템 | Must | API 직접 | API-PST-003, API-CMU-011, API-EVT-005 |  | 엔드포인트 계약에 직접 반영 |
| EVT-020 | 자유 태그 8개 제한 | 회원 | Must | API 직접 | API-PST-003, API-CMU-011, API-EVT-005 |  | 엔드포인트 계약에 직접 반영 |
| EVT-021 | 참여 판정 | 시스템 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| EVT-022 | 게시 후 상세 이동 | 회원 | Must | API 직접 | API-PST-003 |  | 엔드포인트 계약에 직접 반영 |
| EVT-023 | 반경 밖 뱃지 미지급 | 시스템 | Must | API 직접 | API-PST-003, API-ADM-007 |  | 엔드포인트 계약에 직접 반영 |

### 수집형 뱃지

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| BDG-001 | 행사 뱃지 | 회원 | Must | API 직접 | API-BDG-001 | JOB-004 | 엔드포인트 계약에 직접 반영 |
| BDG-002 | 지역 뱃지 | 회원 | Should | API 직접 | API-BDG-001 | JOB-004 | 엔드포인트 계약에 직접 반영 |
| BDG-003 | 완주 뱃지 | 회원 | Should | API 직접 | API-BDG-001 | JOB-004 | 엔드포인트 계약에 직접 반영 |
| BDG-004 | 기록 뱃지 | 회원 | Could | API 직접 | API-BDG-001 | JOB-004 | 엔드포인트 계약에 직접 반영 |
| BDG-005 | 비동기 지급 | 시스템 | Must | API 직접 | API-PST-003 | JOB-004 | 엔드포인트 계약에 직접 반영 |
| BDG-006 | 중복 지급 방지 | 시스템 | Must | API 직접 | API-PST-003 | JOB-004 | 엔드포인트 계약에 직접 반영 |
| BDG-007 | 데이터 기반 조건 정의 | 시스템 | Must | 배치 | - | JOB-004 | 스케줄·비동기 작업으로 구현 |
| BDG-008 | 획득 알림 | 회원 | Could | 배치 | - | JOB-005 | 스케줄·비동기 작업으로 구현 |
| BDG-009 | 뱃지 수집함 화면 | 회원·비회원 | Must | API 직접 | API-BDG-001 |  | 엔드포인트 계약에 직접 반영 |
| BDG-010 | 미획득 표시 | 회원·비회원 | Must | API 직접 | API-BDG-001 |  | 엔드포인트 계약에 직접 반영 |
| BDG-011 | 카테고리 구분 | 회원·비회원 | Should | API 직접 | API-BDG-001 |  | 엔드포인트 계약에 직접 반영 |
| BDG-012 | 타인 수집함 조회 | 회원·비회원 | Could | API 직접 | API-BDG-001 |  | 엔드포인트 계약에 직접 반영 |
| BDG-013 | 뱃지 상세 | 회원·비회원 | Could | API 직접 | API-BDG-002 |  | 엔드포인트 계약에 직접 반영 |
| BDG-014 | 탈퇴 시 뱃지 삭제 | 시스템 | Must | API 직접 | API-USER-009 |  | 엔드포인트 계약에 직접 반영 |

### 알림

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| NTF-001 | 좋아요 알림 | 회원 | Could | 배치 | - | JOB-005 | 스케줄·비동기 작업으로 구현 |
| NTF-002 | 팔로우 알림 | 회원 | Could | 배치 | - | JOB-005 | 스케줄·비동기 작업으로 구현 |
| NTF-003 | 뱃지 획득 알림 | 회원 | Could | 배치 | - | JOB-005 | 스케줄·비동기 작업으로 구현 |
| NTF-004 | 시스템 공지 알림 | 관리자 | Could | API 직접 | API-ADM-012 | JOB-005 | 엔드포인트 계약에 직접 반영 |
| NTF-005 | 커밋 후 발송 | 시스템 | Must | API 직접 | API-ADM-012 | JOB-005 | 엔드포인트 계약에 직접 반영 |
| NTF-006 | 비동기 처리 | 시스템 | Must | API 직접 | API-ADM-012 | JOB-005 | 엔드포인트 계약에 직접 반영 |
| NTF-007 | 자기 자신 제외 | 시스템 | Must | API 직접 | API-ADM-012 | JOB-005 | 엔드포인트 계약에 직접 반영 |
| NTF-008 | 중복 알림 방지 | 시스템 | Should | API 직접 | API-ADM-012 | JOB-005 | 엔드포인트 계약에 직접 반영 |
| NTF-009 | 다국어 문구 조립 | 시스템 | Must | API 직접 | API-NTF-001, API-ADM-012 | JOB-005 | 엔드포인트 계약에 직접 반영 |
| NTF-010 | 무효 토큰 정리 | 시스템 | Should | API 직접 | API-USER-003, API-ADM-012 | JOB-005 | 엔드포인트 계약에 직접 반영 |
| NTF-011 | 알림 목록 조회 | 회원 | Could | API 직접 | API-NTF-001 |  | 엔드포인트 계약에 직접 반영 |
| NTF-012 | 안읽은 알림 수 조회 | 회원 | Could | API 직접 | API-NTF-002 |  | 엔드포인트 계약에 직접 반영 |
| NTF-013 | 알림 읽음 처리 | 회원 | Could | API 직접 | API-NTF-003, API-NTF-004 |  | 엔드포인트 계약에 직접 반영 |
| NTF-014 | 오래된 알림 정리 | 시스템 | Could | 배치 | - | JOB-012 | 스케줄·비동기 작업으로 구현 |

### 랭킹 및 추천

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| RNK-001 | 랭킹 점수 산정 | 시스템 | Must | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-002 | 지역별 랭킹 조회 | 회원·비회원 | Must | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-003 | 전국 랭킹 조회 | 회원·비회원 | Must | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-004 | 기간별 랭킹 | 회원·비회원 | Should | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-005 | 테마별 랭킹 | 회원·비회원 | Should | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-006 | 사용자 등록 장소 랭킹 | 회원·비회원 | Should | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-007 | 결정적 정렬 | 시스템 | Must | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-008 | 랭킹 집계 배치 | 시스템 | Must | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-009 | 순위 변동 표시 | 회원·비회원 | Should | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-010 | 랭킹 진입 기준 | 시스템 | Should | API 직접 | API-RNK-001 | JOB-008 | 엔드포인트 계약에 직접 반영 |
| RNK-011 | 추천 장소 조회 | 회원·비회원 | Should | API 직접 | API-RNK-002 |  | 엔드포인트 계약에 직접 반영 |
| RNK-012 | 추천 사유 제공 | 시스템 | Should | API 직접 | API-RNK-002 |  | 엔드포인트 계약에 직접 반영 |
| RNK-013 | 데이터 부족 대체 | 시스템 | Must | API 직접 | API-RNK-002 |  | 엔드포인트 계약에 직접 반영 |

### 검색

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| SCH-001 | 통합 검색 | 회원·비회원 | Must | API 직접 | API-SCH-001 |  | 엔드포인트 계약에 직접 반영 |
| SCH-002 | 검색 초기 화면 | 회원·비회원 | Should | API 직접 | API-SCH-002, API-SCH-003 |  | 엔드포인트 계약에 직접 반영 |
| SCH-003 | 타입별 상위 노출 | 회원·비회원 | Should | API 직접 | API-SCH-001 |  | 엔드포인트 계약에 직접 반영 |
| SCH-004 | 장소명 검색 | 회원·비회원 | Must | API 직접 | API-SCH-001 |  | 엔드포인트 계약에 직접 반영 |
| SCH-005 | 게시글 검색 | 회원·비회원 | Should | API 직접 | API-SCH-001 |  | 엔드포인트 계약에 직접 반영 |
| SCH-006 | 사용자 검색 | 회원·비회원 | Should | API 직접 | API-SCH-001 |  | 엔드포인트 계약에 직접 반영 |
| SCH-007 | 태그 검색 | 회원·비회원 | Should | API 직접 | API-CMU-013, API-SCH-001 |  | 엔드포인트 계약에 직접 반영 |
| SCH-008 | 지역 필터 전환 | 회원·비회원 | Should | API 직접 | API-SCH-001 |  | SearchResult.matchedRegion으로 필터 전환 |
| SCH-009 | 홈 진입 시 필터 프리필 | 회원·비회원 | Must | API 직접 | API-SCH-001 |  | 엔드포인트 계약에 직접 반영 |
| SCH-010 | 인기 검색어 | 회원·비회원 | Could | API 직접 | API-SCH-002 |  | 최근 7일 검색 로그 집계, Redis 10분 캐시, 로그 30일 보존 |
| SCH-011 | 최근 검색어 | 회원 | Could | API 직접 | API-SCH-003, API-SCH-004 |  | Redis 사용자별 최대 20개, TTL 30일; 동일 검색어는 최신 순서로 갱신 |

### 공통 · 운영

| 요구사항 ID | 기능 이름 | 사용자 유형 | 중요도 | 구현 주체 | API ID | JOB ID | 비고 |
|---|---|---|---|---|---|---|---|
| SYS-001 | 공통 응답 형식 | 시스템 | Must | API 내부 | - | - | 공통 미들웨어·도메인 서비스·저장 규칙 |
| SYS-002 | 에러 코드 체계 | 시스템 | Must | API 내부 | - | - | 공통 미들웨어·도메인 서비스·저장 규칙 |
| SYS-003 | 페이징 규약 | 시스템 | Must | API 내부 | - | - | 공통 미들웨어·도메인 서비스·저장 규칙 |
| SYS-004 | 커서 페이징 원칙 | 시스템 | Must | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| SYS-005 | 타임존 고정 | 시스템 | Must | API 내부 | - | - | 공통 미들웨어·도메인 서비스·저장 규칙 |
| SYS-006 | 논리 삭제 | 시스템 | Must | API 직접 | API-PST-008 |  | 엔드포인트 계약에 직접 반영 |
| SYS-007 | 카운터 보정 배치 | 시스템 | Should | 배치 | - | JOB-009 | 스케줄·비동기 작업으로 구현 |
| SYS-008 | 표시 용어 적용 | 시스템 | Must | 클라이언트 | - | - | 앱 UI/상태 관리 규칙 |
| SYS-009 | 식별자 분리 원칙 | 시스템 | Must | API 내부 | - | - | 공통 미들웨어·도메인 서비스·저장 규칙 |
| SYS-010 | UI 다국어 지원 | 회원·비회원 | Should | API 직접 | API-PST-006 |  | 엔드포인트 계약에 직접 반영 |
| SYS-011 | 텍스트 확장 대응 | 시스템 | Should | 클라이언트 | - | - | Flutter 후속 작업. 이번 백엔드 범위 제외 |
| SYS-012 | 관광정보 다국어 연동 | 시스템 | Should | API 직접 | API-PLC-005 | - | place_details (place_id, language_code) 단위 지연 적재 |
| SYS-013 | API 문서 제공 | 관리자 | Must | API 내부 | - | - | 공통 미들웨어·도메인 서비스·저장 규칙 |
| SYS-014 | CORS 설정 | 시스템 | Must | API 내부 | - | - | 공통 미들웨어·도메인 서비스·저장 규칙 |
| SYS-015 | 수동 배치 실행 | 관리자 | Should | API 직접 | API-ADM-001, API-ADM-002 |  | 엔드포인트 계약에 직접 반영 |
| SYS-016 | 요청 추적 로그 | 시스템 | Should | API 직접 | API-ADM-002 |  | 엔드포인트 계약에 직접 반영 |
| SYS-017 | 신고 검토 | 관리자 | Should | API 직접 | API-ADM-009, API-ADM-010 |  | 엔드포인트 계약에 직접 반영 |
| SYS-018 | 목록 응답 경량화 | 시스템 | Must | API 직접 | API-PLC-003, API-PST-004 |  | 엔드포인트 계약에 직접 반영 |
| SYS-019 | 조회 캐시 | 시스템 | Should | API 내부 | API-PLC-001, API-PLC-002, API-PLC-005 | - | 시도·시군구 24시간, 장소 상세 10분, Redis 장애 시 DB 폴백 |
| SYS-020 | 업로드 주소 만료 | 시스템 | Must | API 직접 | API-PST-001 |  | 엔드포인트 계약에 직접 반영 |
| SYS-021 | 공개 이미지 EXIF 제거 | 시스템 | Must | 배치 | - | JOB-003 | 스케줄·비동기 작업으로 구현 |


---

원본 스프레드시트: [`specs/snaphere-requirements-spec-v1.1.7.xlsx`](specs/snaphere-requirements-spec-v1.1.7.xlsx) · [`specs/snaphere-api-spec-v1.1.7.xlsx`](specs/snaphere-api-spec-v1.1.7.xlsx)
변경 이력: [`08-spec-changelog.md`](08-spec-changelog.md)
