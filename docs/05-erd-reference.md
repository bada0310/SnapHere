# SnapHere ERD 참조

> 기준: 사용자 제공 ERD 정본 · 2026-09-05
>
> 대상 DB: Percona PostgreSQL 17.10.2 + PostGIS 3.6.2 (커스텀 이미지)
>
> 구성: 28개 테이블 · 22개 enum · DBML 명시 관계 42개
>
> 실행 가능한 상세 타입·제약은 [12-db-schema.dbml](12-db-schema.dbml)과 [독립 초기화 SQL](../backend/src/main/resources/db/standalone/01_snaphere_schema.sql)을 따른다.

## 1. 정본 판정

- 사용자 제공 ERD에 실제 선언된 테이블은 28개다.
- 기존 문서에만 있던 `tier_logs`는 최신 정본에서 제외한다.
- 구현 보조 테이블 `heatmap_refresh_state`도 정본 ERD에서 제외한다.
- 정본은 `bigint` 사용자 키와 PostgreSQL native enum을 사용한다.
- 이 문서는 데이터 계약을 설명하며 현재 Flyway 구현을 자동 변경하지 않는다.

## 2. enum

| enum | 값 |
|---|---|
| `provider` | `GOOGLE` |
| `user_role` | `USER`, `ADMIN` |
| `user_status` | `ACTIVE`, `SUSPENDED`, `WITHDRAWN` |
| `content_action` | `KEEP_ANONYMIZED`, `DELETE_ALL` |
| `device_platform` | `ANDROID`, `IOS` |
| `place_type` | `OFFICIAL`, `USER` |
| `post_tier` | `HIGH`, `MEDIUM`, `LOW` |
| `post_source` | `CAMERA`, `ALBUM` |
| `post_status` | `ACTIVE`, `BLINDED`, `DELETED` |
| `comment_status` | `ACTIVE`, `DELETED` |
| `like_target` | `POST`, `COMMENT` |
| `bookmark_target` | `POST`, `PLACE` |
| `badge_type` | `EVENT`, `AREA`, `COMPLETION`, `RECORD` |
| `event_source` | `TOURAPI`, `MANUAL` |
| `heatmap_period` | `LAST_1H`, `LAST_24H`, `WEEKLY`, `MONTHLY` |
| `post_popularity_period` | `HOURS_24`, `WEEKLY`, `MONTHLY`, `ALL` |
| `ranking_period` | `DAILY`, `WEEKLY`, `MONTHLY`, `ALL` |
| `notification_type` | `POST_LIKE`, `FOLLOW`, `BADGE_EARNED`, `SYSTEM` |
| `notification_target` | `POST`, `USER`, `BADGE`, `NONE` |
| `report_target` | `POST`, `COMMENT`, `PLACE`, `USER` |
| `report_status` | `PENDING`, `RESOLVED`, `REJECTED` |
| `sync_result` | `SUCCESS`, `FAIL`, `PARTIAL` |

## 3. 테이블 사전

표의 컬럼 목록은 정본 컬럼을 빠짐없이 나열한다. `PK`와 `Unique`는 별도 표기한다.

### 계정

| 테이블 | PK | FK | Unique | 나머지 컬럼 |
|---|---|---|---|---|
| `users` | `user_id` | - | `(provider, provider_user_id)` | `provider`, `provider_user_id`, `email`, `nickname`, `profile_image_url`, `bio`, `locale`, `role`, `status`, `upload_blocked_until`, `push_like_enabled`, `push_follow_enabled`, `push_badge_enabled`, `badge_count`, `follower_count`, `following_count`, `post_count`, `withdrawn_at`, `purge_scheduled_at`, `restore_key`, `created_at`, `updated_at` |
| `user_devices` | `device_id` | `user_id→users` | `(user_id, fcm_token)` | `fcm_token`, `platform`, `app_version`, `updated_at` |
| `refresh_tokens` | `token_hash` | `user_id→users`, `device_id→user_devices` | PK | `expires_at`, `revoked_at` |
| `account_deletion_logs` | `log_id` | `user_id→users` | - | `reason`, `content_action`, `deleted_at`, `purged_at` |

### 소셜

