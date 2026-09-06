# DB 엔진 결정 — Percona PostgreSQL 17.10.2 + PostGIS 3.6.2

- 최초 결정일: 2026-09-01
- 정확 버전 고정일: 2026-09-05
- PostGIS 3.6.2 변경일: 2026-09-06
- 상태: 확정
- 관련 문서: [04-data-design.md](04-data-design.md), [12-db-schema.dbml](12-db-schema.dbml)

## 결정

**Percona Distribution for PostgreSQL 17.10.2 + PostGIS 3.6.2 하나로 통일한다.** MySQL은
사용하지 않는다. 공식 Percona 17.10.2 배포판은 PostGIS 3.5.7까지만 제공하므로 로컬 개발과
Testcontainers는 `backend/docker/postgres/Dockerfile`로 만드는 커스텀 이미지
`snaphere/percona-postgresql-with-postgis:17.10.2-postgis3.6.2`를 사용한다.

커스텀 이미지는 Percona 기반 이미지의 digest와 PostGIS 3.6.2 공식 소스 SHA-256을 고정한다.
PostGIS는 다단계 빌드하며 컴파일러·개발 헤더는 최종 런타임 이미지에 남기지 않는다.

이 변경은 DB 엔진 배포판과 패치 버전만 고정하며, 테이블·컬럼·인덱스·API 계약은 변경하지
않는다. 따라서 명세 버전은 올리지 않는다.

필요한 확장: `postgis`, `pg_trgm`

## 배경

PostgreSQL, PostGIS, MySQL을 함께 쓰는 방안이 논의되었다. PostgreSQL과 MySQL을 동시에 두는
선택지는 기각했다. 운영 대상이 두 배가 되고 두 DB에 걸친 조인과 트랜잭션이 불가능하다.
현재 스키마는 `posts` - `places` - `visits` - `badges`가 촘촘히 엮여 있어 어디로 선을 그어도
조인이 끊긴다.

## PostGIS를 고른 근거

좌표가 부가 기능이 아니라 서비스의 핵심이다 — 위치 신뢰등급 판정(PST-022), 히트맵 격자(MAP-008~012),
주변 탐색(MAP-026).

| 항목 | MySQL 8.0 | PostGIS |
| --- | --- | --- |
| 반경 검색 | `MBRContains(ST_Buffer(...))`로 인덱스를 유도하고 `ST_Distance_Sphere`로 다시 걸러야 한다. `ST_Buffer`가 평면 계산이라 버퍼 자체가 부정확하다 | `ST_DWithin(geom, :point, :radius_m)` 한 조건. 구면 거리로 정확하고 GIST 인덱스를 그대로 탄다 |
| 공간 인덱스와 NULL | `SPATIAL INDEX`가 NOT NULL 컬럼에만 걸려서, 좌표 없는 장소를 `POINT(0,0)` + `has_coordinate=false`로 우회해야 했다 | NULL 허용 — 우회가 필요 없다 (PLC-007) |
| 격자 계산 | 좌표를 직접 반올림 | `ST_SnapToGrid` 내장 (MAP-009) |

부수적으로 얻는 것

- **부분 인덱스** — soft delete가 전역 원칙(SYS-006)이므로 `WHERE status = 'ACTIVE'` 부분 인덱스로
  삭제·블라인드된 행을 인덱스에서 아예 뺀다. 안읽은 알림(NTF-012)도 `WHERE is_read = false`로
  작은 인덱스가 된다.
- **pg_trgm GIN** — 한글 부분어 검색(SCH-004)에서 `LIKE '%경복%'`도 인덱스를 탄다. MySQL의 ngram
  FULLTEXT는 `ngram_token_size` 서버 설정에 묶여 1글자 검색을 늘리기 어려웠다.
- **jsonb + GIN** — `condition_json`(BDG-007), `fixed_tags`(EVT-017), `sample_post_ids`(MAP-022),
  `message_params`(NTF-009).
- **표현식 인덱스 / citext** — 태그 정규화(CMU-025)를 `lower(name)`으로 처리할 수 있다.

## 타입 매핑 (MySQL 기준으로 쓰인 이전 자료를 읽을 때)

| MySQL | PostgreSQL |
| --- | --- |
| `datetime` | `timestamptz` — 저장 UTC, 해석 Asia/Seoul (SYS-005) |
| `point` + SRID 4326 | `geography(Point,4326)` |
| `json` | `jsonb` |
| `decimal(p,s)` | `numeric(p,s)` |
| `tinyint` | `smallint` |
| `bigint AUTO_INCREMENT` | `bigint GENERATED ALWAYS AS IDENTITY` |
| `SPATIAL INDEX` | `GIST` |
| `FULLTEXT ... WITH PARSER ngram` | `GIN` + `pg_trgm` |
| `INSERT ... ON DUPLICATE KEY UPDATE` | `INSERT ... ON CONFLICT DO NOTHING / UPDATE` |

## 폐기되는 이전 검증

이전에 MySQL 8.0에서 실행 검증했던 내용은 그대로 쓸 수 없다.

| 항목 | 상태 |
| --- | --- |
| 좌표 축 순서 함정 (`ST_X`가 위도, `POINT()`와 WKT의 순서가 반대) | **MySQL 고유 함정.** PostGIS는 `ST_X`=경도, `ST_Y`=위도로 일관된다. 다만 `ST_MakePoint(경도, 위도)`를 한 곳에서만 호출하는 원칙은 유효하다 |
| `MBRContains` + `ST_Distance_Sphere` EXPLAIN 검증 | 폐기. `ST_DWithin` 하나로 대체 |
| ngram FULLTEXT, `ngram_token_size` | 폐기. `pg_trgm` GIN으로 대체 |
| MySQL `schema.sql` | 다시 작성 필요 |
| 설계 판단(places 통합, posts 통합, 알림 dedup 키, 히트맵 별도 테이블, 카운터 비정규화, soft delete) | 그대로 유효. 엔진과 무관한 판단이다 |
| 인덱스 설계 근거 | 대상 쿼리는 유효. 인덱스 종류를 GIST·GIN으로 바꾸고 목록 인덱스는 부분 인덱스로 만든다 |

## 착수 전 확인할 것

1. 관리형 서비스(RDS / Cloud SQL / Supabase 등)에서 `postgis`, `pg_trgm` 확장이 켜지는지 확인한다.
   대부분 지원하지만 플랜에 따라 다르다.
2. `geography`와 `geometry` 중 **`geography`를 쓴다.** 반경이 미터 단위이고 전국 범위이므로
   구면 계산이 맞다. `geometry`는 좌표계 변환이 필요하고 거리가 도(degree) 단위가 된다.
3. JPA / Hibernate를 쓰면 `hibernate-spatial`과 PostGIS dialect 설정이 필요하다.
