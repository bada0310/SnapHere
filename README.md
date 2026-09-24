# Sub Project 1

> **문제 정의 · 기술 의사결정 · 트러블슈팅**은 포트폴리오에 정리했습니다 → **[https://sungeun-portfolio.vercel.app/projects/snaphere](https://sungeun-portfolio.vercel.app/projects/snaphere)**

FE, BE, 문서를 하나의 Git 저장소에서 함께 관리하는 모노레포입니다.

## 폴더 구조

```text
.
├── frontend/      # 프론트엔드 애플리케이션
├── backend/       # 백엔드 API 서버            
├── docs/          # 기획/설계/회의/API 문서
├── .gitignore     # 공통 Git 제외 규칙
└── README.md      # 프로젝트 개요
```

## 영역별 역할

### `frontend/`

사용자 화면, 클라이언트 상태 관리, API 연동 코드를 둡니다.

### `backend/`

서버 애플리케이션, API, DB 연동, 인증/인가, 배치 작업 등을 둡니다.

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

자세한 Git 전략은 [docs/git-strategy.md](docs/git-strategy.md)를 참고합니다.
