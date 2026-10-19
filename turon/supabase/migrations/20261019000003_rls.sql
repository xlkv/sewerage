create function public.is_active_user() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and is_active)
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and is_active and role = 'admin')
$$;

alter table public.profiles enable row level security;
alter table public.masters  enable row level security;
alter table public.manholes enable row level security;
alter table public.pipes    enable row level security;

-- profiles: o'zini ko'radi; admin hammani ko'radi. Yozish faqat Edge Function (service role) orqali.
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());

-- masters, manholes, pipes: faol foydalanuvchi o'qiydi, admin yozadi
create policy masters_select  on public.masters  for select to authenticated using (public.is_active_user());
create policy masters_write   on public.masters  for all    to authenticated using (public.is_admin()) with check (public.is_admin());
create policy manholes_select on public.manholes for select to authenticated using (public.is_active_user());
create policy manholes_write  on public.manholes for all    to authenticated using (public.is_admin()) with check (public.is_admin());
create policy pipes_select    on public.pipes    for select to authenticated using (public.is_active_user());
create policy pipes_write     on public.pipes    for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- length_auto_m ni klient to'g'ridan-to'g'ri o'zgartira olmasin
revoke update (length_auto_m) on public.pipes from authenticated;

-- anon hech narsa ko'rmaydi
revoke all on public.profiles, public.masters, public.manholes, public.pipes from anon;
