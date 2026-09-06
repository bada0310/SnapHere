# 명세 변경 이력 (Spec Changelog)

요구사항 명세서 · API 명세서 · 데이터 설계 세 문서의 버전과 변경 내역을 한곳에 모은다.
**세 문서는 같은 버전 번호로 함께 올린다.** 하나만 바뀌어도 세 문서 모두 같은 번호가 된다.

| 문서 | 파일 | 현재 버전 |
| --- | --- | --- |
| 요구사항 · 기능 명세서 | [specs/snaphere-requirements-spec-v1.1.5.xlsx](specs/snaphere-requirements-spec-v1.1.5.xlsx) | **v1.1.5** |
| API 명세서 · ERD | [specs/snaphere-api-spec-v1.1.5.xlsx](specs/snaphere-api-spec-v1.1.5.xlsx) | **v1.1.5** |
| 데이터 설계 | `04-data-design.md` · `05-erd-reference.md` · `12-db-schema.dbml` | **v1.1.5** |

> 데이터 설계 두 파일은 `docs/backend-db-design` 브랜치에 있다. 그 PR이 `develop`에 병합되면 같은 `docs/` 폴더에서 함께 보인다.

---

## 작성 규칙

이 문서에 줄을 추가할 때는 아래 규칙을 지킨다. 사람이 쓰든 AI에게 시키든 같다.

### 반드시 지킬 것

1. **모든 변경은 ID로 지목한다.** 요구사항 변경은 `요구사항 ID`(`AUTH-001` 형식), API 변경은 `API ID`(`API-PST-003` 형식), 배치는 `JOB ID`(`JOB-013` 형식), 데이터 설계 변경은 `테이블명`으로 쓴다.
2. **한 줄에 하나의 변경만 적는다.** 여러 ID가 같은 이유로 바뀌었으면 ID를 쉼표로 나열하되, 변경 내용이 다르면 줄을 나눈다.
3. **`변경 전 → 변경 후`를 둘 다 적는다.** "수정함"이 아니라 "`Could` → `Should`", "`ANONYMIZE` → `KEEP_ANONYMIZED`" 처럼 쓴다.
4. **근거 열을 비우지 않는다.** 어느 결정·어느 문서에서 나왔는지 적는다 (예: `미확정 15건 결정 10`, `DBML v1.1.3 users.bio`, `CMU-001 의존`).
5. **구분은 5개만 쓴다** — `신규` / `변경` / `승격` / `삭제` / `정정`.
6. **API 변경에는 대응 요구사항 ID를 같이 적는다.** 대응이 없으면 그 자체가 문제이므로 `대응 없음 — 확인 필요`라고 적는다.
7. **버전을 올릴 때는 세 문서를 함께 올린다.** 한 문서만 바뀌어도 나머지 두 문서의 표지 버전을 같이 올리고, "내용 변경 없음"이라고 적는다.
8. **표에는 그 버전에서 바뀐 항목만 적는다.** 이 문서는 변경 이력이지 명세서 사본이 아니다. 바뀌지 않은 요구사항·API·테이블은 한 줄도 넣지 않는다. 현재 상태가 궁금하면 해당 버전의 명세서 파일을 본다.

### 하지 말 것 (Negative Prompt)

이 지시를 AI에게 그대로 붙여넣어도 된다.

```text
아래는 명세 변경 로그를 작성할 때 절대 하지 말아야 할 것이다.

- ID 없이 쓰지 마라. "게시글 관련 수정", "지도 개선" 처럼 기능 이름만 적은 줄은 만들지 마라.
  반드시 요구사항 ID(PST-035) / API ID(API-PST-005) / JOB ID(JOB-013) / 테이블명으로 지목하라.
- 존재하지 않는 ID를 만들어내지 마라. 명세서에 실재하는 ID만 쓰고,
  확실하지 않으면 "확인 필요"라고 적고 멈춰라.
- 변경 전 값을 생략하지 마라. "Should로 변경" 이 아니라 "Could → Should" 로 적어라.
- 근거를 추측해서 채우지 마라. 결정 문서·DBML·요구사항 원문에 실제로 있는 근거만 적고,
  없으면 "근거 없음 — 확인 필요"라고 적어라.
- 여러 변경을 한 줄에 뭉뚱그리지 마라. "enum 정리" 같은 요약 줄로 여러 API를 덮지 마라.
- 이미 기록된 과거 버전의 줄을 고치거나 지우지 마라. 잘못됐으면 새 버전에 정정 줄을 추가하라.
- 요구사항 ID의 중요도(Must/Should/Could)를 근거 없이 바꾸지 마라.
  승격·강등은 반드시 의존 관계나 결정 문서를 근거로 제시하라.
- 세 문서 중 하나만 버전을 올리지 마라.
- 명세서 전체를 이 문서에 옮겨 적지 마라. 표에는 그 버전에서 실제로 바뀐 줄만 넣어라.
  바뀌지 않은 요구사항·API·테이블을 "현황 정리" 명목으로 나열하지 마라.
- 이전 버전 표에 있던 줄을 새 버전 표에 다시 쓰지 마라. 각 줄은 한 버전에만 존재한다.
```

---

## 버전 로그

