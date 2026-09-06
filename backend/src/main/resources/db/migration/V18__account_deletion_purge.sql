-- USER-015~019: 탈퇴 유예가 끝난 게시글의 익명 소유자.
-- 이 계정은 로그인할 수 없고(profile API는 ACTIVE만 노출), FK를 유지하면서 작성자 개인정보만 끊는다.
insert into users (
    id, google_subject, email, nickname, status, role, onboarding_completed,
    locale, push_like_enabled, push_follow_enabled, push_badge_enabled,
    created_at, updated_at
) values (
    '00000000-0000-0000-0000-000000000001', 'system:deleted-author',
    'deleted-author@snaphere.local', '탈퇴한 사용자', 'SUSPENDED', 'USER', true,
    'ko-KR', false, false, false, now(), now()
) on conflict (id) do nothing;
