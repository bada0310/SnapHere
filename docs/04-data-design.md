# SnapHere 데이터 설계

> 상태: 사용자 제공 ERD 정본 · 2026-09-05
>
> 대상 DB: Percona PostgreSQL 17.10.2 + PostGIS 3.5.7
>
> 규모: 28개 테이블 · 22개 enum · DBML에 명시한 관계 42개
>
> 상세 컬럼: [05-erd-reference.md](05-erd-reference.md) · dbdiagram.io 원본: [12-db-schema.dbml](12-db-schema.dbml)

## 1. 정본 범위

이 문서는 사용자가 제공한 ERD를 최신 데이터 설계로 삼는다. 제공 ERD 주석의 “29개” 표기는 실제 `Table` 선언 수와 달랐으며, 최신 정본은 아래 28개 테이블이다.

기존 문서에 있던 `tier_logs`는 최신 ERD에서 의도적으로 제외됐다. `heatmap_refresh_state`는 현재 구현의 보조 테이블일 뿐 정본 데이터 모델에는 포함하지 않는다.

이번 정합화는 문서와 독립 실행 SQL의 기준을 통일한 것이다. 현재 Spring Boot Flyway 스키마는 UUID 사용자 키와 구현 보조 컬럼·테이블을 사용하므로 자동으로 변경하지 않는다. 애플리케이션 스키마를 정본에 맞추는 일은 별도 마이그레이션 결정이 필요하다.

## 2. 공통 규칙

- 모든 시각은 `timestamptz`로 저장하고 DB에는 UTC로 보관한다. 서버에서 지역 시각을 해석할 때는 `Asia/Seoul`을 사용한다.
- 장소 좌표는 `geography(Point,4326)`로 저장한다. 거리 검색은 `ST_DWithin`과 GIST 인덱스를 사용한다.
- 한글 부분어 검색은 `pg_trgm` GIN 인덱스를 사용한다.
- 논리 삭제 대상의 목록 조회에는 `status = 'ACTIVE'` 부분 인덱스를 사용한다.
- `*_count`는 조회 성능을 위한 비정규화 카운터다. 매일 보정 배치가 원본 행과 맞춰야 한다.
- 중복 방지 작업은 복합 PK·UNIQUE와 `INSERT ... ON CONFLICT`를 사용해 멱등성을 보장한다.
- 물리 삭제는 보존 정책에 따른 배치에서만 수행한다.
- `likes`, `bookmarks`, `reports`, `notifications`의 `target_type + target_id`는 다형 참조라 DB FK를 걸지 않고 애플리케이션에서 대상 존재를 검증한다.

필수 확장은 다음과 같다.

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

## 3. 테이블 구성

| 영역 | 테이블 | 수 |
|---|---|---:|
| 계정 | `users`, `user_devices`, `refresh_tokens`, `account_deletion_logs` | 4 |
| 소셜 | `follows` | 1 |
| 장소 | `regions`, `sigungu`, `places`, `place_details` | 4 |
| 게시글 | `posts`, `post_images` | 2 |
| 커뮤니티 | `comments`, `likes`, `bookmarks`, `tags`, `post_tags` | 5 |
| 이벤트·뱃지 | `events`, `badges`, `user_badges` | 3 |
| 방문·집계 | `visits`, `post_rankings`, `heatmap_cells`, `region_stats`, `place_rankings` | 5 |
| 알림·운영 | `notifications`, `reports`, `sync_logs`, `search_logs` | 4 |
| 합계 |  | **28** |

## 4. 핵심 설계

### 계정

- 사용자는 Google OAuth만 사용한다. `role`은 회원 등급이 아니라 `USER`·`ADMIN` 권한 구분이다.
- 탈퇴 시 `provider_user_id`와 이메일을 파기하고, `restore_key`에는 복구 요청을 대조하기 위한 SHA-256 해시만 둔다.
- 리프레시 토큰 원문은 저장하지 않고 `token_hash`만 저장한다. 토큰은 사용 시 회전시키며 `revoked_at`으로 폐기를 기록한다.
- 팔로우는 `(follower_id, following_id)` 복합 PK로 중복을 막는다.