| 버전 | 날짜 | 대상 문서 | 요약 | 건수 |
| --- | --- | --- | --- | --- |
| v1.0.0 | 2026-08-20 | 요구사항 / API / 데이터 설계 | 최초 작성 | — |
| v1.1.0 | 2026-08-31 | 요구사항 | 용어 표준화 · 위치 신뢰등급 `T1/T2/T3` → `높음/보통/낮음` 개편, `PST-046~049` 신설, 참조 ID 밀림 정정 | 요구사항 12 |
| v1.1.0 | 2026-09-01 | 요구사항 | 미확정 15건 전부 결정 반영 | 요구사항 17 |
| v1.1.0 | 2026-09-01 | API | 요구사항 대조 점검 결과 반영 (충돌 11 · 내부 모순 4 · 보강 14) | API 29 |
| v1.1.1 | 2026-09-01 | API | 데이터 설계 DBML v1.1.3과 정합 (기간 enum · 키 설계 · enum 값) | API 9 |
| **v1.1.3** | **2026-09-01** | **요구사항 / API / 데이터 설계** | **세 문서 버전 통일.** 요구사항 2건 반영 + 요구사항 `6. 데이터 설계` 시트를 DBML v1.1.3(29개 테이블)에 동기화 | 요구사항 2 · 데이터 설계 14 |

| **v1.1.4** | **2026-09-03** | **요구사항 / API / 데이터 설계** | **백엔드 구현 정합.** `users` 식별자 `uuid` 정정 · `images[]` 원소 구조 정의 · `sortOrder` 기준 정정 · `places.status` 와 `reports` 운영 검토 컬럼 반영 | 요구사항 1 · API 5 · 데이터 설계 3 |
| **v1.1.5** | **2026-09-05** | **MAP / PLC API / 데이터 설계** | **지도 백엔드 구현 정합.** 줌·폴백·500셀 제한 확정, 썸네일 URL 사전 저장, 기간 포함 cellKey, 최근접 거리 응답, 주변 장소 페이징 표기 제거 | 요구사항 5 · API 7 · 데이터 설계 3 |
| **v1.1.6** | **2026-09-06** | **요구사항 / API / 데이터 설계** | **탈퇴 유예 중 복구 정책 반영.** 계정 정보 보존·복구 제안 및 파기 시점 정정 | 요구사항 3 · API 2 · 데이터 설계 1 |

> `v1.1.1` · `v1.1.2`는 API·DBML만 쓰던 번호다. 통합 번호 체계를 도입하면서 요구사항 명세서 기준으로는 **결번**이다.

---

## 변경 상세 — 요구사항 ID 기준

### v1.1.0 (2026-08-31) · 용어 표준화 · 위치 신뢰등급 개편

| 요구사항 ID | 구분 | 변경 전 | 변경 후 | 근거 |
| --- | --- | --- | --- | --- |
| `PST-022`~`PST-026` | 변경 | 등급 `ON_SITE` / `VISITED` / `SELF_REPORTED` (바로 그곳 / 다녀온 곳 / 자가 기록) | 등급 `HIGH` / `MEDIUM` / `LOW` (높음 / 보통 / 낮음) | 용어 표준화 결정 2026-08-31 — 이름만 봐서는 서열이 안 보임 |
| `PST-046` | 신규 | — | 신뢰 등급 배지 표시 (Should) | 용어 표준화 결정 2026-08-31 |
| `PST-047` | 신규 | — | 신뢰 등급 기준 안내 (Should) | 용어 표준화 결정 2026-08-31 |
| `PST-048` | 신규 | — | 업로드 전 등급 미리보기 (Should) | 용어 표준화 결정 2026-08-31 |
| `PST-049` | 신규 | — | 등급 향상 안내 (Could) | 용어 표준화 결정 2026-08-31 |
| `PST-033` | 정정 | 기능 명세 `5.1 장소 카드`가 `PST-032` 참조 | `PST-033` 참조 | `PST-032` 추가로 뒤 번호 1씩 밀림 |
| `PST-036` | 정정 | 기능 명세 `5.5 수정`이 `PST-035` 참조 | `PST-036` 참조 | 동일 |
| `PST-038` | 정정 | 기능 명세 `5.5 삭제`가 `PST-037` 참조 | `PST-038` 참조 | 동일 |
| `PST-040` | 정정 | 기능 명세 `5.2 좋아요` · 용어 사전이 `PST-039` 참조 | `PST-040` 참조 | 동일 |
| `PST-043` | 정정 | 기능 명세 `5.5 신고` · 데이터 설계가 `PST-042` 참조 | `PST-043` 참조 | 동일 |
| `PST-044` | 정정 | 데이터 설계 `reports`가 `PST-043` 참조 | `PST-044` 참조 | 동일 |
| `PST-037` | 정정 | 미확정 3번이 `PST-036` 참조 | `PST-037` 참조 | 동일 |

### v1.1.0 (2026-09-01) · 미확정 15건 결정 반영

