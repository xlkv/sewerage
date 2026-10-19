alter function public.touch_updated_at() set search_path = public;
alter function public.pipes_set_length() set search_path = public;
alter function public.manholes_recalc_pipes() set search_path = public;
revoke execute on function public.is_admin(), public.is_active_user() from anon, public;
grant execute on function public.is_admin(), public.is_active_user() to authenticated;
