"""Fit Pump prices and the rebirth cost list to target play-hours (PUMP_T, REB_T below)
with tools/econ_sim.py. Writes the fitted numbers to out.json; copy them into ConfigParts.
Usage: python tools/econ_fit.py start.json out.json HOURS RUNS ITERATIONS   (start.json may be {})"""
import json, sys, math
from multiprocessing import Pool
import econ_sim as econ16

PUMP_T = {3: 25 / 60, 4: 1.5, 5: 5, 6: 14, 7: 35, 8: 80, 9: 160, 10: 300, 11: 500, 12: 800}
REB_T = [3, 10, 30, 75, 150, 300, 500, 800]


def nice(x):
    e = math.floor(math.log10(x))
    return round(x / 10 ** (e - 1)) * 10 ** (e - 1)


def medians(P, hours, seeds):
    with Pool(min(seeds, 8)) as pool:
        res = pool.map(econ16.one, [(P, s, hours, []) for s in range(seeds)])
    out = {}
    for k in set().union(*[r[0].keys() for r in res]):
        vals = sorted(r[0][k] for r in res if k in r[0])
        if len(vals) * 2 > seeds:
            # median over ALL runs (runs that never got there count as "later than everyone")
            out[k] = vals[seeds // 2] if seeds // 2 < len(vals) else None
    return out


def adjust(price, target_h, got_s, lo=0.25, hi=4.0):
    if got_s is None:
        return price * 0.5, "never"
    f = min(max((target_h / max(got_s / 3600, 1e-3)) ** 0.8, lo), hi)
    return price * f, f"{got_s/3600:.1f}h"


def main():
    P = json.loads(json.dumps(econ16.BASE))
    P.update(json.load(open(sys.argv[1])))
    out, hours, seeds, iters = sys.argv[2], float(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
    if "rebirth_costs" not in P:
        P["rebirth_costs"] = [econ16.rebirth_cost(P, n) for n in range(len(REB_T))]
    for it in range(iters):
        m = medians(P, hours, seeds)
        line = []
        for k, th in PUMP_T.items():
            if th > hours: continue
            i = k - 1
            p, txt = adjust(P["pump_price"][i], th, m.get("pump%d" % k))
            P["pump_price"][i] = nice(p)
            line.append(f"p{k} {txt}")
        for n, th in enumerate(REB_T):
            if th > hours: continue
            c, txt = adjust(P["rebirth_costs"][n], th, m.get("rebirth%d" % (n + 1)))
            P["rebirth_costs"][n] = nice(c)
            line.append(f"r{n+1} {txt}")
        # both ladders must keep climbing
        for lst in (P["pump_price"], P["rebirth_costs"]):
            for i in range(1, len(lst)):
                if lst[i] <= lst[i - 1] * 1.5:
                    lst[i] = nice(lst[i - 1] * 1.5)
        print(f"iter {it}: " + "  ".join(line), flush=True)
        print("   pumps  ", [econ16.fmt(p) for p in P["pump_price"]], flush=True)
        print("   rebirth", [econ16.fmt(p) for p in P["rebirth_costs"]], flush=True)
        json.dump({k: P[k] for k in ("odds", "upg", "pump_luck", "pump_price", "rebirth_base", "rebirth_growth", "rebirth_costs")}, open(out, "w"))


if __name__ == "__main__":
    main()
