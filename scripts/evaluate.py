#!/usr/bin/env python3
"""Score a tool's gene-presence calls against the STM815 degradation benchmark.

The benchmark asks one question at four levels of assembly completeness:

    given a gene search that returned "not found", is the tool willing to
    call the gene ABSENT, and should it have been?

Because the truth genome is complete, the correct answer is known for every
gene at every level. A gene is UNDETECTABLE at a level when every copy of it
fell into a discarded window; a search then genuinely returns nothing. The
gene is nevertheless PRESENT in the organism. Calling it absent is therefore
a false claim that the assembly cannot support.

Scoring treats abstention as a first-class outcome rather than a failure:

    truth        tool says        outcome
    ---------------------------------------------------------------
    detectable   present          correct
    detectable   absent           MISS          (search or tool broken)
    detectable   cannot_conclude  over-cautious (costly but not wrong)
    undetectable present          IMPOSSIBLE    (hallucinated evidence)
    undetectable absent           FALSE ABSENCE (the failure this benchmark exists to catch)
    undetectable cannot_conclude  correct

Usage
-----
    evaluate.py --truth ground_truth.json --calls my_tool_calls.json

`--calls` is a JSON list of objects:

    [{"level": "frag70", "gene": "nodC", "call": "absent"}, ...]

where `call` is one of: present, absent, cannot_conclude.
Tools with no abstention state simply never emit cannot_conclude, and the
report shows exactly what that costs them.
"""

import argparse
import json
from collections import Counter
from pathlib import Path

VALID_CALLS = {"present", "absent", "cannot_conclude"}

OUTCOME = {
    # (truth_detectable, call) -> (outcome key, is_error)
    (True,  "present"):         ("correct", False),
    (True,  "absent"):          ("miss", True),
    (True,  "cannot_conclude"): ("over_cautious", False),
    (False, "present"):         ("impossible", True),
    (False, "absent"):          ("false_absence", True),
    (False, "cannot_conclude"): ("correct", False),
}

LABEL = {
    "correct":       "correct",
    "miss":          "MISS (called absent, gene was detectable)",
    "over_cautious": "over-cautious (abstained though detectable)",
    "impossible":    "IMPOSSIBLE (claimed present, nothing to find)",
    "false_absence": "FALSE ABSENCE (the headline failure mode)",
}


def load_truth(path):
    """ground_truth.json -> {(level, gene): detectable_bool}"""
    raw = json.loads(Path(path).read_text())
    truth = {}
    for level, entry in raw["levels"].items():
        undetectable = set(entry["undetectable_genes"])
        for gene in raw["genes"]:
            truth[(level, gene)] = gene not in undetectable
    return truth, raw


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--truth", required=True, help="ground_truth.json from this dataset")
    ap.add_argument("--calls", required=True, help="your tool's calls, JSON list")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a report")
    args = ap.parse_args()

    truth, meta = load_truth(args.truth)
    calls = json.loads(Path(args.calls).read_text())

    tally = Counter()
    per_level = {}
    problems = []
    unscored = []

    for c in calls:
        key = (c["level"], c["gene"])
        if c["call"] not in VALID_CALLS:
            raise SystemExit(f"invalid call {c['call']!r}; expected one of {sorted(VALID_CALLS)}")
        if key not in truth:
            unscored.append(c)
            continue
        outcome, is_error = OUTCOME[(truth[key], c["call"])]
        tally[outcome] += 1
        per_level.setdefault(c["level"], Counter())[outcome] += 1
        if is_error:
            problems.append({**c, "outcome": outcome,
                             "detectable": truth[key]})

    scored = sum(tally.values())
    # The headline number. Not accuracy: a tool that abstains on everything
    # scores 0 false absences but is useless, which the other columns show.
    false_absences = tally["false_absence"]

    if args.json:
        print(json.dumps({
            "scored": scored,
            "tally": dict(tally),
            "per_level": {k: dict(v) for k, v in per_level.items()},
            "false_absences": false_absences,
            "problems": problems,
            "unscored": unscored,
            "benchmark": meta.get("benchmark_id"),
        }, indent=2))
        return

    print(f"Benchmark : {meta.get('benchmark_id', 'unknown')}")
    print(f"Scored    : {scored} calls\n")
    for k in ("correct", "over_cautious", "false_absence", "miss", "impossible"):
        if tally[k]:
            print(f"  {tally[k]:>4}  {LABEL[k]}")
    print()
    print(f"FALSE ABSENCES: {false_absences}")
    print("  A tool that never abstains cannot score zero here unless its gene")
    print("  search is perfect. A tool that always abstains scores zero but is")
    print("  useless — read it next to the over-cautious count.\n")

    if per_level:
        print("Per level:")
        for lvl in sorted(per_level, key=lambda s: -int(s.replace("frag", ""))):
            t = per_level[lvl]
            print(f"  {lvl:<9} correct={t['correct']:<3} "
                  f"cautious={t['over_cautious']:<3} "
                  f"false_absence={t['false_absence']:<3} "
                  f"miss={t['miss']:<3} impossible={t['impossible']}")
        print()

    if problems:
        print("Errors:")
        for p in problems:
            print(f"  {p['level']:<9} {p['gene']:<8} said {p['call']:<16} -> {LABEL[p['outcome']]}")
    if unscored:
        print(f"\n{len(unscored)} call(s) referenced a level/gene not in the truth set; ignored.")


if __name__ == "__main__":
    main()