| 테이블 | PK | FK | Unique | 나머지 컬럼 |
|---|---|---|---|---|
| `follows` | `(follower_id, following_id)` | 두 컬럼 모두 `users` | PK | `created_at` |

### 장소

| 테이블 | PK | FK | Unique | 나머지 컬럼 |
|---|---|---|---|---|
| `regions` | `area_code` | - | PK | `name_ko`, `name_en`, `representative_image_url`, `default_event_verify_radius_m` |
| `sigungu` | `(area_code, sigungu_code)` | `area_code→regions` | PK | `name_ko`, `name_en` |
| `places` | `place_id` | `area_code→regions`, `created_by→users`, `(area_code, sigungu_code)→sigungu` | `content_id` | `place_type`, `content_type_id`, `title`, `addr1`, `geom`, `verify_radius_m`, `sigungu_code`, `has_coordinate`, `post_count`, `visit_count`, `view_count`, `created_at` |
| `place_details` | `(place_id, language_code)` | `place_id→places` | PK | `overview`, `tel`, `homepage`, `use_time`, `rest_date` |

### 게시글

| 테이블 | PK | FK | Unique | 나머지 컬럼 |
|---|---|---|---|---|
| `posts` | `post_id` | `user_id→users`, `place_id→places`, `event_id→events`, `area_code→regions` | - | `content`, `original_language_code`, `tier`, `lat`, `lng`, `taken_at`, `source`, `like_count`, `comment_count`, `view_count`, `status`, `created_at`, `updated_at`, `deleted_at` |
| `post_images` | `post_image_id` | `post_id→posts` | `(post_id, sort_order)` | `image_key`, `thumbnail_url`, `aspect_ratio`, `sort_order` |

`post_images.sort_order`는 0~3이며 0번이 대표 사진이다. 최신 정본에는 `image_hash`, `created_at`, `tier_logs`가 없다.

### 커뮤니티

| 테이블 | PK | FK | Unique | 나머지 컬럼 |
|---|---|---|---|---|
| `comments` | `comment_id` | `post_id→posts`, `user_id→users`, `parent_id→comments` | - | `content`, `like_count`, `status`, `created_at` |
| `likes` | `(user_id, target_type, target_id)` | `user_id→users`; 대상은 논리 참조 | PK | `created_at` |
| `bookmarks` | `(user_id, target_type, target_id)` | `user_id→users`; 대상은 논리 참조 | PK | `created_at` |
| `tags` | `tag_id` | - | `normalized_name` | `name`, `theme_code`, `usage_count` |
| `post_tags` | `(post_id, tag_id)` | `post_id→posts`, `tag_id→tags` | PK | `is_locked`, `is_suggested` |

### 이벤트·뱃지

| 테이블 | PK | FK | Unique | 나머지 컬럼 |
|---|---|---|---|---|
| `events` | `event_id` | `area_code→regions`, `place_id→places` | `content_id` | `title`, `overview`, `start_date`, `end_date`, `thumbnail_url`, `fixed_tags`, `participant_count`, `source`, `verify_radius_m` |
| `badges` | `badge_id` | `event_id→events`, `area_code→regions` | `code`, `event_id` | `type`, `name_ko`, `name_en`, `description`, `icon_url`, `condition_json`, `is_obtainable`, `available_from`, `available_to` |
| `user_badges` | `(user_id, badge_id)` | `user_id→users`, `badge_id→badges`, `source_post_id→posts` | PK | `earned_at` |

이벤트와 뱃지의 연결은 `badges.event_id` 한 방향만 사용한다. `events.badge_id`는 없다.

### 방문·집계

| 테이블 | PK | FK | Unique | 나머지 컬럼 |
|---|---|---|---|---|
| `visits` | `visit_id` | `user_id→users`, `place_id→places`, `post_id→posts` | `(user_id, place_id, visited_on)` | `visited_on` |
| `heatmap_cells` | `cell_id` | `top_place_id→places` | `(grid_level, period, lat, lng)` | `grid_level`, `lat`, `lng`, `period`, `post_count`, `visit_count`, `user_count`, `sample_post_ids`, `last_posted_at`, `calculated_at` |
| `post_rankings` | `(post_id, period)` | `post_id→posts` | PK | `score`, `rank_no`, `calculated_at` |
| `region_stats` | `(area_code, period)` | `area_code→regions` | PK | `post_count`, `contributor_count` |
| `place_rankings` | `ranking_id` | `place_id→places`, `area_code→regions` | `(place_id, period, theme)` | `period`, `theme`, `score`, `rank_no`, `previous_rank`, `calculated_at` |