| 요구사항 ID | 구분 | 변경 전 | 변경 후 | 근거 |
| --- | --- | --- | --- | --- |
| `PST-006` | 승격 | Could | **Should** — 카메라 촬영 업로드 구현, 촬영 후 10분 이내·반경 안이면 높음 등급 후보 | 미확정 결정 1 |
| `PST-007` | 변경 | 보류 | Could — 사진 위 텍스트·이모티콘은 핵심 업로드 안정화 후 | 미확정 결정 2 |
| `PST-037` | 변경 | "안 하는 쪽으로 기움" | **불허용** 확정 — 게시 후 장소·좌표·등급 수정 불가, 캡션·해시태그만 수정 | 미확정 결정 3 |
| `MAP-011` | 변경 | 기본 기간 미정 | 기본값 **주간(WEEKLY)**, 값 이름 `LAST_1H` / `LAST_24H` / `WEEKLY` / `MONTHLY`, 조회 시점 기준 롤링 윈도우 | 미확정 결정 4 |
| `MAP-014` | 변경 | 폴백 조건 미정 | 실시간(`LAST_1H`) 선택 시에만 `LAST_24H` 자동 대체 | 미확정 결정 4 |
| `MAP-022` | 변경 | 후보 개수·교체 간격 미정 | 마커당 후보 사진 **최대 10장**, 앱이 **3초** 간격 교체, 교체 중 재요청 없음 | 미확정 결정 5 |
| `MAP-023` | 변경 | — | 확대 상태에서는 마커당 1장, 로테이션 정지 | 미확정 결정 5 |
| `MAP-006` | 변경 | 시도 라벨 좌표 제공 | **시도 대표 이미지 선택** (라벨 좌표 미제공) | 미확정 결정 6 |
| `CMU-004`, `CMU-005` | 변경 | 커뮤니티 화면 구성 고민 중 | 현재 구성 확정 — 상단 고정 검색바 + 인기/팔로잉/최근, 기본 탭 인기 | 미확정 결정 7 |
| `SOC-014`, `CMU-001` | 변경 | 팔로잉 빈 상태 미정 | 팔로잉 피드가 비면 **추천 사용자 노출** | 미확정 결정 8 |
| `EVT-*`, `SYS-008` | 변경 | 표시 용어 후보 (현장 / 나들이 / 축제) | 표시 용어 **이벤트(Event)** 확정 | 미확정 결정 9 |
| `PLC-022`, `PST-027`, `EVT-023` | 변경 | 이벤트 인증 반경 미정 | 이벤트 기본 **2,000m** (관광지 500m · 사용자 장소 100m 유지), 향후 지역별 재정의 가능 | 미확정 결정 10 |
| `VST-010` | 변경 | 방문 지도 표현 미정 | 지도 + 하단 뱃지 병행 표시 | 미확정 결정 11 |
| `BDG-009`, `BDG-010` | 변경 | 진행률 분모 미정 | 분모 = **현재 획득 가능한 전체 뱃지 수** (획득 불가·비활성 제외) | 미확정 결정 12 |
| `NTF-001`~`NTF-003` | 변경 | 적용 여부 미정 | **Could** — 일정 여유 시 구현 | 미확정 결정 13 |
| `SYS-010` | 변경 | 다국어 처리 미해결 | **Should** — 원문 + `original_language_code` 보존, 번역은 별도 필드로 후속 확장 | 미확정 결정 14 |
| `RNK-005`, `PST-004` | 변경 | K-컬처 테마 데이터 확보 방식 미해결 | **사용자 태그 등록** 기반, 태그를 테마로 정규화 | 미확정 결정 15 |

### v1.1.3 (2026-09-01)

| 요구사항 ID | 구분 | 변경 전 | 변경 후 | 근거 |
| --- | --- | --- | --- | --- |
| `USER-003` | 변경 | 기능 이름 "닉네임 규칙 검증" · 내용 "닉네임은 2~20자이며 금칙어를 포함할 수 없다." | 기능 이름 **"닉네임·소개 규칙 검증"** · 내용에 **"소개(bio)는 최대 200자다."** 추가 | 데이터 설계 DBML v1.1.3 `users.bio varchar(200)`. 요구사항에 길이 규정이 없어 API가 임의로 300자를 쓰고 있었다 |
| `SOC-014` | 승격 | Could | **Should** | `CMU-001`(Must)의 "피드가 비면 추천 사용자를 노출한다"가 이 기능에 의존한다. Must 기능의 일부가 Could 기능에 의존하는 상태였음 |

> 이 두 건으로 중요도 분포가 **Must 172 / Should 89 / Could 30 → Must 172 / Should 90 / Could 29** 로 바뀌었다. 전체 291건은 그대로다.

### v1.1.4 (2026-09-03) · 구현 정합

| 요구사항 ID | 구분 | 변경 전 | 변경 후 | 근거 |
| --- | --- | --- | --- | --- |
| `PST-031` | 변경 | 비고 없음 | 비고에 **해시 산출 주체와 시점** 명시 — 클라이언트가 업로드 전에 계산해 보내고, 후처리가 실제 해시로 덮어쓴다 | `PST-019`(후처리를 응답과 분리)와 부딪히는 지점이다. 서버가 등록 시점에 원본을 내려받아 계산하면 사진 4장에 최대 40MB 를 응답 앞에 끼워 넣게 된다 |

> 중요도·건수 분포는 바뀌지 않았다. 전체 291건 · Must 172 / Should 90 / Could 29 그대로다.

---

## 변경 상세 — API ID 기준

### v1.1.0 (2026-09-01) · 요구사항 대조 29건

#### 충돌 — 요구사항을 구현할 수 없던 항목

