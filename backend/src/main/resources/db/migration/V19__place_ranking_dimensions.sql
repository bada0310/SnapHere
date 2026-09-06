-- SnapHere V19 — RNK-001~RNK-013 장소 랭킹·추천
--
-- 한 장소는 같은 기간·테마에서 전국 순위와 지역 순위가 다르고, 전체 장소 순위와
-- OFFICIAL/USER 전용 순위도 다르다. scope와 place_type은 그 집계 차원을 저장한다.

alter table places
    add column is_curated boolean not null default false;

comment on column places.is_curated is
'추천 데이터가 없을 때 노출할 운영자 지정 장소 (RNK-013)';

create index idx_places_curated
    on places (area_code, place_id)
    where status = 'ACTIVE' and is_curated = true;

alter table place_rankings
    add column scope varchar(20) not null default 'REGION',
    add column place_type varchar(20) not null default 'ALL';

alter table place_rankings
    drop constraint place_rankings_place_id_period_theme_key,
    add constraint uk_place_rankings_dimension
        unique (place_id, period, theme, scope, place_type),
    add constraint ck_place_rankings_period
        check (period in ('DAILY', 'WEEKLY', 'MONTHLY', 'ALL')),
    add constraint ck_place_rankings_scope
        check (scope in ('NATIONAL', 'REGION')),
    add constraint ck_place_rankings_place_type
        check (place_type in ('ALL', 'OFFICIAL', 'USER')),
    add constraint ck_place_rankings_score check (score >= 0),
    add constraint ck_place_rankings_rank check (rank_no > 0),
    add constraint ck_place_rankings_previous_rank
        check (previous_rank is null or previous_rank > 0);

create index idx_place_rankings_national
    on place_rankings (period, theme, place_type, rank_no, place_id)
    where scope = 'NATIONAL';

create index idx_place_rankings_region
    on place_rankings (area_code, period, theme, place_type, rank_no, place_id)
    where scope = 'REGION';
