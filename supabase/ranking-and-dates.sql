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
