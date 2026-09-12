-- Supabase SQL Editor에서 새 프로젝트에 한 번 실행하세요.
begin;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check(char_length(name) between 1 and 40),
 grade text not null default '' check(char_length(grade)<=30),
 role text not null default 'student' check(role in ('student','admin')),
 start_date date,
 created_at timestamptz not null default now()
);
create or replace function public.is_center_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin') $$;
revoke all on function public.is_center_admin() from public;
grant execute on function public.is_center_admin() to authenticated;
create table public.progress (
 student_id uuid not null references public.profiles(id) on delete cascade,
 day integer not null check(day between 1 and 40),
 checks boolean[] not null default array[false,false,false,false]
   check(cardinality(checks)=4 and array_ndims(checks)=1 and array_lower(checks,1)=1 and array_position(checks,null) is null),
 correct integer check(correct between 0 and 1000),
 total integer check(total between 0 and 1000),
 minutes integer check(minutes between 0 and 1440),
 study_date date,
 note text not null default '' check(char_length(note)<=3000),
 updated_at timestamptz not null default now(),
 primary key(student_id,day),
 check((correct is null and total is null) or (correct is not null and total is not null and correct<=total))
);
create table public.lecture_links (
 lecture integer primary key check(lecture between 1 and 70),
 url text not null default '' check(char_length(url)<=3000 and (url='' or url ~ '^https://[^[:space:]]+$'))
);
alter table public.profiles enable row level security;
alter table public.progress enable row level security;
alter table public.lecture_links enable row level security;
revoke all on public.profiles,public.progress,public.lecture_links from anon,authenticated;
grant select on public.profiles to authenticated;
grant select,insert,update on public.progress,public.lecture_links to authenticated;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid() or public.is_center_admin());
create policy progress_read on public.progress for select to authenticated using(student_id=auth.uid() or public.is_center_admin());
create policy progress_insert on public.progress for insert to authenticated with check(student_id=auth.uid() and exists(select 1 from public.profiles where id=auth.uid() and role='student'));
create policy progress_update on public.progress for update to authenticated using(student_id=auth.uid()) with check(student_id=auth.uid() and exists(select 1 from public.profiles where id=auth.uid() and role='student'));
create policy links_read on public.lecture_links for select to authenticated using(exists(select 1 from public.profiles where id=auth.uid()));
create policy links_insert on public.lecture_links for insert to authenticated with check(public.is_center_admin());
create policy links_update on public.lecture_links for update to authenticated using(public.is_center_admin()) with check(public.is_center_admin());
commit;
