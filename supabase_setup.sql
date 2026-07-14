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