| API ID | 구분 | 변경 전 → 변경 후 | 대응 요구사항 |
| --- | --- | --- | --- |
| `API-MAP-002` | 변경 | `period` = `REALTIME\|DAY\|WEEK\|MONTH` → `LAST_1H\|LAST_24H\|WEEKLY\|MONTHLY` (기본 `WEEKLY`, 롤링 윈도우) | `MAP-011` |
| `API-MAP-002` | 신규 | 응답에 `HeatmapCell.intensity`(0~1) · `HeatmapResult.maxCount` 추가 — 없어서 앱이 색을 계산할 수 없었다 | `MAP-010` |
| `API-PST-005` | 변경 | 관련 테이블 `posts, likes, comments`(조회 시 실시간 집계) → `post_rankings`(사전 집계 조회) | `PST-035`, `CMU-008` |
| `API-CMU-001` | 변경 | 동일 — 사전 집계 조회로 전환 | `CMU-002`, `CMU-008` |
| `JOB-013` | 신규 | `POST_RANKING_RECALC` (10분 + 수동) 신설 — 게시글 인기 집계 배치가 없었다 | `CMU-008`, `PST-035` |
| `API-USER-001` | 신규 | `MyProfile.role`(`USER\|ADMIN`) 추가 — 관리자 API 13개의 권한 판정 근거가 없었다 | `AUTH-014` |
| `API-PLC-005` | 신규 | `PlaceDetail.languageCode` 추가, `place_details` 를 `(place_id, language_code)` 단위로 | `SYS-012` |
| `API-USER-004`, `API-SOC-003`, `API-SOC-004` | 신규 | `UserSummary.isFollowedBy` 추가 — 맞팔 배지를 그릴 수 없었다 | `USER-005`, `SOC-012` |
| `API-EVT-006` | 신규 | `GET /api/v1/events/region-summary` 신설 (`EventRegionSummary.newCount`) — 시도 칩 강조 데이터가 없었다 | `EVT-007`~`EVT-009` |
| `API-EVT-001`, `API-EVT-003`, `API-EVT-004` | 신규 | `EventSummary.isNew` · `dday` · `createdAt` 추가 | `EVT-008` |
| `API-PST-004`, `API-PST-005`, `API-PST-006` | 신규 | `PostSummary.imageCount` 추가 — 피드 카드에 "여러 장"을 표시할 수 없었다 | `SOC-013` |
| `API-USER-009` | 변경 | `contentAction` = `ANONYMIZE\|DELETE_ALL` → `KEEP_ANONYMIZED\|DELETE_ALL` | `USER-016` |
| ERD `users` | 변경 | `stamp_count` → `badge_count`, `upload_blocked_until` 추가, 알림 설정을 `push_like_enabled`·`push_follow_enabled`·`push_badge_enabled` 3컬럼으로 | 용어 표준화 2026-08-31, `PST-032`, `USER-023` |

#### 내부 모순

| API ID | 구분 | 변경 전 → 변경 후 | 대응 요구사항 |
| --- | --- | --- | --- |
| `API-PLC-007` | 정정 | 비고 `reused=true/false` → 실제 응답 필드 `created` · `duplicateOfPlaceId`, 성공 코드 `201` → `201 / 200` | `PLC-016`, `PLC-017` |
| `API-PST-005` vs `API-CMU-001` | 정정 | 둘 다 `PST-035`·`CMU-002`에 매핑돼 어느 쪽을 쓸지 알 수 없었음 → **역할 분리**: `API-PST-005` = 지도·탐색(`PST-035`), `API-CMU-001` = 커뮤니티 인기 탭(`CMU-002`) | `PST-035`, `CMU-002` |
| `0. 개요` | 정정 | "원본 26행 중 tags/post_tags를 분리해 27개" → "데이터 설계 29개 테이블과 1:1 대응" | — |
| `API-EVT-001` | 정정 | `status`와 `includeEnded` 우선순위 미기재 → `status` 명시 시 우선, 정렬 규칙(진행 중 → 임박 → 예정 → 종료, 시작일 오름차순) 기재 | `EVT-005`, `EVT-006` |

#### 보강

| API ID | 구분 | 변경 전 → 변경 후 | 대응 요구사항 |
| --- | --- | --- | --- |
| `API-USER-008` | 신규 | `DeletionPreview.imageCount` 추가 | `USER-014` |
| `API-PLC-005` | 신규 | `PlaceDetail.viewCount` · `places.view_count` 추가 | `PLC-014` |
| ERD `tier_logs` | 신규 | `has_taken_coordinate` · `threshold_high_minutes` · `threshold_medium_days` 추가 | `PST-028` |
| `JOB-012` | 변경 | "보존기간은 운영 설정" → **90일 고정** | `NTF-014` |
| `API-SCH-001` | 신규 | `SearchResult.matchedRegion` 추가 — 지역 검색어를 필터 칩으로 전환할 근거 | `SCH-008` |
| `API-MAP-003` | 변경 | `period` 기본값 미표기 → 기본 `WEEK` 명시 | `MAP-022`, `MAP-023` |
| `API-BDG-002` | 신규 | 에러 `BADGE_NOT_FOUND` (404) | `BDG-013` |
| `API-CMU-013` | 신규 | 에러 `TAG_NOT_FOUND` (404) | `CMU-030` |
| `API-NTF-003` | 신규 | 에러 `NOTIFICATION_NOT_FOUND` (404) | `NTF-013` |
| `API-PST-001` | 변경 | `files` 제약 미기재 → `POST_IMAGE 1~4개 / PROFILE_IMAGE 1개`, `image/jpeg\|png\|heic\|webp`, 10MB 이하 | `PST-015` |
| `API-EVT-002` | 변경 | `radiusM` 최대 50,000이 장소 탐색 20km 기준과 충돌 → 별도 기준임을 명시 | `EVT-015`, `MAP-027` |
| `API-PST-002`, `API-PST-003` | 변경 | `takenAt` 선택 → `source=CAMERA`이면 필수 | `PST-023` |
| `4. 공통 규약` | 변경 | 신뢰 금지 필드에 **장소명 태그** 추가 (서버가 주입해 태그 최소 1개 보장) | `PLC-021`, `PST-004` |
| ERD `sigungu` | 신규 | 시군구 테이블 분리 | `PLC-002` |

