# SnapHere API (backend)

Spring Boot 3.5 · JDK 21.0.11 · Gradle 8.14 (Kotlin DSL) 기반 백엔드 API 서버.

명세는 저장소 문서를 정본으로 삼는다.

| 문서 | 위치 |
| --- | --- |
| 요구사항 명세서 | `docs/01-requirements-spec.md` |
| 기능 명세서 | `docs/02-feature-spec.md` |
| API 명세서 | `docs/03-api-spec.md` |
| ERD 참조 | `docs/05-erd-reference.md` |
| DB 스키마 (DBML) | `docs/12-db-schema.dbml` |
| 명세 변경 이력 | `docs/08-spec-changelog.md` |
| 커밋·브랜치 규칙 | `docs/commit-convention.md` |
| 스프레드시트 원본 | `docs/specs/` |

## 로컬 실행

다음 버전을 프로젝트 기준으로 고정한다.

| 구성 요소 | 고정 버전 |
| --- | --- |
| JDK | 21.0.11 (벤더 무관) |
| Gradle | 8.14 |
| PostgreSQL | Percona Distribution 17.10.2 |
| PostGIS | 3.6.2 (저장소 Dockerfile로 빌드) |

JDK 21.0.11을 설치하고 `JAVA_HOME`을 해당 설치 경로로 지정한 뒤, 저장소에 포함된 Gradle
8.14 Wrapper로 실행한다. `.java-version`과 빌드 검사가 다른 JDK 패치 버전의 사용을 막는다.

```bash
./gradlew build      # 컴파일 + 테스트
./gradlew bootRun    # 로컬 실행 (기본 8080)
```

## 폴더 구조

```text
backend/src/main/java/com/snaphere/api/
├── SnapHereApplication.java
├── common/
│   ├── error/      # 에러 코드 체계와 전역 예외 처리 (SYS-002)
│   ├── security/   # 현재 로그인 사용자 조회 (AUTH-011)
│   └── web/        # 공통 응답 봉투·커서 페이징·요청 추적 (SYS-001, SYS-003, SYS-016)
├── auth/           # 구글 로그인·JWT·리프레시 토큰 회전 (AUTH-001~011, AUTH-014)
├── media/          # 업로드 URL 발급·객체 저장소 (PST-013~015)
├── place/          # 장소·지역
│   ├── entity/     #   regions · sigungu · places
│   ├── repository/ #   조회. 공간 조건은 네이티브 쿼리
│   ├── jpa/        #   조회 포트의 JPA 구현
│   └── stub/       #   DB 없이 돌릴 때의 고정 데이터
├── post/           # 게시글
│   ├── entity/     #   posts · post_images · tags · post_tags · tier_logs
│   ├── repository/ #   조회. 목록은 전부 커서 기반
│   ├── jpa/        #   판정 근거 적재 (tier_logs)
│   ├── tier/       #   등급 판정 규칙 (PST-022~028)
│   ├── media/      #   썸네일·EXIF 제거·해시 후처리 (PST-019~021)
│   ├── event/      #   커밋 이후 처리를 위한 도메인 이벤트
│   └── dto/        #   요청·응답
├── user/           # 작성자 조회 포트 (auth 엔티티 의존을 가르는 경계)
├── visit/          # 방문 자동 기록 포트 (VST-001) — 구현 대기
├── badge/          # 뱃지 획득 포트 (BDG-005) — 구현 대기
└── report/         # 업로드 정지 조회 포트 (PST-032) — 구현 대기
```

`visit`·`badge`·`report` 는 인터페이스와 아무것도 하지 않는 구현만 있다. 해당 테이블이 다른
담당 범위여서 스키마가 없는데, 게시글 생성 응답의 계약(`visitRecorded`, `earnedBadges`)을
비워 둘 수는 없어서 포트로 남겼다. 실제 구현을 추가할 때 `NoOp*` 파일을 지운다 — 조건부
등록을 걸지 않았으므로 구현이 하나 더 생기면 애플리케이션이 뜨지 않고 중복 빈을 알려 준다.

## 데이터베이스 준비

Percona Distribution for PostgreSQL 17.10.2 + PostGIS 3.6.2가 필요하다. 스키마는 Flyway가
만든다 — 손으로 만들지 않는다.

