"""Floatie Farm economy simulator: one free player on Auto Roll.
The defaults below are the game's numbers (v1.1.0); keep them in step with
src/shared/ConfigParts when you change the economy, then re-run to see the pace.
Follows the game rules: rarest-first luck pick (exact distribution), mutations
(no Conveyor Luck), grades + traits from tokens/gems, levels, upgrades,
rebirth, pumps, Index milestones (+2% luck, rewards), playtime rewards per
2 h session, daily rewards, server events, potions, Jackpot Rolls.
Usage: python tools/econ_sim.py HOURS RUNS [overrides.json or a JSON string]"""
import random, math, sys, json, bisect
from multiprocessing import Pool

RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Celestial", "Cosmic", "Secret"]
INCOME = [1, 2, 3, 4, 5, 8, 11, 14, 19, 25, 40, 55, 75, 95, 120, 250, 340, 430, 560, 700,
          1500, 2000, 2600, 3300, 4000, 10e3, 14e3, 18e3, 24e3, 30e3, 80e3, 105e3, 135e3, 165e3, 200e3,
          600e3, 800e3, 1e6, 1.25e6, 1.5e6, 5e6, 6.5e6, 8e6, 10e6, 12e6, 50e6, 65e6, 80e6, 100e6, 120e6]
OLD_ODDS = [  # before v1.1.0, for comparison
           2, 3, 5, 7, 10, 15, 20, 25, 35, 50, 60, 90, 130, 180, 250, 400, 600, 800, 1100, 1500,
            3000, 5000, 7500, 11000, 15000, 30e3, 50e3, 75e3, 110e3, 150e3, 300e3, 500e3, 750e3, 1.1e6, 1.5e6,
            4e6, 6.5e6, 9e6, 13e6, 20e6, 60e6, 100e6, 150e6, 220e6, 300e6, 1e9, 2e9, 3.5e9, 6e9, 10e9]

BASE = dict(
    odds=[2, 3, 5, 9, 15, 25, 40, 65, 110, 180, 300, 500, 800, 1400, 2300, 3800, 6000, 10000, 17000, 28000, 45000, 75000, 125000, 210000, 350000, 600000, 950000, 1600000, 2600000, 4300000, 7000000, 12000000, 20000000, 32000000, 50000000, 85000000, 140000000, 240000000, 400000000, 650000000, 1100000000, 1800000000, 3000000000, 5000000000, 8000000000, 13000000000, 24000000000, 36000000000, 60000000000, 100000000000],
    income=INCOME,
    pump_luck=[1, 2, 3, 5, 8, 12, 20, 30, 50, 80, 125, 200],
    pump_price=[0, 250, 2200000, 130000000, 9200000000, 360000000000, 4800000000000, 48000000000000, 300000000000000, 2000000000000000, 7600000000000000, 23000000000000000],
    level_cost_mult=100, level_growth=1.08, per_level=0.15, max_level=100,
    # per, max, costBase, costGrowth (Config.Upgrades; Walk Speed doesn't matter here)
    upg={"slots": (1, 20, 5000, 2.6), "luck": (0.05, 40, 10000, 2.3), "cash": (0.10, 50, 5000, 2.2),
         "time": (0.04, 12, 25000, 3.0)},
    rebirth_costs=[1500000000, 100000000000, 4000000000000, 50000000000000, 310000000000000, 2100000000000000, 7700000000000000, 23000000000000000], rebirth_growth=3,
    rebirth_base=1.5e9, rebirth_cash=0.5, rebirth_luck=0.10, rebirth_tokens=5,
    sell_mult=20, inflate=2.0, min_inflate=0.5,
    muts=[("Rainbow", 5, 0.003), ("Foil", 3, 0.012), ("Neon", 2, 0.035), ("Glitter", 1.5, 0.08)],
    grade_token_air=(100e3, 1.3), jackpot_luck=999, index_luck=0.02,
    # how the simulated player plays: a 2 h session (Playtime rewards), one Daily claim per 3 h of play,
    # buys anything that pays back within 10 min, Luck/Time upgrades when they cost <= 5 min of income
    session_hours=2.0, day_hours=3.0, payback=600, luck_buy_secs=300, token_buy_secs=300,
)
GRADES = [(1, 0.45), (1.5, 0.30), (2.5, 0.15), (5, 0.07), (10, 0.025), (25, 0.005)]
TRAITS = [(1.2, 0.40), (1.5, 0.25), (1, 0.15), (2, 0.10), (3, 0.05), (1, 0.03), (5, 0.015), (8, 0.004), (15, 0.0009), (25, 0.0001)]
EVENTS = ["HeliumRain", "GoldenHour", "Thunderstorm", "SecretSkies", "LuckyBreeze"]
EV_DUR = {"HeliumRain": 180, "GoldenHour": 180, "Thunderstorm": 150, "SecretSkies": 120, "LuckyBreeze": 180}
PLAYTIME = [(1, dict(im=5, mn=200)), (3, dict(luck=1)), (5, dict(tok=1)), (8, dict(im=10, mn=500)), (12, dict(cash=1)),
            (16, dict(gem=1)), (20, dict(mut=1)), (25, dict(im=20, mn=1000)), (30, dict(tok=2)), (40, dict(luck=2)),
            (50, dict(gem=2)), (60, dict(jack=1))]