### v1.1.1 (2026-09-01) · 데이터 설계 DBML v1.1.3 정합 9건

| API ID | 구분 | 변경 전 → 변경 후 | 대응 요구사항 |
| --- | --- | --- | --- |
| `API-USER-002` | 변경 | `bio` 최대 300자 → **200자** | `USER-003` (v1.1.3에서 요구사항에 역반영) |
| `API-PST-004`, `API-PST-005` | 변경 | `period` = `DAY\|WEEK\|MONTH\|ALL` → `HOURS_24\|WEEKLY\|MONTHLY\|ALL` | `PST-035` |
| `API-CMU-001` | 변경 | `period` = `WEEK\|MONTH` → `WEEKLY\|MONTHLY` | `CMU-007` |
| `API-RNK-001` | 변경 | `period` = `DAY\|WEEK\|MONTH\|ALL` → `DAILY\|WEEKLY\|MONTHLY\|ALL` | `RNK-004` |
| `API-MAP-001`, `API-MAP-003` | 변경 | `period` = `DAY\|WEEK\|MONTH` → `LAST_1H\|LAST_24H\|WEEKLY\|MONTHLY` (`region_stats`·`heatmap_cells`가 같은 enum 공유) | `MAP-005`, `MAP-011` |
| `API-ADM-003` | 변경 | `result` = `SUCCESS\|FAIL` → `SUCCESS\|FAIL\|PARTIAL` | `PLC-009` |
| `API-ADM-008` | 변경 | 경로 `/admin/regions/{regionId}/event-radius` → `/admin/regions/{areaCode}/event-radius` | `PLC-022` |
| 응답 스키마 전반 | 삭제 | `Region.regionId` · `Sigungu.sigunguId` · `EventRegionSummary.regionId` 제거, `areaCode`·`sigunguCode`를 `integer`로 통일 | `PLC-001`, `PLC-002` |
| `4. 공통 규약` | 변경 | 식별자 규약에 "내부 PK는 `bigint`, API는 불투명 string으로 노출" 명시 | `SYS-009` |
| ERD 전반 | 변경 | 대리키 PK 환원 — `tier_logs(tier_log_id)` · `heatmap_cells(cell_id)` · `place_rankings(ranking_id)` · `account_deletion_logs(log_id)` · `search_logs(log_id)`. `notifications`는 `dedupe_key` → 5컬럼 UNIQUE | `NTF-008` 외 |

### v1.1.3 (2026-09-01)

| API ID | 구분 | 변경 전 → 변경 후 | 대응 요구사항 |
| --- | --- | --- | --- |
| 전체 | 변경 | 표지 버전 `v1.1.1` → `v1.1.3`. **API 계약 변경 없음** — 세 문서 번호를 맞추기 위한 표기 변경 | — |

### v1.1.4 (2026-09-03) · 구현 정합

| API ID | 구분 | 변경 전 → 변경 후 | 대응 요구사항 |
| --- | --- | --- | --- |
| `API-PST-003` | 신규 | 요청 `images[].imageKey` 행 추가 — 배열 원소 구조가 정의돼 있지 않아 예시로만 유추해야 했다 | `PST-014` |
| `API-PST-003` | 신규 | 요청 `images[].sortOrder` 행 추가. **1부터**이며 중복 불가 | `PST-001` |
| `API-PST-003` | 신규 | 요청 `images[].aspectRatio` 행 추가 (`number\|null`, 선택). 후처리 전까지 값이 없어 클라이언트가 아는 값을 함께 받고, `JOB-003` 이 실제 값으로 덮어쓴다 | `PST-021` |
| `API-PST-003` | 신규 | 요청 `images[].imageHash` 행 추가 (`string\|null`, 선택, SHA-256 64자). 중복 409 를 등록 응답 전에 내리기 위한 값 | `PST-031` |
| `PostImage.sortOrder` | 정정 | 설명 `0부터 정렬 순서` → **`1부터 정렬 순서 (1~4)`** — 같은 명세의 `API-PST-003` 요청 예시가 `sortOrder:1` 이라 내부가 불일치했다 | `PST-001` |
| `4. 공통 규약` | 정정 | 식별자 규약에 `users 만 uuid` 예외 명시 | `SYS-009`, `AUTH-001` |
| `8. ERD 엔터티` | 정정 | `users` PK `user_id` → **`id (uuid)`** | `AUTH-001` |

