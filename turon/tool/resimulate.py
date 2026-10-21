"""Re-simulates the construction history as one crew working through the
network: starts at the north-west (top-left) pipe and keeps going to an
adjacent pipe (continuing the same line first); when a branch is finished it
moves to the nearest unbuilt pipe. All objects are "planned" at the start.

Writes a transactional SQL that sets current statuses and replaces the
history in status_events. IDs, codes and geometry are untouched.

usage: python3 -I resimulate.py manholes.json pipes.json out.sql
       [--days-back 90] [--days-ahead 60]
"""
import json
import math
import sys


def rows(path):
    d = json.load(open(path))
    return d["rows"] if isinstance(d, dict) else d


def dist(a, b):
    kx = 111320 * math.cos(math.radians((a[0] + b[0]) / 2))
    return math.hypot((a[1] - b[1]) * kx, (a[0] - b[0]) * 110574)


def main():
    days_back, days_ahead = 90.0, 60.0
    if "--days-back" in sys.argv:
        days_back = float(sys.argv[sys.argv.index("--days-back") + 1])
    if "--days-ahead" in sys.argv:
        days_ahead = float(sys.argv[sys.argv.index("--days-ahead") + 1])

    manholes = {r["id"]: (float(r["lat"]), float(r["lng"])) for r in rows(sys.argv[1])}
    pipes = {r["id"]: (r["a"], r["b"]) for r in rows(sys.argv[2])}
    mid = {pid: ((manholes[a][0] + manholes[b][0]) / 2, (manholes[a][1] + manholes[b][1]) / 2)
           for pid, (a, b) in pipes.items()}
    at = {}
    for pid, (a, b) in pipes.items():
        at.setdefault(a, []).append(pid)
        at.setdefault(b, []).append(pid)

    # Start: pipe nearest the north-west corner of the network.
    max_lat = max(p[0] for p in manholes.values())
    min_lng = min(p[1] for p in manholes.values())
    corner = (max_lat, min_lng)
    current = min(pipes, key=lambda p: dist(mid[p], corner))

    order, built = [], set()
    built_nodes = set()
    while current is not None:
        order.append(current)
        built.add(current)
        a, b = pipes[current]
        built_nodes.update((a, b))
        # Continue along the line: unbuilt pipes touching this pipe's ends.
        nxt = [p for n in (b, a) for p in at.get(n, []) if p not in built]
        if not nxt:
            # Any unbuilt pipe touching the built network, nearest first.
            nxt = [p for n in built_nodes for p in at.get(n, []) if p not in built]
        if not nxt:
            nxt = [p for p in pipes if p not in built]
        current = min(nxt, key=lambda p: dist(mid[p], mid[order[-1]])) if nxt else None

    n = len(order)
    slot = (days_back + days_ahead) / max(1, n)
    plan_day = -days_back - 2
    sched = {}
    for k, pid in enumerate(order):
        start = -days_back + k * slot
        sched[pid] = (plan_day, start, start + 2 * slot)

    msched = {}
    for mid_id, pos in manholes.items():
        ps = at.get(mid_id)
        if ps:
            msched[mid_id] = (plan_day, min(sched[p][1] for p in ps), min(sched[p][2] for p in ps))
        else:  # standalone manhole: built together with the nearest pipe
            near = min(pipes, key=lambda p: dist(mid[p], pos))
            msched[mid_id] = sched[near]

    def status(s):
        return "completed" if s[2] <= 0 else "in_progress" if s[1] <= 0 else "planned"

    data = [["pipe", pid, status(s), round(s[0], 4), round(s[1], 4), round(s[2], 4)] for pid, s in sched.items()]
    data += [["manhole", mid_id, status(s), round(s[0], 4), round(s[1], 4), round(s[2], 4)] for mid_id, s in msched.items()]
    payload = json.dumps(data, separators=(",", ":"))
    assert "$sim$" not in payload

    sql = f"""
begin;
create temp table sim on commit drop as
select e->>0 as t, (e->>1)::uuid as id, (e->>2)::public.work_status as status,
       (e->>3)::float8 as plan_d, (e->>4)::float8 as start_d, (e->>5)::float8 as done_d
from jsonb_array_elements($sim${payload}$sim$::jsonb) e;

update public.manholes m set status = s.status from sim s where s.t = 'manhole' and s.id = m.id and m.status <> s.status;
update public.pipes p set status = s.status from sim s where s.t = 'pipe' and s.id = p.id and p.status <> s.status;

delete from public.status_events where object_id in (select id from sim);
insert into public.status_events (object_type, object_id, status, changed_at)
select t, id, st::public.work_status, now() + d * interval '1 day'
from (
  select t, id, 'planned' st, plan_d d from sim
  union all select t, id, 'in_progress', start_d from sim where start_d <= 0
  union all select t, id, 'completed', done_d from sim where done_d <= 0
) x;
commit;

select
  (select count(*) from public.status_events) as events,
  (select count(*) filter (where status = 'completed') from public.pipes) as pipes_completed,
  (select count(*) filter (where status = 'in_progress') from public.pipes) as pipes_in_progress,
  (select count(*) filter (where status = 'planned') from public.pipes) as pipes_planned;
"""
    open(sys.argv[3], "w").write(sql)
    jumps = sum(1 for p, q in zip(order, order[1:]) if not (set(pipes[p]) & set(pipes[q])))
    print("pipes", n, "slot days %.3f" % slot, "jumps between areas", jumps,
          "first pipe midpoint", tuple(round(x, 5) for x in mid[order[0]]), "NW corner", tuple(round(x, 5) for x in corner))


if __name__ == "__main__":
    main()