| 파일 | 내용 |
| --- | --- |
| `V1__auth_schema.sql` | `users` · `user_devices` · `refresh_tokens` |
| `V2__place_schema.sql` | `regions` · `sigungu` · `places` + 공간·검색 인덱스 |
| `V3__post_schema.sql` | `posts` · `post_images` · `tags` · `post_tags` · `tier_logs` |
| `V4__region_seed.sql` | 17개 시도 기준정보. `posts.area_code` 가 참조하므로 없으면 게시글을 만들 수 없다 |
| `V11__place_features.sql` | 장소 상세·저장·랭킹·신고·이벤트·배치 운영 확장 |
| `V12__map_aggregates.sql` | 기간별 히트맵 셀·지역 통계·갱신 상태 집계 |
| `V19__place_ranking_dimensions.sql` | 운영자 추천 장소와 전국·지역·장소 유형별 랭킹 집계 차원 |

`V11__place_features.sql`은 병합 직후 V8/V9의 `bookmarks`·`reports`를 중복 생성하던 오류를
수정했다. 수정 전 V11을 이미 적용한 개발 DB는 새 코드를 올리기 전에 Flyway `repair`로
체크섬을 맞춰야 한다. 신규 DB는 V1부터 그대로 적용하면 된다.

`V2` 가 `postgis` · `pg_trgm` 확장을 만든다. 확장 생성에는 보통 슈퍼유저 권한이 필요하니
관리형 DB(RDS 등)에서는 관리자 계정으로 한 번 만들어 두고 애플리케이션 계정에는 권한을 주지 않아도 된다.

Docker 로 띄우는 것이 가장 간단하다. 공식 Percona 17.10.2 이미지의 PostGIS는 3.5.7이므로,
저장소의 다단계 Dockerfile이 공식 3.6.2 소스를 검증·빌드한 커스텀 이미지를 쓴다.

```bash
docker build -t snaphere/percona-postgresql-with-postgis:17.10.2-postgis3.6.2 \
  docker/postgres
docker run -d --name snaphere-db -p 5432:5432 \
  -e POSTGRES_DB=snaphere -e POSTGRES_USER=snaphere -e POSTGRES_PASSWORD=snaphere \
  snaphere/percona-postgresql-with-postgis:17.10.2-postgis3.6.2
```

저장소 루트에서는 `docker compose build postgres` 후 `docker compose up -d`로 같은 이미지를
빌드하고 실행할 수 있다. Testcontainers도 `docker/postgres/Dockerfile`을 직접 빌드한다.

`spring.jpa.hibernate.ddl-auto` 는 `validate` 다. 엔티티와 마이그레이션이 어긋나면 애플리케이션이
기동하지 않고 어느 컬럼이 다른지 알려 준다 — 스키마를 Hibernate 가 바꾸는 일은 없다.

대부분의 단위·웹 테스트는 H2에서 실행하며 Flyway를 끄고 Hibernate가 엔티티에서 스키마를
만든다(`src/test/resources/application.yml`). `PlaceSchemaIntegrationTests`는 예외로 위 커스텀
이미지를 Testcontainers로 직접 빌드하고 Flyway와 `ddl-auto=validate`를 켜서 실제 PostGIS 문법,
마이그레이션, MAP·RNK 집계를 검증한다. Docker 29에서도 건너뛰지 않도록 테스트 작업의 Docker
API 기본값은 1.40으로 설정돼 있으며 `-Dapi.version=...`으로 재정의할 수 있다.

## 실행 전 필요한 값

아래 환경 변수가 필요하다. `SNAPHERE_JWT_SECRET` 은 32바이트 이상
무작위 값으로 설정하고, 모바일 앱의 Google OAuth 클라이언트 ID 를 쓴다.

```text
DB_URL=jdbc:postgresql://localhost:5432/snaphere
DB_USERNAME=snaphere
DB_PASSWORD=...
GOOGLE_OAUTH_CLIENT_ID=...
SNAPHERE_JWT_SECRET=...
SNAPHERE_TERMS_VERSION=2026-08-01
TOUR_API_SERVICE_KEY=...
GOOGLE_MAPS_API_KEY=...
REDIS_HOST=localhost
REDIS_PORT=6379
```

S3 를 쓸 때만 추가한다. 자격증명은 설정 파일에 두지 않고 SDK 기본 체인을 사용한다.

```text
MEDIA_PROVIDER=s3
MEDIA_S3_BUCKET=snaphere-media
MEDIA_S3_REGION=ap-northeast-2
MEDIA_PUBLIC_BASE_URL=https://cdn.example.com
```

## 지금 구현된 것

