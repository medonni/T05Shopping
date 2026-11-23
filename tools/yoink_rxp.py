#!/usr/bin/env python3
"""Convert RestedXP's Tier 0.5 guide into T05Shopping's own Guide.lua.

Usage: python3 -I tools/yoink_rxp.py <path to RXPGuides addon folder> > Guide.lua

Run it again whenever RestedXP updates the guide. T05Shopping never reads RestedXP at
runtime: this script copies what it needs once.

Source: RestedXP Guides, licensed CC BY-NC-SA 4.0 (see the header this writes).
"""
import re
import sys
from pathlib import Path

PARTS = re.compile(r"#name Part ([1-4]):")
# RestedXP's color placeholders -> real WoW color codes
COLORS = {
    "WARN": "ffff9933", "LOOT": "ff00d1ff", "FRIENDLY": "ff40ff40",
    "ENEMY": "ffff5555", "BUY": "ffffd100", "PICK": "ffffd100",
}


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def split_cond(line):
    """'text << Alliance Druid --comment' -> ('text', 'Alliance Druid')"""
    line = re.sub(r"\s--[^|]*$", "", line)  # trailing --comments
    if "<<" in line:
        text, cond = line.split("<<", 1)
        return text.strip(), cond.strip()
    return line.strip(), ""


def resolve_flags(cond):
    """WoW Forever is not Season of Discovery: drop "sod" lines, keep "!sod" ones.
    Returns the faction/class condition left for runtime, or None to drop the line."""
    if cond == "sod":
        return None
    return cond.replace("!sod", "").strip()


def clean(text):
    text = re.sub(r"\|cRXP_([A-Z]+)_", lambda m: "|c" + COLORS.get(m.group(1), "ffffffff"), text)
    return text.strip()


def parse(guide_file, zone_ids):
    src = guide_file.read_text(encoding="utf-8")
    steps = []
    for block in src.split("RXPGuides.RegisterGuide("):
        m = PARTS.search(block)
        if not m or "Set Guide" not in block:
            continue
        part = int(m.group(1))
        body = block.split("\nstep", 1)[1] if "\nstep" in block else ""
        for raw in re.split(r"\n\s*step", "\n" + body):
            lines = raw.split("\n")
            head = lines[0]
            step_cond = resolve_flags(split_cond(head)[1]) if "<<" in head else ""
            if step_cond is None:
                continue
            step = {"part": part, "cond": step_cond, "lines": [], "accept": [], "turnin": [], "go": None, "optional": False, "names": {}}
            for line in lines[1:]:
                t = line.strip()
                if not t or t.startswith("--"):
                    continue
                if t == "#optional":
                    step["optional"] = True
                    continue
                if t.startswith("#") or t.startswith("]]"):
                    continue
                text, cond = split_cond(t)
                cond = resolve_flags(cond)
                if cond is None:
                    continue
                g = re.match(r"\.goto ([^,]+),([\d.]+),([\d.]+)", text)
                if g and not step["go"] and g.group(1) in zone_ids:
                    step["go"] = (zone_ids[g.group(1)], float(g.group(2)), float(g.group(3)), g.group(1), cond)
                q = re.match(r"\.(accept|turnin) (\d+)", text)
                if q:
                    step[q.group(1)].append((int(q.group(2)), cond))
                # Anything with ">>" is text for the player (">>x" or ".cmd args >>x")
                if ">>" in text:
                    shown = clean(text.split(">>", 1)[1])
                    if q:  # quest name -> a real quest link (hover, shift-click, Wowhead)
                        shown = shown.replace("Turn in Accept ", "Turn in ")  # (RestedXP typo, quest 8996)
                        n = re.match(r"^(?:Accept|Turn in) (.+)$", shown)
                        if n:
                            step["names"][int(q.group(2))] = n.group(1)
                        shown = re.sub(r"^(Accept|Turn in) (.+)$",
                                       lambda m: "%s |cffffff00|Hquest:%s:60|h[%s]|h|r" % (m.group(1), q.group(2), m.group(2)), shown)
                    if shown:
                        step["lines"].append((shown, cond))
                elif text.startswith("+"):
                    step["lines"].append((clean(text[1:]), cond))
            if step["lines"]:
                steps.append(step)
    return steps


def has(step, needle):
    return any(needle in text for text, _ in step["lines"])


