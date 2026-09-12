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
