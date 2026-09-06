# 데이터 활용 공모전

FE, BE, AI, 문서를 하나의 Git 저장소에서 함께 관리하는 모노레포입니다.

## 폴더 구조

```text
.
├── frontend/      # 프론트엔드 애플리케이션
├── backend/       # 백엔드 API 서버
├── ai/            # AI 모델, 학습/추론 코드, 실험 자료
├── docs/          # 기획/설계/회의/API 문서
├── AGENTS.md      # 에이전트 협업·의사결정 기록 규칙
├── .gitignore     # 공통 Git 제외 규칙
└── README.md      # 프로젝트 개요
```

## 영역별 역할

### `frontend/`

사용자 화면, 클라이언트 상태 관리, API 연동 코드를 둡니다.

### `backend/`

서버 애플리케이션, API, DB 연동, 인증/인가, 배치 작업 등을 둡니다.

### `ai/`

데이터 전처리, 모델 학습, 추론 코드, 실험 기록, 모델 서빙 관련 코드를 둡니다.

대용량 데이터셋과 모델 파일은 Git에 직접 올리지 않고 외부 저장소나 Git LFS 사용을 권장합니다.

### `docs/`

요구사항, 기능 명세, API 명세, 아키텍처, 회의록, 발표 자료 등 프로젝트 문서를 둡니다.

## 프로젝트 관리 링크

- [Notion](https://app.notion.com/p/39848b75b1c08024939dd161044f2489)
- [1차 와이어프레임]
- [요구사항 명세서]
- [기능 명세서]


## Git 관리 규칙

이 프로젝트는 `main`, `develop`, 작업 브랜치를 사용합니다.

```text
main
└── develop
    ├── feature/frontend-login
    ├── fix/backend-jwt-expire
    └── docs/git-strategy
```

- 기능 개발은 `develop`에서 새 브랜치를 만들어 진행합니다.
- 작업이 끝나면 Merge Request를 만들고 `develop`에 merge합니다.
- 브랜치 이름은 `feature/frontend-login`처럼 작성합니다.
- 커밋 메시지는 `feat(frontend): 로그인 페이지 구현`처럼 작성합니다.

자세한 Git 전략은 [docs/09-git-strategy.md](09-git-strategy.md)를 참고합니다.

## 문서 목록

파일 이름 앞의 번호는 **읽는 순서**다. 새 문서를 넣을 때도 번호를 붙여 정렬이 흐트러지지 않게 한다.

| # | 문서 | 내용 |
| --- | --- | --- |
| 01 | [01-requirements-spec.md](01-requirements-spec.md) | 요구사항 명세서 — 291건, 대분류별 상세와 중요도 |
| 02 | [02-feature-spec.md](02-feature-spec.md) | 기능 명세서 — 화면 흐름과 페이지 전환 106항목 |
| 03 | [03-api-spec.md](03-api-spec.md) | API 명세서 — 97 엔드포인트·요청·응답·에러·배치·요구사항 추적 |
| 04 | [04-data-design.md](04-data-design.md) | 데이터 설계 — 테이블 29개, 설계 판단, 인덱스 |
| 05 | [05-erd-reference.md](05-erd-reference.md) | ERD 참조 — 엔터티 29개, 관계 49개, 삭제 정책 |
| 06 | [06-glossary.md](06-glossary.md) | 용어 사전 — 표시 용어와 DB·API 식별자 |
| 07 | [07-decision-log.md](07-decision-log.md) | 제품 미확정사항 및 구현 의사결정 이력 |
| 08 | [08-spec-changelog.md](08-spec-changelog.md) | 명세 변경 이력 — 버전별 변경 내역과 작성 규칙 |
| 09 | [09-git-strategy.md](09-git-strategy.md) | Git 브랜치 전략, 커밋·PR 규칙 |
| 11 | [11-db-engine-decision.md](11-db-engine-decision.md) | DB 엔진 결정 (Percona PostgreSQL 17.10.2 + PostGIS 3.6.2) |
| 12 | [12-db-schema.dbml](12-db-schema.dbml) | DB 스키마 — dbdiagram.io ERD 소스. 현재 게시글 도메인 8개 테이블 |
| 13 | [13-flutter-bootstrap-plan.md](13-flutter-bootstrap-plan.md) | Flutter 앱 초기 구성 계획 |
| — | [specs/](specs) | 스프레드시트 원본 (.xlsx) |

**번호 10은 비워 두었다.** 이미 머지된 `commit-convention.md` 를 `10-commit-convention.md` 로 옮길 자리다.
커밋 규칙을 참조하는 문서·PR 링크가 여러 곳에 있어 파일명 변경은 따로 처리한다.

`12-db-schema.dbml` 은 dbdiagram.io 에 그대로 붙여넣어 ERD 를 그릴 수 있다.
현재는 게시글 도메인 8개 테이블만 담겨 있고, 소셜·이벤트·뱃지·방문·집계·알림·운영 테이블은
각 담당 브랜치에서 같은 파일에 추가한다. 전체 28개 테이블 설계는 04·05번 문서가 정본이다.

## 에이전트 협업 의사결정

에이전트는 저장소 루트의 [`AGENTS.md`](../AGENTS.md)를 작업 규칙으로 사용한다. 플랜 모드 여부와 관계없이 사용자 결정과 에이전트 자동 결정을 [`07-decision-log.md`](07-decision-log.md)에 기록한다.

- 범위, 아키텍처, 운영 의존성·버전, 외부 연동, 보안, API·DB 계약에 영향을 주는 결정은 구현 전에 기록한다.
- 에이전트는 기존 범위 안의 되돌리기 쉬운 저위험 세부사항만 자동 결정할 수 있다.
- 범위 확대나 계약 변경처럼 중요한 선택은 사용자 확인 없이 구현하지 않는다.
- 결정으로 명세가 달라지면 [`08-spec-changelog.md`](08-spec-changelog.md)의 버전·근거 기록 규칙도 함께 적용한다.

## 명세서를 읽는 방법

01~03이 정본이다. `.md` 는 GitHub에서 바로 읽고 PR diff로 변경을 확인하기 위한 것이고,
편집은 `specs/` 의 스프레드시트에서 한 뒤 `.md` 를 다시 뽑는다. **`.md` 를 직접 고치지 않는다** — 다음 변환에서 덮어써진다.

세 문서는 **같은 버전 번호로 함께 올린다** (현재 v1.1.4). 규칙은 [08-spec-changelog.md](08-spec-changelog.md) 에 있다.
