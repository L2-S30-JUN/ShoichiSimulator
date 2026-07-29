-- ============================================================
-- 쇼이치 시뮬레이터 챌린지 랭킹 — Supabase 초기 설정
-- Supabase 대시보드 → SQL Editor에 붙여넣고 Run.
-- 여러 번 실행해도 안전하다 (이미 있는 항목은 건너뛰고 빠진 항목만 생성).
-- ============================================================

-- 기록 테이블
create table if not exists public.challenge_records (
  id bigint generated always as identity primary key,
  nickname text not null check (char_length(trim(nickname)) between 1 and 12),
  clear_ms integer not null check (clear_ms between 3000 and 3600000), -- 3초 미만·1시간 초과 기록 거부 (조작 1차 방어)
  created_at timestamptz not null default now()
);

-- 기존 DB 마이그레이션: 하한 10초 → 3초 (10초 미만 정상 기록이 등록 거부되던 문제 수정)
-- 인라인 check는 Postgres가 challenge_records_clear_ms_check 이름을 자동 부여한다.
alter table public.challenge_records drop constraint if exists challenge_records_clear_ms_check;
alter table public.challenge_records add constraint challenge_records_clear_ms_check
  check (clear_ms between 3000 and 3600000);

-- 랭킹 조회용 인덱스 (시간 오름차순 TOP N)
create index if not exists challenge_records_clear_ms_idx on public.challenge_records (clear_ms asc);

-- RLS: 익명(anon) 키로 읽기·추가만 허용, 수정·삭제는 불가
alter table public.challenge_records enable row level security;

drop policy if exists "anyone can read rankings" on public.challenge_records;
create policy "anyone can read rankings"
  on public.challenge_records for select
  using (true);

drop policy if exists "anyone can submit a record" on public.challenge_records;
create policy "anyone can submit a record"
  on public.challenge_records for insert
  with check (true);
-- update/delete 정책은 만들지 않는다 → anon 키로는 기존 기록을 건드릴 수 없음


-- ============================================================
-- 사이트 업데이트 내역 (로비 → '업데이트 내역')
-- 재배포 없이 Table Editor에서 행만 추가하면 사이트에 바로 반영된다.
-- ============================================================
create table if not exists public.site_updates (
  id bigint generated always as identity primary key,
  ver text not null,                      -- 'v1.8' 처럼 표시할 버전 문구
  released_on date,                       -- 비워두면 날짜를 표시하지 않는다
  video_url text,                         -- 유튜브 등 주소. 비우면 '▶ 영상 보기' 링크가 생기지 않는다
  body text not null default '',          -- 한 줄 = 항목 하나. '-' 로 시작하면 바로 위 항목의 하위 항목
  published boolean not null default true,-- false로 두면 사이트에 노출되지 않는다 (초안)
  sort_key integer not null default 0,    -- 클수록 위. 같으면 나중에 추가한 행(id 큰 쪽)이 위로 온다
  created_at timestamptz not null default now()
);

-- 목록 조회용 인덱스 (sort_key 내림차순 → id 내림차순)
create index if not exists site_updates_order_idx on public.site_updates (sort_key desc, id desc);

-- RLS: anon 키로는 읽기만 가능. 작성·수정·삭제는 대시보드(service_role)에서만.
alter table public.site_updates enable row level security;

drop policy if exists "anyone can read updates" on public.site_updates;
create policy "anyone can read updates"
  on public.site_updates for select
  using (published);
-- insert/update/delete 정책 없음 → anon 키로는 패치노트를 위조할 수 없다