---

## 변경 상세 — 데이터 설계 (테이블 기준)

요구사항 명세서 `6. 데이터 설계` 시트를 DBML v1.1.3(29개 테이블)에 맞춘 내역이다. 26개 → 29개.

| 테이블 | 구분 | 변경 전 → 변경 후 | 대응 요구사항 |
| --- | --- | --- | --- |
| `sigungu` | 신규 | `regions`에 섞여 있던 시군구를 분리. PK `(area_code, sigungu_code)` | `PLC-002`, `PLC-020` |
| `post_rankings` | 신규 | 기간별 게시글 인기 집계 테이블. PK `(post_id, period)` | `PST-035`, `CMU-002`, `CMU-008`, `CMU-009` |
| `tags` / `post_tags` | 변경 | 한 행에 묶여 있던 것을 두 테이블로 분리 | `PST-004`, `CMU-025`, `CMU-029` |
| `regions` | 변경 | `sigungu_code` 제거, `area_code` 단독 PK | `PLC-001`, `PLC-002` |
| `users` | 변경 | `role` · `upload_blocked_until` · `push_like_enabled` · `push_follow_enabled` · `push_badge_enabled` · `badge_count` 추가, `bio(200)` 명시 | `AUTH-014`, `PST-032`, `USER-003`, `USER-023` |
| `places` | 변경 | `view_count` · `sigungu_code` 추가 | `PLC-014`, `PLC-020` |
| `place_details` | 변경 | PK `place_id` → `(place_id, language_code)` | `SYS-012` |
| `tier_logs` | 변경 | `tier_log_id` PK, `has_taken_coordinate` · `applied_radius_m` · `threshold_high_minutes` · `threshold_medium_days` 추가 | `PST-028`, `PST-047`, `PST-049` |
| `heatmap_cells` | 변경 | `cell_id` PK, `sample_post_ids` · `last_posted_at` · `calculated_at` 추가, `period`는 롤링 윈도우 enum | `MAP-010`, `MAP-016`, `MAP-022` |
| `region_stats` | 변경 | `period`가 `heatmap_period`를 공유함을 명시 | `MAP-005` |
| `place_rankings` | 변경 | `ranking_id` PK + `UNIQUE(place_id, period, theme)` | `RNK-007`, `RNK-008` |
| `notifications` | 변경 | 중복 방지를 5컬럼 UNIQUE로, `target_type`을 `POST\|USER\|BADGE\|NONE` enum으로 | `NTF-008` |
| `account_deletion_logs` | 변경 | `log_id` PK | `USER-015` |
| `sync_logs` | 변경 | `result`에 `PARTIAL` 추가 | `PLC-009` |
| `search_logs` | 변경 | `log_id` PK. 최근 검색어 저장소는 미정으로 표기 | `SCH-010`, `SCH-011` |

### v1.1.4 (2026-09-03) · 구현 정합

요구사항 명세서 `6. 데이터 설계` 시트를 구현된 스키마(`V1`~`V9`)에 맞춘 내역이다.

| 테이블 | 구분 | 변경 전 → 변경 후 | 대응 요구사항 |
| --- | --- | --- | --- |
| `users` | 정정 | 식별자 `user_id`(bigint) → **`id`(uuid)**. 구글 OAuth 기반이라 순번을 노출하지 않고, 구현된 `V1__auth_schema.sql` 이 `uuid` 로 만든다 | `AUTH-001` |
| `places` | 신규 | 컬럼에 `status(ACTIVE/HIDDEN/DELETED)` 추가 — 장소 숨김 상태를 담을 곳이 없었다 | `PLC-023` |
| `reports` | 신규 | 컬럼에 `detail` · `action(KEEP/HIDE/DELETE)` · `reviewed_at` · `created_at` 추가 — 운영자 검토 결과를 담을 곳이 없었다. `status` 와 짝이 맞아야 하므로 DB CHECK 로 묶는다 | `SYS-017` |

> `8. ERD 엔터티` 시트에는 `places.status` 와 `reports` 보강 컬럼이 v1.1.3 시점에 이미 반영돼 있었다.
> 요구사항 쪽 `6. 데이터 설계` 시트만 뒤처져 있어 이번에 맞췄다.

---

### v1.1.5 (2026-09-05) · 지도 백엔드 구현 정합