최신 정본의 `heatmap_cells`는 숫자형 중심 좌표와 JSON `sample_post_ids`를 사용한다. `lat_index`, `lng_index`, `sample_thumbnail_urls`는 없다. `region_stats`에는 `representative_post_id`, `calculated_at`이 없다.

### 알림·운영

| 테이블 | PK | FK | Unique | 나머지 컬럼 |
|---|---|---|---|---|
| `notifications` | `notification_id` | `recipient_id→users`, `actor_id→users`; 대상은 논리 참조 | `(recipient_id, actor_id, type, target_type, target_id)` | `type`, `target_type`, `target_id`, `message_key`, `message_params`, `is_read`, `created_at` |
| `reports` | `report_id` | `reporter_id→users`; 대상은 논리 참조 | `(reporter_id, target_type, target_id)` | `reason`, `status`, `created_at` |
| `sync_logs` | `sync_id` | `area_code→regions` | - | `job_type`, `content_type_id`, `result`, `count`, `message`, `created_at` |
| `search_logs` | `log_id` | `area_code→regions` | - | `keyword`, `searched_at` |

최신 정본의 `reports`에는 `detail`, `action`, `reviewed_at`이 없고 `search_logs`에는 `user_id`가 없다.

## 4. 명시 관계 42개

아래 목록은 [12-db-schema.dbml](12-db-schema.dbml)의 `Ref:` 42개와 1:1로 대응한다.

| 번호 | 자식 컬럼 | 부모 컬럼 | 비고 |
|---:|---|---|---|
| 1 | `user_devices.user_id` | `users.user_id` | 기기 소유자 |
| 2 | `refresh_tokens.user_id` | `users.user_id` | 토큰 소유자 |
| 3 | `refresh_tokens.device_id` | `user_devices.device_id` | 기기 세션 |
| 4 | `account_deletion_logs.user_id` | `users.user_id` | 탈퇴 감사 |
| 5 | `follows.follower_id` | `users.user_id` | 팔로우 주체 |
| 6 | `follows.following_id` | `users.user_id` | 팔로우 대상 |
| 7 | `sigungu.area_code` | `regions.area_code` | 시도 소속 |
| 8 | `places.area_code` | `regions.area_code` | 장소 지역 |
| 9 | `places.created_by` | `users.user_id` | 사용자 장소 생성자 |
| 10 | `place_details.place_id` | `places.place_id` | 다국어 상세 |
| 11 | `posts.user_id` | `users.user_id` | 작성자 |
| 12 | `posts.place_id` | `places.place_id` | 게시 장소 |
| 13 | `posts.event_id` | `events.event_id` | 행사 참여 |
| 14 | `posts.area_code` | `regions.area_code` | 게시 지역 |
| 15 | `post_images.post_id` | `posts.post_id` | 게시글 사진 |
| 16 | `comments.post_id` | `posts.post_id` | 댓글 게시글 |
| 17 | `comments.user_id` | `users.user_id` | 댓글 작성자 |
| 18 | `comments.parent_id` | `comments.comment_id` | 대댓글 |
| 19 | `likes.user_id` | `users.user_id` | 좋아요 주체 |
| 20 | `bookmarks.user_id` | `users.user_id` | 북마크 주체 |
| 21 | `post_tags.post_id` | `posts.post_id` | 게시글 태그 |
| 22 | `post_tags.tag_id` | `tags.tag_id` | 태그 사전 |
| 23 | `events.area_code` | `regions.area_code` | 행사 지역 |
| 24 | `events.place_id` | `places.place_id` | 행사 장소 |
| 25 | `badges.event_id` | `events.event_id` | 행사 뱃지 |
| 26 | `badges.area_code` | `regions.area_code` | 지역 뱃지 |
| 27 | `user_badges.user_id` | `users.user_id` | 획득 사용자 |
| 28 | `user_badges.badge_id` | `badges.badge_id` | 획득 뱃지 |
| 29 | `user_badges.source_post_id` | `posts.post_id` | 게시글 삭제 시 `SET NULL` |
| 30 | `post_rankings.post_id` | `posts.post_id` | 게시글 순위 |
| 31 | `visits.user_id` | `users.user_id` | 방문 사용자 |
| 32 | `visits.place_id` | `places.place_id` | 방문 장소 |
| 33 | `visits.post_id` | `posts.post_id` | 게시글 삭제 시 `SET NULL` |
| 34 | `heatmap_cells.top_place_id` | `places.place_id` | 대표 장소 |
| 35 | `region_stats.area_code` | `regions.area_code` | 지역 집계 |
| 36 | `place_rankings.place_id` | `places.place_id` | 장소 순위 |
| 37 | `place_rankings.area_code` | `regions.area_code` | 지역별 순위 |
| 38 | `notifications.recipient_id` | `users.user_id` | 알림 수신자 |
| 39 | `notifications.actor_id` | `users.user_id` | 알림 행위자 |
| 40 | `reports.reporter_id` | `users.user_id` | 신고자 |
| 41 | `sync_logs.area_code` | `regions.area_code` | 동기화 지역 |
| 42 | `search_logs.area_code` | `regions.area_code` | 검색 지역 |