### 장소

- `regions.area_code`는 TourAPI의 비연속 시도 코드를 그대로 PK로 사용한다.
- 시군구는 `(area_code, sigungu_code)` 복합 PK를 사용하며, `places`가 두 컬럼으로 참조한다.
- 관광지와 사용자 등록 장소는 `places` 한 테이블에 저장한다. `place_type`으로 `OFFICIAL`·`USER`를 구분한다.
- `geom`은 좌표가 없으면 `NULL`을 허용한다. `POINT(0,0)` 같은 가짜 좌표를 넣지 않는다.
- `has_coordinate`는 `geom IS NOT NULL`과 같은 의미의 조회 편의 플래그다. `false`인 장소는 주변 탐색·히트맵·등급 판정에서 제외한다.
- `visit_count`는 실제 방문 누적 수이고, `view_count`는 장소 상세 화면을 연 횟수다.

### 게시글과 사진

- 게시글에는 장소가 반드시 연결되며, `area_code`는 클라이언트 입력이 아니라 장소에서 산출한다.
- 신뢰 등급은 `HIGH`, `MEDIUM`, `LOW`이며 서버가 판정한다.
- 게시 후 장소·좌표·등급은 수정하지 않고 캡션·태그·사진 순서만 수정한다.
- 사진은 최대 4장이고 `sort_order`는 0부터 3까지다. 0번 사진이 대표 사진이다.
- 최신 정본에는 `post_images.image_hash`와 `tier_logs`가 없다. 중복 이미지 확인이 필요하면 `posts`를 통해 사용자 범위를 확인하며, 등급 판정 감사 로그는 별도 결정 전까지 정본 DB 범위가 아니다.

### 커뮤니티

- 댓글은 대댓글 깊이 1단계까지만 허용한다. 자식이 있는 댓글 삭제 시 부모 표시만 삭제 상태로 바꾸고 자식은 남긴다.
- 좋아요와 북마크는 사용자·대상 종류·대상 ID의 복합 PK로 중복을 막는다.
- 태그는 표시용 `name`과 검색·중복 방지용 `normalized_name`을 분리한다.
- 행사 고정 태그는 `post_tags.is_locked`, 추천 채택 태그는 `is_suggested`로 구분한다.

### 이벤트와 뱃지

- 이벤트 인증 반경은 이벤트 값, 지역 기본값, 2,000m 순서로 적용한다.
- 이벤트와 지급 뱃지의 연결은 `badges.event_id` 한 방향만 사용한다.
- 뱃지 조건은 `condition_json`에 저장하며 허용한 조건 유형은 `EVENT_PARTICIPATE`, `AREA_POST_COUNT`, `VISITED_AREA_COUNT`, `TOTAL_POST_COUNT`다.
- `(user_id, badge_id)` 복합 PK로 중복 지급을 막는다. 근거 게시글이 삭제돼도 획득 사실은 남고 `source_post_id`만 `NULL`이 된다.

### 방문과 집계

- 방문은 `(user_id, place_id, visited_on)` UNIQUE로 같은 날 같은 장소를 한 번만 기록한다.
- 게시글이 삭제돼도 방문 사실은 남고 `visits.post_id`만 `NULL`이 된다.
- `heatmap_cells`는 줌 단계 `0~3`과 기간별로 미리 집계한다. 기간은 `LAST_1H`, `LAST_24H`, `WEEKLY`, `MONTHLY`다.
- `sample_post_ids`는 마커 후보 게시글을 최대 10개 담는 JSON 배열이다.
- 인기 게시글은 `post_rankings`, 장소 랭킹은 `place_rankings`에 미리 계산해 조회 시 집계하지 않는다.
- 장소 랭킹 점수는 게시글 신뢰 등급별 가중치 `3.0 / 1.8 / 0.5`를 사용한다. 동점 순서를 고정할 보조 정렬 키는 구현 시 명시해야 한다.