| 대상 | 구분 | 변경 전 → 변경 후 | 근거 |
| --- | --- | --- | --- |
| `MAP-009`, `MAP-014`, `MAP-018` | 변경 | 격자 전환·폴백 기준·셀 한도 미정 → 줌 경계 4단계, 5건 미만 폴백, 상위 500셀·`truncated` | DEC-20260905-004 |
| `MAP-025` | 변경 | 썸네일 저장 구조 미정 → `sample_post_ids`와 정렬이 같은 `sample_thumbnail_urls` | DEC-20260905-005 |
| `MAP-028`, `MAP-029` | 변경 | 최근접 거리·비회원 인증값 표현 미정 → `nearestDistanceM`, 비회원 `isVerifiable=null` | DEC-20260905-006 |
| `API-MAP-002` | 변경 | 셀 초과 시 422 가능 → 상위 500셀 200 응답, `forceRefresh`는 응답 캐시만 우회 | MAP-015, MAP-018 |
| `API-MAP-003`, `API-MAP-004` | 변경 | 좌표 문자열 `cellKey` → 기간·격자·좌표 인덱스를 포함한 불투명 키 | MAP-017, MAP-020 |
| `API-PLC-004` | 변경 | 응답에 페이지 정보 없는 `cursor`·`size` 요청 → 거리순 최대 50개 고정, 두 파라미터 삭제 | MAP-026~MAP-030 |
| `NearbyPlaceResult` | 신규 | 최근접 거리 필드 없음 → 후보가 없을 때 `nearestDistanceM` 반환 | MAP-028 |
| `heatmap_cells` | 변경 | 후보 게시글 ID만 저장 → 동일 순서의 썸네일 URL 배열과 정수 좌표 인덱스 저장 | MAP-009, MAP-025 |
| `HeatmapCell.visitCount` | 정정 | 기간별 방문 원천 미구현인데 예시값 제공 → VST 구현 전까지 0 | DEC-20260905-007 |

### v1.1.5 데이터 설계 정본 교정 (2026-09-05)

요구사항·API 내용과 버전 번호는 바꾸지 않고, 사용자 제공 ERD를 최신 정본으로 다시 지정한 문서 교정이다. 아래 항목은 앞선 v1.1.4·v1.1.5 구현 정합 기록을 삭제하지 않고 데이터 설계 정본에서 되돌린다. 현재 Flyway·애플리케이션 구현은 이 교정으로 자동 변경되지 않는다.

| 대상 | 구분 | 변경 전 → 변경 후 | 근거 |
| --- | --- | --- | --- |
| 데이터 설계 테이블 수 | 정정 | 29개 및 부분 DBML 11개 → 사용자 제공 ERD에 실제 선언된 28개 | DEC-20260905-011 |
| `tier_logs` | 삭제 | 데이터 설계 정본 포함 → 최신 정본에서 의도적으로 제외 | DEC-20260905-011 |
| `heatmap_refresh_state` | 정정 | 부분 DBML에 정본 테이블처럼 포함 → 구현 보조 테이블로 분류하고 정본에서 제외 | DEC-20260905-011 |
| `users` | 정정 | `id uuid` → `user_id bigint` | 사용자 제공 ERD, DEC-20260905-011 |
| 22개 상태·종류 타입 | 정정 | 문자열과 CHECK 중심 → PostgreSQL native enum | 사용자 제공 ERD, DEC-20260905-011 |
| `places` | 정정 | 위·경도에서 생성한 `geom`, `status`, `updated_at` 포함 → nullable `geography(Point,4326)` 직접 저장, `has_coordinate` 유지, `status`·`updated_at` 제외 | 사용자 제공 ERD, DEC-20260905-011 |
| `posts.status` | 정정 | `ACTIVE/HIDDEN/DELETED` → `ACTIVE/BLINDED/DELETED` | 사용자 제공 ERD `post_status` |
| `post_images` | 정정 | `sort_order` 1~4와 `image_hash`·`created_at` → `sort_order` 0~3, 두 컬럼 제외 | 사용자 제공 ERD `post_images` |
| `heatmap_cells` | 정정 | 정수 좌표 인덱스·썸네일 URL 배열 포함 → 숫자형 중심 좌표와 JSON `sample_post_ids`만 유지 | 사용자 제공 ERD `heatmap_cells` |
| `region_stats` | 정정 | `representative_post_id`·`calculated_at` 포함 → 두 컬럼 제외 | 사용자 제공 ERD `region_stats` |
| `reports` | 정정 | `detail`·`action`·`reviewed_at` 포함 → `reason`·`status`·`created_at`만 유지 | 사용자 제공 ERD `reports` |
| `search_logs` | 정정 | 사용자별 최근 검색을 위한 `user_id` 포함 → 인기 검색어 집계용으로 `user_id` 제외 | 사용자 제공 ERD `search_logs` |
| `API-PST-003` | 정정 | 저장 테이블에 `tier_logs` 포함 → `posts`, `post_images`, `post_tags`, `visits`, `user_badges` | PST-001~032, DEC-20260905-011 |
| `API-PST-006` | 정정 | 상세 조회 저장 테이블에 `tier_logs` 포함 → `posts`, `post_images`, `post_tags`, `users`, `places` | PST-033, PST-042, PST-046~047, DEC-20260905-011 |
| `API-PST-002`, `API-PST-003`, `API-PST-006` | 정정 | `TierResult` 근거 저장소를 `tier_logs`로 표기 → `posts`·`places`와 요청 시 계산값으로 표기 | PST-022~028, PST-046~049, DEC-20260905-011 |
| 요구사항·API 명세 | 정정 | 데이터 설계 교정에 맞춰 버전 상승 필요 → 엔드포인트·요청·응답 계약은 유지하고 저장소 주석·ERD 시트만 교정해 v1.1.5 유지 | DEC-20260905-011 |

### v1.1.5 RNK 백엔드 구현 정합 (2026-09-05)

