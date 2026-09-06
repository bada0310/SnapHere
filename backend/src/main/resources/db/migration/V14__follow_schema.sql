create table follows (
    follower_id uuid not null references users(id) on delete cascade,
    following_id uuid not null references users(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (follower_id, following_id),
    constraint ck_follows_not_self check (follower_id <> following_id)
);
create index idx_follows_following_created on follows (following_id, created_at desc, follower_id desc);
create index idx_follows_follower_created on follows (follower_id, created_at desc, following_id desc);