def forever_fixes(steps):
    """WoW Forever changed parts of the chain. Raises if RestedXP's text moved, so a
    re-run never silently ships the old Classic steps."""
    # Three Kings of Flame: Forever replaced the Cinder of Cynders (Duke of Cynders,
    # summoned at Silithus Wind Stones with Twilight gear) with the Ash of Asharell
    # from an elite in Burning Steppes. Drop the whole Silithus detour (Twilight
    # gear, Cenarion rep, Aurel Goldleaf, Dukes of the Council, Medallion of
    # Station, the Duke) and put the Forever step in its place.
    end = next((i for i, s in enumerate(steps) if has(s, "Duke of Cynders")), None)
    if end is None:
        raise SystemExit("forever_fixes: Duke of Cynders step not found; check the guide")
    start = next((i for i in range(end, -1, -1)
                  if steps[i]["part"] == 4 and has(steps[i], "Travel to") and has(steps[i], "Silithus")), None)
    if start is None:
        raise SystemExit("forever_fixes: start of the Silithus detour not found")
    steps[start:end + 1] = [{
        "part": 4, "cond": "", "optional": False, "accept": [], "turnin": [],
        "go": (1428, 74.0, 66.0, "Burning Steppes", ""), "names": {},
        "lines": [
            ("Kill |cffff5555Executor Asharell|r and loot the |cff00d1ff[Ash of Asharell]|r", ""),
            ("|cffff9933Level 62 elite in a cave in southern|r |cFFfa9602Burning Steppes|r|cffff9933. Bring a group|r", ""),
            ("|cffff9933Reported to be summoned at the Forgotten Brazier (72.6, 68.8); not confirmed|r", ""),
            ("|cff9e9e9e(WoW Forever change: replaces the Silithus Duke of Cynders and its Twilight gear farm)|r", ""),
        ],
    }]
    return steps


def chain(steps):
    """The quest chain in guide order: one entry per turned-in quest name with every
    class/faction variant ID. A quest only one faction ever turns in gets its faction."""
    out = {}
    for s in steps:
        for qid, cond in s["turnin"]:
            name = s["names"].get(qid)
            if not name:
                continue
            e = out.setdefault(name, {"part": s["part"], "ids": [], "factions": set()})
            if qid not in e["ids"]:
                e["ids"].append(qid)
            tokens = (s["cond"] + " " + cond).split()
            e["factions"].add(next((t for t in tokens if t in ("Alliance", "Horde")), None))
    return out


def zones(rxp):
    db = (rxp / "DB" / "classic" / "db.lua").read_text(encoding="utf-8")
    return {name: int(i) for name, i in re.findall(r'\["([^"]+)"\]\s*=\s*(\d+),', db)}


def emit(steps):
    out = [
        "-- T0.5 quest guide for T05Shopping. GENERATED by tools/yoink_rxp.py: don't edit by hand.",
        "--",
        "-- Adapted from RestedXP Guides (Guides/Classic-0.5.lua, \"Set Guide\" Parts 1-4)",
        "-- by RestedXP, https://github.com/RestedXP/RXPGuides",
        "-- Licensed CC BY-NC-SA 4.0: https://creativecommons.org/licenses/by-nc-sa/4.0/",
        "-- Changes: converted to a plain Lua table, colors mapped, Season of Discovery lines",
        "-- removed, Three Kings of Flame rewritten for WoW Forever (Ash of Asharell).",
        "-- This file (and only this file) is shared under the same license.",
        "local _, ns = ...",
        "",
        "-- { part, cond (faction/class, RestedXP syntax), opt, lines = { {text, cond} },",
        "--   go = { mapID, x, y, zone, cond }, accept/turnin = { {questID, cond} } }",
        "ns.GUIDE = {",
    ]

    def pairs(xs):
        return "{ " + ", ".join("{ %s, %s }" % (a if isinstance(a, int) else lua_str(a), lua_str(c)) for a, c in xs) + " }"

    for s in steps:
        parts = ["part = %d" % s["part"]]
        if s["cond"]:
            parts.append("cond = " + lua_str(s["cond"]))
        if s["optional"]:
            parts.append("opt = true")
        parts.append("lines = " + pairs(s["lines"]))
        if s["go"]:
            m, x, y, z, c = s["go"]
            parts.append("go = { %d, %.2f, %.2f, %s, %s }" % (m, x, y, lua_str(z), lua_str(c)))
        if s["accept"]:
            parts.append("accept = " + pairs(s["accept"]))
        if s["turnin"]:
            parts.append("turnin = " + pairs(s["turnin"]))
        out.append("  { " + ", ".join(parts) + " },")
    out.append("}")
    out += ["", "-- The quest chain in turn-in order (ids = every class/faction variant)", "ns.CHAIN = {"]
    for name, e in chain(steps).items():
        faction = ", faction = " + lua_str(next(iter(e["factions"]))) if len(e["factions"]) == 1 and None not in e["factions"] else ""
        out.append("  { part = %d, name = %s, ids = { %s }%s }," % (e["part"], lua_str(name), ", ".join(map(str, e["ids"])), faction))
    out += ["}", "ns.STEP = {}", "for _, s in ipairs(ns.CHAIN) do ns.STEP[s.name] = s end"]
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    rxp = Path(sys.argv[1])
    sys.stdout.write(emit(forever_fixes(parse(rxp / "Guides" / "Classic-0.5.lua", zones(rxp)))))
