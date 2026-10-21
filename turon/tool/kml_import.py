"""KML / GeoJSON (Yandex Map Constructor) -> Turon network rows.

Points become manholes (names kept exactly, duplicates allowed). Each
LineString becomes a chain of pipes between the manholes lying on it
(within SNAP_M), ordered along the line; line vertices between two manholes
are kept as the pipe's `path` so pipes stay curved. Line ends without a
manhole snap to a nearby manhole/line end, otherwise a "tugun" node is
created. Flow direction = drawing direction of the line.

A construction schedule is simulated (downstream first) so the timeline
replay has history. Output: compact JSON for the SQL import.

usage: python3 -I kml_import.py file.kml|file.geojson out.json [--days-back 90]
"""
import json
import math
import sys
import uuid
import xml.etree.ElementTree as ET

SNAP_M = 15.0  # manhole is "on" a line within this distance
END_SNAP_M = 25.0  # line end joins a nearby node within this distance
NS = "{http://www.opengis.net/kml/2.2}"


def hav(a, b):
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    d = (
        math.sin((lat2 - lat1) / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    )
    return 2 * 6371008.8 * math.asin(math.sqrt(d))


def parse(path):
    if path.endswith((".geojson", ".json")):
        return parse_geojson(path)
    root = ET.parse(path).getroot()
    points, lines = [], []
    for pm in root.iter(NS + "Placemark"):
        name = (pm.findtext(NS + "name") or "").strip()
        ls = pm.find(".//" + NS + "LineString/" + NS + "coordinates")
        pt = pm.find(".//" + NS + "Point/" + NS + "coordinates")
        if ls is not None:
            cs = []
            for tok in ls.text.split():
                lng, lat = map(float, tok.split(",")[:2])
                if not cs or hav(cs[-1], (lat, lng)) > 0.05:
                    cs.append((lat, lng))
            if len(cs) >= 2:
                lines.append(cs)
        elif pt is not None:
            lng, lat = map(float, pt.text.strip().split(",")[:2])
            points.append({"name": name, "lat": lat, "lng": lng})
    return points, lines


def parse_geojson(path):
    """GeoJSON export (Yandex Map Constructor): Point.iconCaption = name."""
    data = json.load(open(path))
    points, lines = [], []
    for f in data.get("features", []):
        g = f.get("geometry") or {}
        props = f.get("properties") or {}
        if g.get("type") == "LineString":
            cs = []
            for lng, lat, *_ in g["coordinates"]:
                if not cs or hav(cs[-1], (lat, lng)) > 0.05:
                    cs.append((lat, lng))
            if len(cs) >= 2:
                lines.append(cs)
        elif g.get("type") == "Point":
            lng, lat = g["coordinates"][:2]
            name = (props.get("iconCaption") or props.get("name") or "").strip()
            points.append({"name": name, "lat": lat, "lng": lng})
    return points, lines


class Projector:
    """Local metric plane around the data centre."""

    def __init__(self, lat0):
        self.kx = 111320 * math.cos(math.radians(lat0))
        self.ky = 110574

    def xy(self, c):
        return (c[1] * self.kx, c[0] * self.ky)


def project_on_line(pr, line, p):
    """Returns (distance_m, chainage_m, segment_index, t) of p on polyline."""
    best = None
    chain = 0.0
    P = pr.xy(p)
    for i in range(len(line) - 1):
        A, B = pr.xy(line[i]), pr.xy(line[i + 1])
        dx, dy = B[0] - A[0], B[1] - A[1]
        L2 = dx * dx + dy * dy
        t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((P[0] - A[0]) * dx + (P[1] - A[1]) * dy) / L2))
        X, Y = A[0] + t * dx, A[1] + t * dy
        d = math.hypot(P[0] - X, P[1] - Y)
        seg = math.sqrt(L2)
        if best is None or d < best[0]:
            best = (d, chain + t * seg, i, t)
        chain += seg
    return best