### 공통

| 클래스 | 역할 | 요구사항 |
| --- | --- | --- |
| `common.web.ApiResponse` | 성공·실패 공통 응답 봉투 | `SYS-001` |
| `common.web.CursorPage` | 커서 페이징 응답 | `SYS-003`, `SYS-004`, `CMU-010` |
| `common.web.TraceIdFilter` | `X-Trace-Id` 수용·생성, MDC 주입 | `SYS-016` |
| `common.error.ErrorCode` | 코드 기반 에러 분기 | `SYS-002` |
| `common.error.ErrorBody` | 실패 봉투 본문 (`violations`, `retryAfterSec`) | `SYS-002` |
| `common.error.GlobalExceptionHandler` | 모든 예외를 실패 봉투로 변환 | `SYS-001`, `SYS-002` |

### 엔드포인트

| API ID | 메서드 · 경로 | 기능 명세 | 요구사항 |
| --- | --- | --- | --- |
| `API-AUTH-001`~`005` | `/api/v1/auth/*` | 9.1 로그인 · 9.2 온보딩 | `AUTH-001`~`AUTH-011`, `AUTH-014` |
| `API-PST-001` | `POST /api/v1/media/presigned-urls` | 2.3 사진·캡션·태그 > 업로드 실행 | `PST-013`~`PST-015`, `USER-004`, `SYS-020` |
| `API-PST-002` | `POST /api/v1/posts/tier-preview` | 2.2 위치 확인 > 등급 미리보기 | `PST-022`~`PST-028`, `PST-046`~`PST-049` |
| `API-PST-003` | `POST /api/v1/posts` | 2.3 사진·캡션·태그 > 게시글 등록 | `PST-001`~`PST-004`, `PST-016`~`PST-021`, `PST-029`~`PST-031` |
| `API-PLC-001`~`009` | `/api/v1/regions`, `/api/v1/places*` | 2.1 장소 설정 · 6.1 장소 정보 | `PLC-001`~`PLC-023` |
| `API-MAP-001`~`004` | `/api/v1/map/*` | 지역·히트맵·사진 마커·셀 상세 | `MAP-001`~`MAP-030` 백엔드 범위 |
| `API-RNK-001` | `GET /api/v1/rankings/places` | 전국·지역·기간·테마·장소 유형별 사전 집계 순위 | `RNK-001`~`RNK-010` |
| `API-RNK-002` | `GET /api/v1/recommendations/places` | 거리·지역 기반 추천과 운영자 지정 장소 폴백 | `RNK-011`~`RNK-013` |
| `API-ADM-001`~`003` | `/api/v1/admin/batches*`, `/api/v1/admin/sync-logs` | 관리자 장소 동기화 | `PLC-008`~`PLC-010` |
| `API-ADM-005`~`010`, `013` | `/api/v1/admin/events*`, `/api/v1/admin/places*`, `/api/v1/admin/reports*` | 관리자 반경·신고 처리 | `PLC-022`, `PLC-023` |

### 위치 신뢰 등급 (`PST-022`~`PST-026`)

판정 기준은 세 가지뿐이고 순서가 정해져 있다. `post.tier.TierPolicy` 한 곳에만 규칙이 있으며,
미리보기(`API-PST-002`)와 게시글 등록(`API-PST-003`)이 같은 클래스를 쓴다.

| 등급 | 조건 | 랭킹 가중치 | 뱃지 | 방문 기록 | 히트맵 |
| --- | --- | --- | --- | --- | --- |
| `HIGH` 높음 | 카메라 촬영 후 10분 이내 + 인증 반경 안 | 3.0 | ✅ | ✅ | ✅ |
| `MEDIUM` 보통 | 촬영 후 30일 이내 + 인증 반경 안 | 1.8 | ✅ | ✅ | ✅ |
| `LOW` 낮음 | 촬영 좌표 없음 / 반경 밖 / 30일 경과 | 0.5 | ❌ | ❌ | ❌ |

낮음도 게시와 랭킹 반영은 허용한다. 0점을 주면 EXIF 가 없는 기기 사용자가 전부 배제된다 (`PST-025`).

### 장소 랭킹·추천 (`RNK-001`~`RNK-013`)

