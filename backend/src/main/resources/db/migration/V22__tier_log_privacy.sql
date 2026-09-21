alter table tier_logs add column if not exists days_since_taken bigint;

alter table tier_logs drop column if exists taken_at;

comment on column tier_logs.days_since_taken is
'등급 판정 당시 촬영 후 경과일. 정확한 촬영 시각은 보관하지 않는다.';