API 요청·응답 계약과 사용자 제공 28테이블 독립 SQL은 바꾸지 않는다. 아래 항목은 UUID 기반
애플리케이션 Flyway 스키마에 적용한 구현 확장이며, 정본과의 차이는 `05-erd-reference.md`에 남긴다.

| 대상 | 구분 | 변경 전 → 변경 후 | 근거 |
| --- | --- | --- | --- |
| `places` | 신규 | 운영자 지정 추천 저장소 미정 → 애플리케이션 V19에 `is_curated boolean` 추가 | RNK-013, DEC-20260905-017 |
| `place_rankings` | 신규 | 한 행에 지역·전체 장소 순위만 표현 → `scope(NATIONAL\|REGION)`와 `place_type(ALL\|OFFICIAL\|USER)` 집계 차원 추가 | RNK-002, RNK-003, RNK-006, DEC-20260905-018 |
| `JOB-008` | 변경 | 주기·진입 기준·동점 처리 미구현 → 기본 10분, 기간 내 활성 게시글 1개 이상, `score DESC, place_id ASC`로 집계 | RNK-007~RNK-010, DEC-20260905-018 |
| `API-RNK-001` | 변경 | 계약만 존재 → 전국·지역·기간·테마·장소 유형별 사전 집계 조회 구현 | RNK-001~RNK-010, DEC-20260905-017 |
| `API-RNK-002` | 변경 | 계약만 존재 → 주간 랭킹 무작위 보정·20km 위치 추천·`CURATED` 폴백 구현 | RNK-011~RNK-013, DEC-20260905-017~018 |
| `API-ADM-001` | 변경 | `RANKING_RECALC` 계약만 존재 → 비동기 수동 실행과 `batch_runs`·`sync_logs` 결과 기록 구현 | SYS-015, JOB-008 |

## 다음 예정

| 대상 | 내용 | 근거 |
| --- | --- | --- |
| DBML `users` | `terms_agreed_at` 추가 — 약관 동의가 Must인데 DBML에 컬럼이 없다 | `USER-006` |
| ~~DBML `places`~~ | `status` 추가 — **v1.1.4 완료** | `PLC-023` |
| ~~DBML `reports`~~ | `detail` · `action` · `reviewed_at` 추가 — **v1.1.4 완료** | `SYS-017` |
| 요구사항 `MAP-025` | `sample_post_ids`와 정렬이 같은 썸네일 URL 사전 저장 여부를 다시 결정 | 사용자 제공 ERD 미결정 9, DEC-20260905-011 |
| 요구사항 `SCH-011`, `VST-006` | 최근 검색어·최근 본 장소 저장소 결정 (앱 로컬 / Redis / DB) | DBML 미결정 10 |
| ~~요구사항 `RNK-013`~~ | 운영자 지정 장소 — 애플리케이션 V19의 `places.is_curated`로 **구현 완료**. 사용자 제공 독립 ERD 정본에는 포함하지 않음 | DEC-20260905-017 |
| 요구사항 `PST-043`, `PLC-023` | 신고 대상 범위에 댓글·사용자를 넣을지 | DBML 미결정 12 |
| 요구사항 `BDG-013` | `badges.earned_count` 비정규화 여부 | DBML 미결정 13 |
| 요구사항 `CMU-019` | 공유 주소에 `post_id` 노출 vs `posts.share_slug` | DBML 미결정 14 |

### v1.1.5 에서 결정할 것 (구현 중 드러남)

| 대상 | 내용 | 근거 |
| --- | --- | --- |
| 요구사항 `PST-032` | 업로드 정지를 어디에 저장할지 — DBML 은 `users.upload_blocked_until` 이지만 `users` 는 인증 담당 테이블이다. 별도 `upload_suspensions` 테이블도 후보다. `UploadSuspensionReader` 포트는 준비돼 있고 구현체만 갈아끼우면 된다 | 구현 보류 |
| `API-PST-003` | `Idempotency-Key 필수` 를 실제로 강제하려면 키 저장소가 필요하다. 현재는 중복 이미지 검사와 장소별 하루 한도가 부분 방어를 한다 | 구현 보류 |
| `API-PST-004`, `API-PST-005` | 요청 `placeId` 타입이 `uuid` 로 적혀 있으나 `places.place_id` 는 `bigint` 다. 응답은 불투명 string 으로 내보내는데 요청은 숫자를 받는 비대칭이 남아 있다 | 구현 정합 |
| 요구사항 `PST-042` | 조회수 24시간 중복 제거를 프로세스 메모리로 구현했다. 인스턴스가 늘면 최대 대수만큼 중복 집계된다. Redis(`SYS-019`) 도입 시 교체 | 구현 한계 |
| `JOB-013` | 분산 락이 없어 여러 인스턴스가 동시에 돌면 같은 기간 집계를 서로 지우고 넣는다. 현재는 `snaphere.jobs.enabled` 로 한 대만 켜서 회피한다 | 구현 한계 |

## 알려진 문제

| 위치 | 내용 |
| --- | --- |
| 요구사항 `0. 사용 안내` B52 | `기능 명세 남은 비고` 수식이 `COUNTA - COUNTBLANK` 조합이라 음수가 나온다. v1.1.0 이전부터 있던 문제이며 이번 버전에서 손대지 않았다 |
| 요구사항 `0. 사용 안내` B53 | `용어 사전 등재 수`도 같은 형태의 수식이다 |