`RankingJobs`가 기본 10분마다 일간·주간·월간·전체 점수와 순위를 `place_rankings`에 저장한다.
점수는 신뢰 등급 게시글, 자기 좋아요를 뺀 좋아요, 댓글, 장소 방문·조회 카운터를 사용한다.
전국·지역과 전체·공식·사용자 장소 순위는 집계 때 각각 계산하므로 조회 API는 점수를 다시 계산하지 않는다.
동점은 `place_id` 오름차순으로 고정하며, 직전 집계의 순위는 `previous_rank`에 남긴다.

추천은 주간 전체 랭킹에 작은 무작위 계수를 섞고, 좌표가 있으면 20km 이내만 후보로 쓴다.
후보가 없으면 `places.is_curated=true`인 활성 장소를 `CURATED` 사유 코드로 반환한다.
관리자는 `POST /api/v1/admin/batches/RANKING_RECALC`로 네 기간을 즉시 다시 계산할 수 있다.

**인증 반경 우선순위** (`PLC-022`, `EVT-023`) — 이벤트별 값 → 그 지역 기본값 → 2,000m.
일반 게시글은 장소에 설정된 값(관광지 500m / 사용자 장소 100m)을 쓴다.

### 이미지 후처리 (`PST-019`~`PST-021`)

썸네일 생성·EXIF 제거·해시 계산은 등록 응답과 분리해 돌린다. 게시글 커밋 이후에
`PostCreatedEvent` 를 받아 `imageProcessingExecutor` 풀에서 처리한다.

| 단계 | 객체 키 | 이유 |
| --- | --- | --- |
| 원본 보관 | `originals/{키}` | 좌표가 남은 사본. 심사 근거이고 후처리를 다시 돌릴 수 있다 (`PST-020` 비고) |
| 공개 이미지 | `{키}` (덮어쓰기) | 새 키를 만들면 저장된 `image_key` 와 앱이 든 주소가 어긋난다 |
| 썸네일 | `thumbs/{키}` | 긴 변 480px |

EXIF 는 태그를 하나씩 지우지 않는다. `ImageIO` 로 픽셀만 읽어 다시 인코딩하면 EXIF·GPS·기기
정보가 애초에 옮겨지지 않는다. 지울 태그 목록을 관리할 필요가 없고 라이브러리도 더 붙이지 않는다.

해시는 **원본** 바이트로 계산한다. 재인코딩 결과로 계산하면 JDK 인코더가 바뀔 때 같은 사진의
해시가 달라져 중복 판정(`PST-031`)이 무너진다.

후처리가 실패해도 게시글은 남는다. 사진은 원본 그대로 보이고 썸네일·해시만 비며, 목록에서는
원본 주소와 기본 비율을 대신 준다. 한 장이 실패해도 나머지 사진은 계속 처리한다.

## 로컬에서 호출해 보기

`Authorization: Bearer {accessToken}` 로 호출한다. 토큰은 `POST /api/v1/auth/google` 로 받는다.

```bash
# 업로드 URL 발급
curl -X POST http://localhost:8080/api/v1/media/presigned-urls \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  -d '{"purpose":"POST_IMAGE","files":[{"mimeType":"image/jpeg","sizeBytes":1048576}]}'

# 카메라로 방금 찍고 반경 안 -> HIGH
curl -X POST http://localhost:8080/api/v1/posts/tier-preview \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  -d '{"placeId":1,"source":"CAMERA","takenAt":"2026-09-02T12:00:00+09:00","lat":37.5796,"lng":126.9770}'

# 촬영 좌표가 없으면 -> LOW (improvementHints 로 올리는 방법을 알려준다)
curl -X POST http://localhost:8080/api/v1/posts/tier-preview \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  -d '{"placeId":1,"source":"ALBUM"}'
```

`snaphere.stub-data=true` 일 때 `placeId` 1 = 관광지(경복궁 좌표, 반경 500m), 2 = 사용자 장소(반경 100m),
3 = 좌표 없는 장소, 4 = 축제 장소. `eventId` 1 = 지역 기본값(2,500m), 2 = 이벤트별 값(3,000m).

## 장소 기능 운영 참고

- TourAPI 동기화는 지역 17개 × 콘텐츠 타입 6개를 조합별 독립 트랜잭션으로 처리한다.
- 장소 상세 조회수는 Redis에 누적한 뒤 PostgreSQL에 반영하며, Redis 장애 시 DB 직접 증가로 대체한다.
- 사용자 장소는 Google 역지오코딩으로 대한민국 범위와 시도·시군구를 판정한다.
- `visits`·`user_badges`는 기존 포트와 No-Op 구현을 유지하며 담당 기능에서 확장한다.
