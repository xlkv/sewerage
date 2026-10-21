"""Applies corrected line directions to already imported pipes.

Pipes were imported from ORIGINAL (KML) and follow its line directions.
CORRECTED (GeoJSON/KML) has the same lines, some reversed. For every pipe we
find the original line it was built from (the pipe lies on it AND runs in its
direction — this disambiguates overlapping lines), then swap the pipe iff that
line is reversed in the corrected file. IDs, codes, statuses and history are
kept.

usage: python3 -I fix_directions.py original.kml corrected.geojson \
           pipes_export.json out.sql
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kml_import as K  # noqa: E402


def load_lines(path):
    if path.endswith(".kml"):
        return K.parse(path)[1]
    gj = json.load(open(path))
    lines = []
    for f in gj["features"]:
        if f["geometry"]["type"] != "LineString":
            continue
        cs = []
        for lng, lat, *_ in f["geometry"]["coordinates"]:
            if not cs or K.hav(cs[-1], (lat, lng)) > 0.05:
                cs.append((lat, lng))
        if len(cs) >= 2:
            lines.append(cs)
    return lines


def same(x, y):
    return len(x) == len(y) and all(K.hav(p, q) < 0.5 for p, q in zip(x, y))


def main():
    original = load_lines(sys.argv[1])
    corrected = load_lines(sys.argv[2])
    data = json.load(open(sys.argv[3]))
    rows = data["rows"] if isinstance(data, dict) else data

    # Original line index -> reversed in corrected file?
    reversed_line = {}
    used = set()
    for i, a in enumerate(original):
        for j, b in enumerate(corrected):
            if j in used:
                continue
            if same(a, b):
                reversed_line[i] = False
                used.add(j)
                break
            if same(a, list(reversed(b))):
                reversed_line[i] = True
                used.add(j)
                break
    missing = [i for i in range(len(original)) if i not in reversed_line]

    pr = K.Projector(sum(l[0][0] for l in original) / len(original))
    swap, keep, unsure = [], 0, []
    for r in rows:
        a = (float(r["alat"]), float(r["alng"]))
        b = (float(r["blat"]), float(r["blng"]))
        pts = [a, *[tuple(v) for v in (r["path"] or [])], b]
        candidates = []
        for i, line in enumerate(original):
            score = max(K.project_on_line(pr, line, p)[0] for p in pts)
            if score > K.END_SNAP_M:
                continue
            ch_a = K.project_on_line(pr, line, a)[1]
            ch_b = K.project_on_line(pr, line, b)[1]
            candidates.append((ch_a < ch_b, score, i))
        # Source line: runs the same way as the pipe; best fit first.
        forward = sorted(c for c in candidates if c[0])
        forward.sort(key=lambda c: c[1])
        if not forward or forward[0][2] not in reversed_line:
            unsure.append(r["code"])
            continue
        if reversed_line[forward[0][2]]:
            swap.append(r["id"])
        else:
            keep += 1

    ids = ",".join("'%s'" % i for i in swap)
    sql = f"""
begin;
update public.pipes p
   set from_manhole_id = p.to_manhole_id,
       to_manhole_id = p.from_manhole_id,
       path = (select jsonb_agg(e order by ord desc)
                 from jsonb_array_elements(p.path) with ordinality t(e, ord))
 where p.id in ({ids or "null"});
commit;
select count(*) as swapped from public.pipes where id in ({ids or "null"});
"""
    open(sys.argv[4], "w").write(sql)
    print(
        "lines reversed", sum(reversed_line.values()), "of", len(reversed_line),
        "unmatched lines", missing,
        "| pipes swap", len(swap), "keep", keep, "unsure", len(unsure), unsure[:10],
    )


if __name__ == "__main__":
    main()