### DBML 선을 생략한 참조

- `places.(area_code, sigungu_code) → sigungu.(area_code, sigungu_code)`는 복합 참조다. 독립 SQL에는 실제 복합 FK가 있으며 DBML에서는 선을 생략한다.
- `likes.target_type + target_id`, `bookmarks.target_type + target_id`, `reports.target_type + target_id`, `notifications.target_type + target_id`는 다형 논리 참조다.
- `heatmap_cells.sample_post_ids`는 게시글 ID JSON 배열이어서 FK를 걸지 않는다.

## 5. 주요 인덱스

| 인덱스 | 대상 | 용도 |
|---|---|---|
| `gix_places_geom` | `places.geom` | GIST 반경 검색 |
| `gin_places_title` | `places.title`, `places.addr1` | `pg_trgm` 한글 부분어 검색 |
| `idx_posts_area_created` | `posts(area_code, created_at)` | 활성 게시글 지역 피드 |
| `idx_comments_post` | `comments(post_id, created_at)` | 활성 댓글 목록 |
| `idx_notifications_unread` | `notifications(recipient_id, is_read)` | 안 읽은 알림 |
| `idx_post_rankings_lookup` | `post_rankings(period, rank_no)` | 기간별 인기 게시글 |
| `idx_rankings_lookup` | `place_rankings(area_code, period, theme, rank_no)` | 지역·기간·테마별 장소 순위 |

## 6. 정본과 현재 구현의 차이

이 절은 정본을 바꾸는 내용이 아니라 후속 마이그레이션 시 확인할 차이를 기록한다.

| 항목 | 정본 ERD | 현재 구현에서 관찰된 형태 |
|---|---|---|
| 사용자 PK | `users.user_id bigint` | `users.id uuid` |
| enum 저장 | PostgreSQL native enum | 문자열과 CHECK 중심 |
| 장소 좌표 | `geom geography(Point,4326)` 직접 저장 | 위·경도와 생성 좌표 혼용 |
| 게시글 숨김 상태 | `BLINDED` | 일부 구현은 `HIDDEN` |
| 사진 순서 | 0~3 | 일부 구현은 1~4 |
| 등급 감사 | 별도 테이블 없음 | `tier_logs` 존재 가능 |
| 히트맵 보조 상태 | 정본에 없음 | `heatmap_refresh_state` 존재 가능 |
| 운영자 추천 장소 | 정본의 미결정 제안 | 애플리케이션 V19에 `places.is_curated` 추가 |
| 장소 랭킹 집계 차원 | `(place_id, period, theme)` 단위 | 애플리케이션 V19는 전국·지역 및 전체·공식·사용자 순위를 미리 저장하도록 `scope`, `place_type` 추가 |

따라서 이 문서 변경만으로 기존 Flyway 마이그레이션을 삭제하거나 재작성해서는 안 된다.

---

결정 기록: [`07-decision-log.md`](07-decision-log.md)의 `DEC-20260905-011`

변경 이력: [`08-spec-changelog.md`](08-spec-changelog.md)