DAILY = [dict(im=10, mn=500), dict(luck=2), dict(im=30, mn=1500), dict(tok=3), dict(cash=2, mut=1), dict(gem=3),
         dict(epic=1, jack=1)]
INDEX_MS = [(10, dict(im=10, mn=1000, tok=1)), (25, dict(im=15, mn=5000, luck=2)), (50, dict(im=20, mn=20000, tok=3, gem=2)),
            (100, dict(im=30, mn=100e3, luck=2, cash=2, gem=3)), (150, dict(im=45, mn=500e3, tok=5, mut=2)),
            (200, dict(im=60, mn=1e6, tok=5, gem=5)), (250, dict(im=90, mn=5e6, tok=10, gem=10)),
            (300, dict(im=120, mn=10e6, tok=25, gem=25, jack=3))]


def pick_weighted(table, rng):
    total = sum(w for w, _ in table)
    r = rng.random() * total
    for w, v in table:
        r -= w
        if r <= 0:
            return v
    return table[-1][1]


def rebirth_cost(P, n):
    """Config.Rebirth.Costs list, then x CostGrowth for every rebirth after the list"""
    costs = P.get("rebirth_costs")
    if costs:
        if n < len(costs):
            return costs[n]
        return costs[-1] * P["rebirth_growth"] ** (n - len(costs) + 1)
    return P["rebirth_base"] * P["rebirth_growth"] ** n


