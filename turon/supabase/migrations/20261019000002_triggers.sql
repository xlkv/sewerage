-- updated_at
create function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

create trigger trg_profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger trg_masters_touch  before update on public.masters  for each row execute function public.touch_updated_at();
create trigger trg_manholes_touch before update on public.manholes for each row execute function public.touch_updated_at();
create trigger trg_pipes_touch    before update on public.pipes    for each row execute function public.touch_updated_at();

-- Ikki kolodets orasidagi masofa (metr, 2 xona)
create function public.calc_pipe_length(a uuid, b uuid) returns numeric
language sql stable set search_path = public, extensions as $$
  select round(st_distance(m1.location, m2.location)::numeric, 2)
  from manholes m1, manholes m2 where m1.id = a and m2.id = b
$$;

-- Quvur yaratilganda / uchlari o'zgarganda — avto uzunlik
create function public.pipes_set_length() returns trigger language plpgsql as $$
begin
  new.length_auto_m := coalesce(public.calc_pipe_length(new.from_manhole_id, new.to_manhole_id), 0);
  return new;
end $$;
create trigger trg_pipes_length
  before insert or update on public.pipes
  for each row execute function public.pipes_set_length();

-- Kolodets surilganda — ulangan quvurlar avto uzunligi (length_manual_m ga tegilmaydi)
create function public.manholes_recalc_pipes() returns trigger language plpgsql as $$
begin
  update public.pipes p
     set length_auto_m = public.calc_pipe_length(p.from_manhole_id, p.to_manhole_id)
   where p.from_manhole_id = new.id or p.to_manhole_id = new.id;
  return null;
end $$;
create trigger trg_manholes_moved
  after update of lat, lng on public.manholes
  for each row when (old.lat is distinct from new.lat or old.lng is distinct from new.lng)
  execute function public.manholes_recalc_pipes();
