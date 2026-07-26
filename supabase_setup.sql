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