class Sim:
    def __init__(s, P, seed):
        s.P = P
        s.rng = random.Random(seed)
        n = len(P["odds"])
        s.defs = [(i, RARITIES[i // 5], P["odds"][i], P["income"][i]) for i in range(n)]
        s.by_odds = sorted(s.defs, key=lambda d: -d[2])
        s.cache = {}
        s.t = 0.0
        s.air = 100.0
        s.pump = 0
        s.up = {k: 0 for k in P["upg"]}
        s.reb = 0
        s.placed = []      # floatie = [base_income_with_mut, grade, trait, level, def_income, sell]
        s.bench = []
        s.index = set()
        s.ms_claimed = 0
        s.items = dict(tok=0, gem=0, luck=0, cash=0, mut=0, jack=0)
        s.pot = dict(luck=0.0, cash=0.0, mut=0.0)
        s.event, s.event_end, s.next_event = None, 0.0, 15 * 60
        s.rolls = 0
        s.tokens_bought = 0
        s.ms = {}
        s.got = {r: 0 for r in RARITIES}
        s.session_start, s.pt_claimed = 0.0, 0
        s.next_daily, s.day = 0.0, 0
        s.dirty = True
        s.inc = 0.0

    # -- multipliers
    def luck(s):
        P = s.P
        L = P["pump_luck"][s.pump] * (1 + s.up["luck"] * P["upg"]["luck"][0]) * (1 + s.reb * P["rebirth_luck"])
        L *= 1 + s.ms_claimed * P["index_luck"]
        if s.pot["luck"] > s.t: L *= 2
        if s.event == "LuckyBreeze": L *= 2
        return L

    def cashm(s):
        P = s.P
        c = (1 + s.up["cash"] * P["upg"]["cash"][0]) * (1 + s.reb * P["rebirth_cash"])
        if s.pot["cash"] > s.t: c *= 2
        if s.event == "GoldenHour": c *= 2
        return c

    def slots(s):
        return 10 + s.up["slots"] + min(s.reb * 2, 6)

    def interval(s):
        if s.rolls < 10: return 0.7 + 0.1
        return max(s.P["min_inflate"], s.P["inflate"] * (1 - s.up["time"] * s.P["upg"]["time"][0])) + 0.1

    @staticmethod
    def finc(f):
        return f[0] * (1 + 0.15 * (f[3] - 1)) * f[1] * f[2]

    # -- the pull
    def dist(s, L, secret):
        key = (L, secret)
        d = s.cache.get(key)
        if d: return d
        probs = []
        remaining = 1.0
        bo = s.by_odds
        done = False
        for i, df in enumerate(bo):
            luck = L * secret if df[1] == "Secret" else L
            c = luck / df[2]
            if c >= 1:
                pool = [g for g in bo[i:] if g[1] == df[1]]
                tw = sum(1 / g[2] for g in pool)
                for g in pool:
                    probs.append((remaining * (1 / g[2]) / tw, g))
                remaining = 0
                done = True
                break
            probs.append((remaining * c, df))
            remaining *= 1 - c
        if not done and remaining > 0:
            commons = [g for g in s.defs if g[1] == "Common"]
            tw = sum(1 / g[2] for g in commons)
            for g in commons:
                probs.append((remaining * (1 / g[2]) / tw, g))
        cum, acc, vals = [], 0.0, []
        for p, g in probs:
            acc += p
            cum.append(acc)
            vals.append(g)
        d = (cum, vals)
        if len(s.cache) > 4000: s.cache.clear()
        s.cache[key] = d
        return d

    def roll_def(s, mult=1.0):
        L = s.luck() * mult
        secret = 5 if s.event == "SecretSkies" else 1
        cum, vals = s.dist(L, secret)
        r = s.rng.random() * cum[-1]
        return vals[min(bisect.bisect_left(cum, r), len(vals) - 1)]

    def roll_mut(s):
        m = 1.0
        if s.pot["mut"] > s.t: m *= 3
        if s.event == "HeliumRain": m *= 4
        if s.event == "Thunderstorm" and s.rng.random() < min(0.03 * m, 0.9):
            return "Thunder", 8
        for name, mm, c in s.P["muts"]:
            if s.rng.random() < min(c * m, 0.9):
                return name, mm
        return "Normal", 1

    def add(s, d, mut=None):
        name, mm = mut or s.roll_mut()
        s.got[d[1]] += 1
        k = "first_" + d[1]
        if k not in s.ms: s.ms[k] = s.t
        s.index.add((d[0], name))
        f = [d[3] * mm, 1, 1, 1, d[3], d[3] * s.P["sell_mult"] * mm]
        # goes to a slot if it beats the worst placed one, else bench/sold
        if len(s.placed) < s.slots():
            s.placed.append(f); s.dirty = True
        elif s.finc(f) > s.finc(s.placed[-1]) if s.placed else True:
            s.placed.append(f); s.dirty = True
        else:
            s.bench.append(f)
            if len(s.bench) > 40:
                s.bench.sort(key=lambda g: -s.finc(g))
                for g in s.bench[20:]:
                    s.air += g[5] * g[1]
                del s.bench[20:]

    def resort(s):
        allf = s.placed + s.bench
        allf.sort(key=lambda g: -s.finc(g))
        n = s.slots()
        s.placed = allf[:n]
        s.bench = allf[n:]
        s.dirty = False
        s.inc = sum(s.finc(f) for f in s.placed) * s.cashm()

    def mark(s, k):
        if k not in s.ms: s.ms[k] = s.t

    # -- rewards
    def give(s, r):
        if "im" in r:
            s.air += max(r.get("mn", 0), s.inc * 60 * r["im"])
        for k in ("tok", "gem", "luck", "cash", "mut", "jack"):
            if k in r: s.items[k] += r[k]
        if r.get("epic"):
            pool = [d for d in s.defs if d[1] == "Epic"]
            d = pick_weighted([(1 / d[2], d) for d in pool], s.rng)
            muts = s.P["muts"]
            m = s.rng.choice(muts)
            s.add(d, (m[0], m[1]))

    def use_items(s):
        # drink potions as they come (each adds 10 min)
        for k in ("luck", "cash", "mut"):
            while s.items[k] > 0:
                s.items[k] -= 1
                s.pot[k] = max(s.pot[k], s.t) + 600
        # grade tokens: reroll the best C (then B) Floatie on a slot
        while s.items["tok"] > 0:
            if s.dirty: s.resort()
            tgt = next((f for f in s.placed if f[1] == 1), None) or next((f for f in s.placed[:5] if f[1] == 1.5), None)
            if not tgt: break
            s.items["tok"] -= 1
            tgt[1] = pick_weighted([(c, m) for m, c in GRADES], s.rng)
            s.dirty = True
        while s.items["gem"] > 0:
            if s.dirty: s.resort()
            tgt = next((f for f in s.placed if f[2] <= 1.2), None)
            if not tgt: break
            s.items["gem"] -= 1
            tgt[2] = pick_weighted([(c, m) for m, c in TRAITS], s.rng)
            s.dirty = True

    def spend(s):
        P = s.P
        for _ in range(300):
            if s.dirty: s.resort()
            nxt = P["pump_price"][s.pump + 1] if s.pump + 1 < len(P["pump_price"]) else math.inf
            if s.air >= nxt:
                s.air -= nxt; s.pump += 1; s.mark("pump%d" % (s.pump + 1)); continue
            rc = rebirth_cost(P, s.reb)
            if s.air >= rc and nxt > s.air:
                s.air = 0; s.reb += 1; s.items["tok"] += P["rebirth_tokens"]; s.mark("rebirth%d" % s.reb)
                s.dirty = True; s.use_items(); continue
            inc = max(s.inc, 1e-9)
            best = None
            for k, (per, mx, base, growth) in P["upg"].items():
                if s.up[k] >= mx: continue
                cost = math.floor(base * growth ** s.up[k])
                if k == "cash":
                    pb = cost / (inc * per / (1 + s.up[k] * per))
                elif k == "slots":
                    g = s.finc(s.bench[0]) * s.cashm() if s.bench else 0
                    pb = cost / g if g > 0 else math.inf
                else:  # luck / time: players buy these when cheap compared with income
                    pb = cost / inc * (P["payback"] / P["luck_buy_secs"])
                if best is None or pb < best[0]: best = (pb, cost, ("up", k))
            c = s.cashm()
            for f in s.placed:
                if f[3] < P["max_level"]:
                    cost = f[0] * f[1] * f[2] * P["level_cost_mult"] * P["level_growth"] ** (f[3] - 1)
                    gain = f[0] * f[1] * f[2] * 0.15 * c
                    pb = cost / gain
                    if best is None or pb < best[0]: best = (pb, cost, ("lvl", f))
            tb, tg = P["grade_token_air"]
            tcost = tb * tg ** s.tokens_bought
            if tcost <= inc * P["token_buy_secs"] and tcost <= s.air and any(f[1] == 1 for f in s.placed[:5]):
                s.air -= tcost; s.tokens_bought += 1; s.items["tok"] += 1; s.use_items(); continue
            if best and best[0] <= P["payback"] and best[1] <= s.air:
                s.air -= best[1]
                if best[2][0] == "up":
                    s.up[best[2][1]] += 1
                else:
                    best[2][1][3] += 1
                s.dirty = True
                continue
            break

    def run(s, hours, checkpoints):
        P = s.P
        end = hours * 3600
        next_roll = 0.0
        sess_len = P["session_hours"] * 3600
        rep = {}
        cps = sorted(checkpoints)
        tick = 1.0
        last_spend = -10
        while s.t < end:
            t = s.t
            # session / playtime / daily
            if t - s.session_start >= sess_len:
                s.session_start, s.pt_claimed = t, 0
            while s.pt_claimed < len(PLAYTIME) and t - s.session_start >= PLAYTIME[s.pt_claimed][0] * 60:
                s.give(PLAYTIME[s.pt_claimed][1]); s.pt_claimed += 1; s.use_items()
            if t >= s.next_daily:
                s.give(DAILY[s.day % 7]); s.day += 1; s.next_daily = t + P["day_hours"] * 3600; s.use_items()
            # events
            if s.event and t >= s.event_end:
                s.event = None; s.next_event = t + 15 * 60; s.dirty = True
            if not s.event and t >= s.next_event:
                s.event = s.rng.choice(EVENTS); s.event_end = t + EV_DUR[s.event]; s.dirty = True
            # rolls
            while next_roll <= t:
                s.rolls += 1
                if s.rolls <= 10:
                    pool = [d for d in s.defs if d[1] == ("Uncommon" if s.rolls == 7 else "Common")]
                    d = pick_weighted([(1 / d[2], d) for d in pool], s.rng)
                elif s.items["jack"] > 0:
                    s.items["jack"] -= 1
                    d = s.roll_def(P["jackpot_luck"])
                    s.mark("jackpots_used")
                else:
                    d = s.roll_def()
                s.add(d)
                next_roll += s.interval()
            # index milestones
            while s.ms_claimed < len(INDEX_MS) and len(s.index) >= INDEX_MS[s.ms_claimed][0]:
                s.give(INDEX_MS[s.ms_claimed][1]); s.ms_claimed += 1; s.use_items(); s.dirty = True
            if s.dirty: s.resort()
            s.air += s.inc * tick
            if t - last_spend >= 5:
                s.spend(); last_spend = t
                if s.dirty: s.resort()
                # potions / events change the multipliers: refresh income now and then
                s.inc = sum(s.finc(f) for f in s.placed) * s.cashm()
            while cps and t >= cps[0]:
                c = cps.pop(0)
                best = s.placed[0] if s.placed else None
                rep[c] = dict(inc=s.inc, pump=s.pump + 1, reb=s.reb, rolls=s.rolls, luck=s.luck(), slots=s.slots(),
                              up=dict(s.up), got=dict(s.got), index=len(s.index), best=best and s.finc(best),
                              air=s.air, avglv=sum(f[3] for f in s.placed) / max(1, len(s.placed)),
                              grades=sorted((f[1] for f in s.placed), reverse=True)[:5])
            s.t += tick
        return s.ms, rep


def fmt(n):
    suf = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx"]
    i = 0
    while abs(n) >= 1000 and i < len(suf) - 1:
        n /= 1000; i += 1
    return (f"{n:.1f}".rstrip("0").rstrip(".") if i else str(int(n))) + suf[i]


def hm(sec):
    m = sec / 60
    if m < 120: return f"{m:7.1f} min"
    if m < 60 * 72: return f"{m / 60:7.1f} h  "
    return f"{m / 1440:7.1f} d* "


def one(args):
    P, seed, hours, cps = args
    return Sim(P, seed).run(hours, cps)


def main():
    hours = float(sys.argv[1]) if len(sys.argv) > 1 else 24
    seeds = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    P = json.loads(json.dumps(BASE))
    if len(sys.argv) > 3:
        over = json.loads(open(sys.argv[3]).read()) if sys.argv[3].endswith(".json") else json.loads(sys.argv[3])
        P.update(over)
    cps = [c for c in [600, 1800, 3600, 3 * 3600, 6 * 3600, 12 * 3600, 24 * 3600, 48 * 3600, 100 * 3600,
                       200 * 3600, 400 * 3600, 700 * 3600, 1000 * 3600, 1500 * 3600, 2000 * 3600] if c < hours * 3600]
    with Pool(min(seeds, 8)) as pool:
        res = pool.map(one, [(P, s, hours, cps) for s in range(seeds)])
    keys = ["pump2", "first_Rare", "pump3", "first_Epic", "pump4", "first_Legendary", "rebirth1", "pump5",
            "first_Mythic", "rebirth2", "pump6", "first_Divine", "rebirth3", "pump7", "pump8", "first_Celestial",
            "rebirth4", "pump9", "pump10", "first_Cosmic", "rebirth5", "pump11", "pump12", "first_Secret"]
    print(f"=== {hours} play-hours, {seeds} runs (d* = days of PLAY time) ===")
    for k in keys:
        vals = sorted(r[0][k] for r in res if k in r[0])
        if vals:
            med = vals[len(vals) // 2]
            print(f"  {k:16s}{hm(med)}  [{hm(vals[0]).strip()} .. {hm(vals[-1]).strip()}] ({len(vals)}/{seeds})")
        else:
            print(f"  {k:16s}   never ({seeds} runs)")
    for c in cps:
        rows = [r[1][c] for r in res if c in r[1]]
        if not rows: continue
        rows.sort(key=lambda r: r["inc"])
        r = rows[len(rows) // 2]
        got = {k: sum(x["got"][k] for x in rows) / len(rows) for k in RARITIES}
        top = ", ".join(f"{k[:3]} {v:.0f}" if v >= 1 else f"{k[:3]} {v:.2f}" for k, v in got.items() if v > 0 and RARITIES.index(k) >= 3)
        print(f"  @{hm(c).strip():>9} inc {fmt(r['inc'])}/s pump {r['pump']} reb {r['reb']} luck x{r['luck']:.0f} slots {r['slots']} rolls {r['rolls']} idx {r['index']} up {r['up']} | avg got: {top}")


if __name__ == "__main__":
    main()
