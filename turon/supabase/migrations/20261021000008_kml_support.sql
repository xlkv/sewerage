-- KML import support.
-- 1) Manhole codes are kept exactly as in the source data, so they may repeat.
alter table public.manholes drop constraint if exists manholes_code_key;
create index if not exists manholes_code_idx on public.manholes (code);

-- 2) Curved pipes: interior bend points between the two manholes,
--    as a JSON array of [lat, lng] pairs (null/[] = straight pipe).
alter table public.pipes
  add column if not exists path jsonb
  check (path is null or jsonb_typeof(path) = 'array');

-- 3) Auto length follows the path: from → bends → to.
create or replace function public.calc_pipe_length_path(a uuid, b uuid, bends jsonb)
returns numeric
language sql stable set search_path = public, extensions as $$
  with pts as (
    select 0 as ord, m.location::geometry as g from manholes m where m.id = a
    union all
    select e.ordinality::int,
           st_setsrid(st_makepoint((e.value->>1)::float8, (e.value->>0)::float8), 4326)
      from jsonb_array_elements(coalesce(bends, '[]'::jsonb)) with ordinality e
    union all
    select 1000000, m.location::geometry from manholes m where m.id = b
  )
  select round(st_length(st_makeline(g order by ord)::geography)::numeric, 2) from pts
$$;

create or replace function public.pipes_set_length() returns trigger
language plpgsql set search_path = public as $$
begin
  new.length_auto_m := coalesce(
    public.calc_pipe_length_path(new.from_manhole_id, new.to_manhole_id, new.path), 0);
  return new;
end $$;

create or replace function public.manholes_recalc_pipes() returns trigger
language plpgsql set search_path = public as $$
begin
  update public.pipes p
     set length_auto_m = public.calc_pipe_length_path(p.from_manhole_id, p.to_manhole_id, p.path)
   where p.from_manhole_id = new.id or p.to_manhole_id = new.id;
  return null;
end $$;
