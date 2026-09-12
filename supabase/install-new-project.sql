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

begin;
alter table public.progress add column if not exists mistakes jsonb not null default '[]'::jsonb;
do $$ declare item record; begin
 for item in select conname from pg_constraint where conrelid='public.progress'::regclass and contype='c' and pg_get_constraintdef(oid) like '%correct%' and pg_get_constraintdef(oid) like '%total%' loop
  execute format('alter table public.progress drop constraint %I',item.conname);
 end loop;
end $$;
alter table public.progress add constraint progress_optional_correct_check check(correct is null or (total is not null and correct<=total));
alter table public.progress add constraint progress_mistakes_array_check check(jsonb_typeof(mistakes)='array');
create or replace function public.delete_center_student(target_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.is_center_admin() then raise exception '관리자만 학생을 삭제할 수 있습니다.' using errcode='42501'; end if;
 perform 1 from public.profiles where id=target_id and role='student' for update;
 if not found then raise exception '삭제할 학생을 찾을 수 없습니다.'; end if;
 delete from auth.users where id=target_id;
end $$;
revoke all on function public.delete_center_student(uuid) from public,anon;
grant execute on function public.delete_center_student(uuid) to authenticated;
commit;

begin;
create or replace function public.center_ranking() returns jsonb
language sql stable security definer set search_path='' as $$
with stats as (
 select p.id,p.name,p.created_at,
 coalesce(sum((select count(*) from unnest(g.checks) v where v)),0)::integer as checked,
 count(g.day) filter(where g.checks=array[true,true,true,true])::integer as completed
 from public.profiles p left join public.progress g on g.student_id=p.id
 where p.role='student' group by p.id,p.name,p.created_at
), ranked as (
 select *,dense_rank() over(order by checked desc,completed desc) as place from stats
)
select coalesce(jsonb_agg(jsonb_build_object(
 'rank',place,
 'name',case when char_length(name)<=1 then '*' when char_length(name)=2 then left(name,1)||'*' else left(name,1)||repeat('*',char_length(name)-2)||right(name,1) end,
 'percent',round(checked*100.0/160,1),'completed',completed,'finished',completed=40
) order by checked desc,completed desc,created_at,id),'[]'::jsonb) from ranked;
$$;
revoke all on function public.center_ranking() from public;
grant execute on function public.center_ranking() to anon,authenticated;
create or replace function public.set_my_start_date(new_date date) returns date
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception '로그인이 필요합니다.' using errcode='42501'; end if;
 if new_date is null or new_date not between date '2000-01-01' and date '2100-12-31' then raise exception '시작일을 확인하세요.'; end if;
 update public.profiles set start_date=new_date where id=auth.uid() and role='student';
 if not found then raise exception '학생 계정만 시작일을 선택할 수 있습니다.' using errcode='42501'; end if;
 return new_date;
end $$;
revoke all on function public.set_my_start_date(date) from public,anon;
grant execute on function public.set_my_start_date(date) to authenticated;
commit;

-- 새 프로젝트에서 schema.sql, update-student-features.sql, ranking-and-dates.sql 다음 실행
begin;
alter table public.profiles add column plan_days integer not null default 50 check(plan_days in (50,60,70,80));
alter table public.progress drop constraint progress_day_check;
alter table public.progress add column plan_days integer not null default 50 check(plan_days in (50,60,70,80));
alter table public.progress add constraint progress_day_check check(day between 1 and plan_days);
alter table public.progress drop constraint progress_pkey;
alter table public.progress add primary key(student_id,plan_days,day);
alter table public.lecture_links drop constraint lecture_links_lecture_check;
alter table public.lecture_links add constraint lecture_links_lecture_check check(lecture between 1 and 80);

create or replace function public.set_my_study_plan(new_date date,new_days integer) returns void
language plpgsql security definer set search_path='' as $$
begin
 if new_days is null or new_days not in (50,60,70,80) then raise exception '수업계획을 확인하세요.'; end if;
 if new_date is null or new_date not between date '2000-01-01' and date '2100-12-31' then raise exception '시작일을 확인하세요.'; end if;
 update public.profiles set start_date=new_date,plan_days=new_days where id=auth.uid() and role='student';
 if not found then raise exception '학생 로그인이 필요합니다.' using errcode='42501'; end if;
end $$;
revoke all on function public.set_my_study_plan(date,integer) from public,anon;
grant execute on function public.set_my_study_plan(date,integer) to authenticated;

create or replace function public.center_ranking() returns jsonb
language sql stable security definer set search_path='' as $$
with stats as (
 select p.id,p.name,p.created_at,p.plan_days,
 coalesce(sum((select count(*) from unnest(g.checks) v where v)),0)::integer as checked,
 count(g.day) filter(where g.checks=array[true,true,true,true])::integer as completed
 from public.profiles p left join public.progress g on g.student_id=p.id and g.plan_days=p.plan_days
 where p.role='student' group by p.id,p.name,p.created_at,p.plan_days
), ranked as (
 select *,dense_rank() over(order by round(checked*100.0/(plan_days*4),1) desc,completed desc) as place from stats
)
select coalesce(jsonb_agg(jsonb_build_object(
 'rank',place,'plan_days',plan_days,
 'name',case when char_length(name)<=1 then '*' when char_length(name)=2 then left(name,1)||'*' else left(name,1)||repeat('*',char_length(name)-2)||right(name,1) end,
 'percent',round(checked*100.0/(plan_days*4),1),'completed',completed,'finished',completed=plan_days
) order by place,created_at,id),'[]'::jsonb) from ranked;
$$;
revoke all on function public.center_ranking() from public;
grant execute on function public.center_ranking() to anon,authenticated;
commit;