def build(points, lines):
    lat0 = sum(p["lat"] for p in points) / max(1, len(points))
    pr = Projector(lat0)
    nodes = [
        {"id": str(uuid.uuid4()), "code": p["name"] or "K-?", "lat": p["lat"], "lng": p["lng"], "auto": False}
        for p in points
    ]
    auto_count = 0

    def find_node_near(c, radius):
        best, bd = None, radius
        for n in nodes:
            d = hav(c, (n["lat"], n["lng"]))
            if d < bd:
                best, bd = n, d
        return best

    pipes = []
    seen_pairs = set()
    line_chains = []
    for li, line in enumerate(lines):
        on_line = []
        for n in nodes:
            d, ch, seg, t = project_on_line(pr, line, (n["lat"], n["lng"]))
            if d <= SNAP_M:
                on_line.append((ch, seg, t, n))
        total = project_on_line(pr, line, line[-1])[1]
        # Ensure both ends have a node.
        for end, ch_end in ((line[0], 0.0), (line[-1], total)):
            if any(abs(ch - ch_end) <= END_SNAP_M for ch, _, _, _ in on_line):
                continue
            n = find_node_near(end, END_SNAP_M)
            if n is None:
                auto_count += 1
                n = {"id": str(uuid.uuid4()), "code": "Tugun-%d" % auto_count, "lat": end[0], "lng": end[1], "auto": True}
                nodes.append(n)
            seg = 0 if ch_end == 0 else len(line) - 2
            t = 0.0 if ch_end == 0 else 1.0
            on_line.append((ch_end, seg, t, n))
        on_line.sort(key=lambda x: x[0])
        # drop the same node twice in a row / nodes at ~same chainage
        chain = []
        for item in on_line:
            if chain and (item[3] is chain[-1][3] or abs(item[0] - chain[-1][0]) < 0.5):
                continue
            chain.append(item)
        line_chains.append([c[3]["id"] for c in chain])
        for a, b in zip(chain, chain[1:]):
            na, nb = a[3], b[3]
            if na["id"] == nb["id"]:
                continue
            key = frozenset((na["id"], nb["id"]))
            if key in seen_pairs:
                continue
            seen_pairs.add(key)
            # interior line vertices strictly between the two chainages
            path = [line[i] for i in range(a[1] + 1, b[1] + 1) if i < len(line) - 1 or b[2] >= 1.0]
            path = [v for v in path if hav(v, (na["lat"], na["lng"])) > 1 and hav(v, (nb["lat"], nb["lng"])) > 1]
            pipes.append({
                "id": str(uuid.uuid4()),
                "from": na["id"],
                "to": nb["id"],
                "path": [[round(v[0], 7), round(v[1], 7)] for v in path],
                "line": li,
            })
    return nodes, pipes, auto_count, line_chains


def simulate(nodes, pipes, line_chains, days_back=90, days_ahead=60, seed=7):
    """Downstream-first construction over [-days_back, +days_ahead] days.

    Each pipe gets plan/start/done day offsets (relative to today, negative =
    past). Lines are built one after another (shuffled deterministically);
    inside a line the last pipe (downstream end) goes first.
    """
    import random

    rnd = random.Random(seed)
    by_line = {}
    for p in pipes:
        by_line.setdefault(p["line"], []).append(p)
    order = list(by_line)
    rnd.shuffle(order)
    total = sum(len(by_line[l]) for l in order)
    span = days_back + days_ahead
    k = 0
    for l in order:
        group = list(reversed(by_line[l]))  # downstream first
        for p in group:
            start = -days_back + span * k / max(1, total)
            p["plan"] = round(-days_back - rnd.uniform(3, 12), 1)
            p["start"] = round(start, 1)
            p["done"] = round(start + rnd.uniform(6, 18), 1)
            k += 1
    node_pipes = {}
    for p in pipes:
        for nid in (p["from"], p["to"]):
            node_pipes.setdefault(nid, []).append(p)
    for n in nodes:
        ps = node_pipes.get(n["id"])
        if ps:
            n["plan"] = min(p["plan"] for p in ps)
            n["start"] = min(p["start"] for p in ps)
            n["done"] = min(p["done"] for p in ps)
        else:  # standalone manhole
            n["plan"] = round(-days_back - rnd.uniform(3, 12), 2)
            n["start"] = round(rnd.uniform(-days_back, days_ahead), 2)
            n["done"] = round(n["start"] + rnd.uniform(1, 4), 2)

    def status(o):
        if o["done"] <= 0:
            return "completed"
        if o["start"] <= 0:
            return "in_progress"
        return "planned"

    for o in nodes + pipes:
        o["status"] = status(o)


def main():
    src, out = sys.argv[1], sys.argv[2]
    days_back = 90
    if "--days-back" in sys.argv:
        days_back = int(sys.argv[sys.argv.index("--days-back") + 1])
    points, lines = parse(src)
    nodes, pipes, auto_count, chains = build(points, lines)
    simulate(nodes, pipes, chains, days_back=days_back)
    # Compact payload: manholes are referenced by their index; the database
    # assigns real UUIDs.
    index = {n["id"]: i for i, n in enumerate(nodes)}
    data = {
        "manholes": [
            [i, n["code"], round(n["lat"], 7), round(n["lng"], 7), n["status"], n["plan"], n["start"], n["done"]]
            for i, n in enumerate(nodes)
        ],
        "pipes": [
            [index[p["from"]], index[p["to"]], p["path"], p["status"], p["plan"], p["start"], p["done"]]
            for p in pipes
        ],
    }
    with open(out, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    from collections import Counter
    used = {p["from"] for p in pipes} | {p["to"] for p in pipes}
    print("manholes", len(nodes), "(auto tugun:", auto_count, ") standalone:", sum(1 for n in nodes if n["id"] not in used))
    print("pipes", len(pipes), "with bends:", sum(1 for p in pipes if p["path"]), "path vertices:", sum(len(p["path"]) for p in pipes))
    print("status manholes", Counter(n["status"] for n in nodes), "pipes", Counter(p["status"] for p in pipes))
    print("json bytes", len(json.dumps(data, separators=(",", ":"))))


if __name__ == "__main__":
    main()
