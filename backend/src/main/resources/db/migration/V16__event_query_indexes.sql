-- SnapHere V16 — 이벤트 홈 조회 인덱스
-- 요구사항: EVT-005, EVT-006, EVT-007, EVT-008
-- 테이블 자체는 V11__place_features.sql 이 이미 만들었다. 여기서는 조회 경로만 연다.

-- 첫 화면 목록은 정렬 그룹을 계산해 (그룹, 시작일, event_id) 로 훑는다 (EVT-005). 그룹은
-- start_date·end_date 에서 파생되므로 인덱스는 두 날짜로 건다. 시도 필터(EVT-007)가 함께 오는
-- 경우가 잦아 area_code 를 앞에 둔 인덱스도 따로 둔다 — 전국 조회는 아래 date 인덱스를 쓴다.
create index if not exists idx_events_period
    on events (start_date, end_date, event_id)
    where status = 'ACTIVE';

create index if not exists idx_events_area_period
    on events (area_code, start_date, end_date, event_id)
    where status = 'ACTIVE';

-- 시도별 요약은 진행·예정(end_date >= today)만 세고 created_at 으로 신규를 가른다 (EVT-008).
create index if not exists idx_events_area_created
    on events (area_code, created_at desc)
    where status = 'ACTIVE';

comment on index idx_events_period is
'이벤트 홈 전국 목록. 부분 인덱스라 숨긴 행사는 인덱스에 들어가지 않는다 (EVT-005)';
comment on index idx_events_area_period is
'시도 필터가 걸린 이벤트 홈 목록 (EVT-007)';
comment on index idx_events_area_created is
'시도별 신규 행사 수·최근 적재 시각 (EVT-008)';