### 알림과 운영

- 알림 본문은 완성 문장 대신 `message_key`와 `message_params`로 저장해 다국어 렌더링을 지원한다.
- 신고는 동일 사용자가 같은 대상을 중복 신고하지 못하도록 UNIQUE를 둔다.
- `sync_logs`는 장소·이벤트·랭킹·히트맵·카운터 보정 작업의 조합 단위 결과를 기록한다.
- `search_logs`는 인기 검색어 집계용이며 최신 정본에는 `user_id`가 없다.

## 5. 인덱스와 조회 원칙

| 목적 | 인덱스·제약 | 핵심 조건 |
|---|---|---|
| 주변 장소 검색 | `gix_places_geom` GIST | `ST_DWithin(geom, :point, :radius_m)` |
| 장소 부분어 검색 | `gin_places_title` GIN | 제목·주소 `pg_trgm` 검색 |
| 활성 게시글 목록 | `idx_posts_area_created` 등 부분 인덱스 | `status = 'ACTIVE'` |
| 안 읽은 알림 | `idx_notifications_unread` 부분 인덱스 | `is_read = false` |
| 기간별 게시글 순위 | `idx_post_rankings_lookup` | `(period, rank_no)` |
| 지역·기간·테마별 장소 순위 | `idx_rankings_lookup` | `(area_code, period, theme, rank_no)` |

## 6. 삭제와 보존

| 대상 | 정책 |
|---|---|
| 회원 탈퇴 개인정보 | 즉시 파기 또는 익명화 |
| 회원 본체 | 탈퇴 30일 뒤 배치 물리 삭제 |
| 게시글 | 상태 기반 논리 삭제, 사진 파기 기산은 `deleted_at` 사용 |
| 받은 뱃지 | 근거 게시글 삭제 후에도 유지 |
| 방문 기록 | 근거 게시글 삭제 후에도 유지 |
| 읽은 알림 | 90일 뒤 배치 삭제 |
| 비정규화 카운터 | 매일 새벽 원본 기준 보정 |

## 7. 아직 정본에 넣지 않은 제안

다음은 필요성이 제기됐지만 데이터 계약이 확정되지 않아 컬럼·테이블로 추가하지 않는다.

- MAP-025: `heatmap_cells.sample_thumbnails` 사전 저장
- SCH-011·VST-006: 사용자별 최근 검색어·최근 본 장소 저장소
- RNK-013: 애플리케이션 V19는 `places.is_curated`로 구현했다. 사용자 제공 독립 ERD 정본 반영은 후속 개정에서 결정한다.
- 신고 대상에 댓글·사용자를 포함할지 여부와 댓글 `BLINDED` 상태
- BDG-013: `badges.earned_count`
- CMU-019: 게시글 공유용 `share_slug`

## 8. 구현 산출물과 관계

- 정본 DBML: [`12-db-schema.dbml`](12-db-schema.dbml)
- 테이블·컬럼·관계 사전: [`05-erd-reference.md`](05-erd-reference.md)
- 독립 초기화 SQL: [`../backend/src/main/resources/db/standalone/01_snaphere_schema.sql`](../backend/src/main/resources/db/standalone/01_snaphere_schema.sql)
- 독립 더미 데이터 SQL: [`../backend/src/main/resources/db/standalone/02_snaphere_dummy_data.sql`](../backend/src/main/resources/db/standalone/02_snaphere_dummy_data.sql)
- 결정 기록: [`07-decision-log.md`](07-decision-log.md)의 `DEC-20260905-011`

독립 SQL은 빈 데이터베이스에서 검증하는 참조 산출물이다. 현재 애플리케이션의 `db/migration`에는 자동 적용되지 않는다.