-- 초기 데이터 (한 번만 넣는다 — 이미 행이 있으면 건너뜀)
insert into public.site_updates (ver, released_on, video_url, body)
select * from (values
  ('v1.7', null::date, 'https://www.youtube.com/watch?v=eUCUH4sENAM',
   '자세한 변경 내용은 영상으로 확인해주세요'),
  ('v1.8', date '2026-07-26', null,
   E'''쇼이치 클래식'' 모드 추가\n- 궁 시전시간 0.6초 (선딜 0.15 + 후딜 0.45초)\n- 패시브 최대 6스택 옵션\n- 패시브 스택 저장 — 최대 9스택 (6스택 옵션 시 11스택)\n- 패시브 단검이 적중하면 스택 획득\n3D 시뮬레이터(실험) 로비 버튼 추가\n3D 화면 배율을 exe 전체화면과 동일하게 수정')
) as v(ver, released_on, video_url, body)
where not exists (select 1 from public.site_updates);


-- ============================================================
-- 사이트 문구 설정 (site_config)
-- 재배포 없이 이 표의 value만 고치면 사이트 문구가 바뀐다.
-- ============================================================
-- 쓰는 곳:
--   season_name       현재 시즌 이름. 로비 '랭킹' 모달 제목에 붙는다
--   update_link_text  로비의 업데이트 내역 링크 문구. '{ver}' 자리에 최신 버전이 들어간다
--                     (예: '쇼이치 시뮬레이터 {ver} 업데이트 내역' → '쇼이치 시뮬레이터 v1.9 업데이트 내역')
--   hof_title         명예의 전당 모달 제목
-- 값을 빈 문자열로 두면 셸이 내장 기본값을 쓴다 — 실수로 비워도 문구가 사라지지 않는다.
create table if not exists public.site_config (
  key text primary key,
  value text not null default '',
  note text,                              -- 이 값이 어디에 쓰이는지 메모 (사이트는 읽지 않는다)
  updated_at timestamptz not null default now()
);

alter table public.site_config enable row level security;

drop policy if exists "anyone can read site config" on public.site_config;
create policy "anyone can read site config"
  on public.site_config for select
  using (true);
-- insert/update/delete 정책 없음 → anon 키로는 문구를 위조할 수 없다

-- 기본 문구 (이미 있는 키는 건드리지 않는다 — 대시보드에서 고친 값을 덮어쓰지 않기 위해)
insert into public.site_config (key, value, note) values
  ('season_name',      '시즌 2',                            '로비 랭킹 모달 제목에 붙는 현재 시즌 이름'),
  ('update_link_text', '쇼이치 시뮬레이터 {ver} 업데이트 내역', '{ver} 자리에 site_updates의 최신 ver이 들어간다'),
  ('hof_title',        '명예의 전당',                        '명예의 전당 모달 제목')
on conflict (key) do nothing;


-- ============================================================
-- 명예의 전당 (hall_of_fame) — 마감된 시즌의 TOP 10 보존
-- ============================================================
-- challenge_records는 "현재 시즌"만 담는다. 시즌을 마감할 때 그 시점의 TOP 10을 여기로
-- 옮겨 적고 challenge_records를 비운다 (아래 '시즌 마감 절차' 참고).
-- 순위·닉네임·기록을 그 시점 그대로 박제하므로, 나중에 랭킹 규칙이 바뀌어도 흔들리지 않는다.
create table if not exists public.hall_of_fame (
  id bigint generated always as identity primary key,
  season integer not null,                -- 1, 2, 3 ...
  season_name text not null default '',   -- 비우면 사이트가 '시즌 N'으로 표시한다
  rank integer not null check (rank >= 1),
  nickname text not null,
  clear_ms integer not null,
  recorded_at timestamptz,                -- 원래 기록이 등록된 시각 (challenge_records.created_at)
  archived_at timestamptz not null default now(),
  unique (season, rank)
);

create index if not exists hall_of_fame_order_idx on public.hall_of_fame (season desc, rank asc);

alter table public.hall_of_fame enable row level security;

drop policy if exists "anyone can read hall of fame" on public.hall_of_fame;
create policy "anyone can read hall of fame"
  on public.hall_of_fame for select
  using (true);
-- insert/update/delete 정책 없음 → 지난 시즌 기록은 anon 키로 건드릴 수 없다


-- ============================================================
-- 시즌 마감 절차 (시즌 1 → 시즌 2)
-- ============================================================
-- ⚠ 아래 블록은 challenge_records를 **비운다**. 되돌릴 수 없다.
--   위의 create/insert 문과 달리 "여러 번 실행해도 안전"하지 않으므로 한 번만 실행할 것.
--   (on conflict do nothing + 아래 not exists 가드로 두 번째 실행은 아무 일도 하지 않지만,
--    새 시즌 기록이 쌓인 뒤에 다시 돌리면 그 기록이 지워진다.)
--
-- 실행 전 확인: 아래 select로 박제될 10명을 눈으로 보고 나서 do 블록을 돌리는 것을 권한다.
--   select distinct on (nickname) nickname, clear_ms, created_at
--     from public.challenge_records order by nickname, clear_ms asc, created_at asc;
do $$
begin
  -- 이미 시즌 1을 박제했다면 통째로 건너뛴다 (실수로 두 번 돌려 기록을 날리는 것 방지)
  if exists (select 1 from public.hall_of_fame where season = 1) then
    raise notice '시즌 1은 이미 명예의 전당에 있습니다 — 건너뜁니다';
    return;
  end if;

  -- 닉네임당 최고 기록 1개만 추린 뒤(도배 방지 — challenge_best 뷰와 같은 규칙) 상위 10명을 박제
  insert into public.hall_of_fame (season, season_name, rank, nickname, clear_ms, recorded_at)
  select 1,
         '시즌 1',
         row_number() over (order by clear_ms asc, created_at asc),
         nickname,
         clear_ms,
         created_at
  from (
    select distinct on (nickname) nickname, clear_ms, created_at
    from public.challenge_records
    order by nickname, clear_ms asc, created_at asc
  ) best
  order by clear_ms asc, created_at asc
  limit 10;

  -- 시즌 2 시작 — 현재 시즌 기록을 비운다
  delete from public.challenge_records;

  raise notice '시즌 1 마감 완료. 명예의 전당 % 명 등재, 현재 랭킹 초기화',
    (select count(*) from public.hall_of_fame where season = 1);
end $$;


-- ============================================================
-- 참고: challenge_best 뷰
-- ============================================================
-- 사이트의 현재 시즌 랭킹은 이 뷰를 읽는다 (닉네임당 최고 기록 1개 = 도배 방지).
-- 이 뷰는 원래 대시보드에서 직접 만들어져 이 파일에 없었다. 위 마감 절차가 같은 규칙을
-- 쓰므로, 규칙이 한 곳에만 적혀 있지 않도록 여기에도 남겨 둔다.
-- ⚠ 이미 뷰가 있다면 아래를 실행할 필요가 없다. 실행하려면 컬럼 구성이 같아야 하고,
--   다르면 create or replace가 실패하므로 그때만 drop view 후 다시 만들 것.
-- create or replace view public.challenge_best as
--   select distinct on (nickname) nickname, clear_ms, created_at
--     from public.challenge_records
--    order by nickname, clear_ms asc, created_at asc;
