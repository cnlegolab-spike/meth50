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
