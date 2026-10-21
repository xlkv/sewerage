"""Builds one transactional SQL import from kml_import.py's JSON output.

- removes the old demo network (note = 'demo') and orphaned history,
- inserts manholes (names exactly as in KML) and curved pipes (Ø200 default),
- replaces trigger-made history with the simulated construction timeline,
- moves the manhole code sequence past the imported K-numbers.

usage: python3 -I kml_import_sql.py import.json out.sql [--note "KML: Kh"]
"""
import sys

src, out = sys.argv[1], sys.argv[2]
note = "KML import"
if "--note" in sys.argv:
    note = sys.argv[sys.argv.index("--note") + 1]
payload = open(src).read()
assert "$kml$" not in payload

sql = f"""
begin;

delete from public.pipes where note = 'demo';
delete from public.manholes where note = 'demo';

create temp table imp_json on commit drop as select $kml${payload}$kml$::jsonb as j;

create temp table imp_m on commit drop as
select (e->>0)::int as idx, gen_random_uuid() as id, e->>1 as code,
       (e->>2)::float8 as lat, (e->>3)::float8 as lng,
       (e->>4)::public.work_status as status,
       (e->>5)::float8 as plan_d, (e->>6)::float8 as start_d, (e->>7)::float8 as done_d
from imp_json, jsonb_array_elements(j->'manholes') e;

create temp table imp_p on commit drop as
select gen_random_uuid() as id, (e->>0)::int as from_idx, (e->>1)::int as to_idx,
       case when jsonb_array_length(e->2) = 0 then null else e->2 end as path,
       (e->>3)::public.work_status as status,
       (e->>4)::float8 as plan_d, (e->>5)::float8 as start_d, (e->>6)::float8 as done_d
from imp_json, jsonb_array_elements(j->'pipes') e;

insert into public.manholes (id, code, lat, lng, status, note, created_at)
select id, code, lat, lng, status, '{note}', now() + plan_d * interval '1 day'
from imp_m;

insert into public.pipes (id, from_manhole_id, to_manhole_id, diameter_mm, path, status, note, created_at)
select p.id, a.id, b.id, 200, p.path, p.status, '{note}', now() + p.plan_d * interval '1 day'
from imp_p p join imp_m a on a.idx = p.from_idx join imp_m b on b.idx = p.to_idx;

-- History: drop rows the triggers just wrote and orphans of deleted objects,
-- then write the simulated plan -> in progress -> completed steps.
delete from public.status_events e
 where e.object_id in (select id from imp_m union all select id from imp_p)
    or (not exists (select 1 from public.manholes m where m.id = e.object_id)
        and not exists (select 1 from public.pipes p where p.id = e.object_id));

insert into public.status_events (object_type, object_id, status, changed_at)
select t, id, s::public.work_status, now() + d * interval '1 day'
from (
  select 'manhole' t, id, 'planned' s, plan_d d from imp_m
  union all select 'manhole', id, 'in_progress', start_d from imp_m where start_d <= 0
  union all select 'manhole', id, 'completed', done_d from imp_m where done_d <= 0
  union all select 'pipe', id, 'planned', plan_d from imp_p
  union all select 'pipe', id, 'in_progress', start_d from imp_p where start_d <= 0
  union all select 'pipe', id, 'completed', done_d from imp_p where done_d <= 0
) x;

select setval('public.manhole_code_seq',
  coalesce((select max((regexp_match(code, '^[Kk]-?(\\d+)'))[1]::int) from public.manholes), 0) + 1,
  false);

commit;

select
  (select count(*) from public.manholes where note = '{note}') as manholes,
  (select count(*) from public.pipes where note = '{note}') as pipes,
  (select count(*) from public.pipes where note = '{note}' and path is not null) as curved,
  (select round(sum(length_auto_m) / 1000, 1) from public.pipes where note = '{note}') as km,
  (select count(*) from public.status_events) as events;
"""
open(out, "w").write(sql)
print("sql bytes", len(sql))
