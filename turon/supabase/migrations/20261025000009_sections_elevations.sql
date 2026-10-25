-- 1) Elevations (Baltic system, metres). Depth is derived from them.
alter table public.manholes
  add column if not exists ground_elev numeric(8,2),
  add column if not exists invert_elev numeric(8,2);
alter table public.manholes
  add constraint manholes_elev_order
  check (ground_elev is null or invert_elev is null or ground_elev > invert_elev);

create or replace function public.manholes_depth_from_elev() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.ground_elev is not null and new.invert_elev is not null then
    new.height_m := round(new.ground_elev - new.invert_elev, 2);
  end if;
  return new;
end $$;
create trigger trg_manholes_depth
  before insert or update of ground_elev, invert_elev on public.manholes
  for each row execute function public.manholes_depth_from_elev();

-- 2) Sections (uchastkalar): a set of pipes/manholes with files.
create table public.sections (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(trim(name)) between 1 and 120),
  note        text check (note is null or length(note) <= 2000),
  status      public.work_status not null default 'planned',
  start_date  date,
  end_date    date,
  created_by  uuid references auth.users(id) default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint sections_dates check (end_date is null or start_date is null or end_date >= start_date)
);
create trigger trg_sections_touch before update on public.sections
  for each row execute function public.touch_updated_at();

create table public.section_pipes (
  section_id uuid not null references public.sections(id) on delete cascade,
  pipe_id    uuid not null references public.pipes(id) on delete cascade,
  primary key (section_id, pipe_id)
);
create table public.section_manholes (
  section_id uuid not null references public.sections(id) on delete cascade,
  manhole_id uuid not null references public.manholes(id) on delete cascade,
  primary key (section_id, manhole_id)
);
create table public.section_files (
  id          uuid primary key default gen_random_uuid(),
  section_id  uuid not null references public.sections(id) on delete cascade,
  name        text not null,
  path        text not null unique,
  mime        text,
  size_bytes  bigint,
  created_by  uuid references auth.users(id) default auth.uid(),
  created_at  timestamptz not null default now()
);
create index section_pipes_pipe_idx on public.section_pipes (pipe_id);
create index section_manholes_manhole_idx on public.section_manholes (manhole_id);
create index section_files_section_idx on public.section_files (section_id);

alter table public.sections enable row level security;
alter table public.section_pipes enable row level security;
alter table public.section_manholes enable row level security;
alter table public.section_files enable row level security;

create policy sections_select on public.sections for select to authenticated using (public.is_active_user());
create policy sections_write  on public.sections for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy section_pipes_select on public.section_pipes for select to authenticated using (public.is_active_user());
create policy section_pipes_write  on public.section_pipes for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy section_manholes_select on public.section_manholes for select to authenticated using (public.is_active_user());
create policy section_manholes_write  on public.section_manholes for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy section_files_select on public.section_files for select to authenticated using (public.is_active_user());
create policy section_files_write  on public.section_files for all to authenticated using (public.is_admin()) with check (public.is_admin());
revoke all on public.sections, public.section_pipes, public.section_manholes, public.section_files from anon;

alter publication supabase_realtime add table
  public.sections, public.section_pipes, public.section_manholes, public.section_files;

-- 3) Private storage for section drawings (PNG/JPEG/PDF, ≤ 50 MB).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('section-files', 'section-files', false, 52428800,
        array['application/pdf', 'image/png', 'image/jpeg'])
on conflict (id) do nothing;

create policy section_files_read on storage.objects for select to authenticated
  using (bucket_id = 'section-files' and public.is_active_user());
create policy section_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'section-files' and public.is_admin());
create policy section_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'section-files' and public.is_admin());

-- 4) Insert a manhole on a pipe: splits the pipe in two (flow direction,
--    diameter, status, note and section membership are kept). Runs with the
--    caller's rights, so RLS allows it for admins only.
--    p_path_a: bends from the pipe's start to the new manhole,
--    p_path_b: bends from the new manhole to the pipe's end ([[lat,lng],...]).
create or replace function public.split_pipe(
  p_pipe uuid, p_lat float8, p_lng float8,
  p_path_a jsonb default '[]', p_path_b jsonb default '[]', p_code text default null
) returns uuid
language plpgsql set search_path = public as $$
declare
  p public.pipes%rowtype;
  m_id uuid;
  new_pipe uuid;
begin
  select * into p from public.pipes where id = p_pipe for update;
  if not found then
    raise exception 'pipe % not found', p_pipe;
  end if;

  insert into public.manholes (lat, lng, status, code)
  values (p_lat, p_lng, p.status,
          coalesce(nullif(trim(p_code), ''), 'K-' || nextval('public.manhole_code_seq')))
  returning id into m_id;

  insert into public.pipes (from_manhole_id, to_manhole_id, diameter_mm, status, note, path)
  values (m_id, p.to_manhole_id, p.diameter_mm, p.status, p.note,
          nullif(coalesce(p_path_b, '[]'::jsonb), '[]'::jsonb))
  returning id into new_pipe;

  update public.pipes
     set to_manhole_id = m_id,
         path = nullif(coalesce(p_path_a, '[]'::jsonb), '[]'::jsonb),
         length_manual_m = null
   where id = p_pipe;

  insert into public.section_pipes (section_id, pipe_id)
  select section_id, new_pipe from public.section_pipes where pipe_id = p_pipe;
  insert into public.section_manholes (section_id, manhole_id)
  select section_id, m_id from public.section_pipes where pipe_id = p_pipe;

  return m_id;
end $$;
revoke execute on function public.split_pipe(uuid, float8, float8, jsonb, jsonb, text) from public, anon;
grant execute on function public.split_pipe(uuid, float8, float8, jsonb, jsonb, text) to authenticated;
