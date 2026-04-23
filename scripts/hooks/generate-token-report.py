#!/usr/bin/env python3
"""
Generate per-step token report after approve/collect.
Usage: python3 scripts/hooks/generate-token-report.py --step N
"""

import json, sys, argparse
from pathlib import Path
from datetime import datetime

REPO      = Path(__file__).resolve().parent.parent.parent
CACHE     = REPO / ".cache" / "mcp"
EVENTS_F  = CACHE / "events.jsonl"
STATS_F   = CACHE / "session-stats.json"
STATE_F   = REPO / "workflow-state.json"

PRICE = {"input": 3.0, "output": 15.0}

def load_events():
    if not EVENTS_F.exists(): return []
    lines = EVENTS_F.read_text().strip().split("\n")
    events = []
    for l in lines:
        try: events.append(json.loads(l))
        except: pass
    return events

def load_stats():
    if not STATS_F.exists(): return {}
    try: return json.loads(STATS_F.read_text())
    except: return {}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--step", type=int)
    args = parser.parse_args()

    state = {}
    try: state = json.loads(STATE_F.read_text())
    except: pass

    step = args.step or state.get("current_step", 0)
    # After approve, current_step has advanced — use step-1 unless explicitly given
    if not args.step and step > 1:
        step = step - 1

    step_name = (state.get("steps", {}).get(str(step), {}) or {}).get("name", f"Step {step}")
    events    = load_events()
    stats     = load_stats()

    # Per-tool breakdown from session stats
    tools = stats.get("tools", {})
    consumed  = stats.get("total_consumed_tokens", 0)
    saved     = stats.get("total_saved_tokens", 0)
    cost_usd  = stats.get("total_cost_usd", 0)
    saved_usd = stats.get("total_saved_usd", 0)
    waste_tok = stats.get("bash_waste_tokens", 0)
    eff       = saved / (consumed + saved) * 100 if (consumed + saved) else 0

    # Top wasteful bash commands
    bash_waste = [(e.get("cmd",""), e.get("waste_tokens",0), e.get("suggestion",""))
                  for e in events if e.get("type") == "bash" and e.get("waste_tokens", 0) > 0]
    bash_waste.sort(key=lambda x: -x[1])

    # Low hit rate tools
    low_hit = [(n, t.get("hits",0)/t.get("calls",1), t.get("calls",0))
               for n, t in tools.items() if t.get("calls",0) >= 3 and t.get("hits",0)/t.get("calls",1) < 0.7]

    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    lines = [
        f"# Token Report — Step {step}: {step_name}",
        f"Generated: {now}",
        "",
        "## Summary",
        "",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Total consumed (est.) | ~{consumed:,} tokens |",
        f"| Total saved (est.)    | ~{saved:,} tokens |",
        f"| Efficiency            | {eff:.0f}% |",
        f"| Cost (est.)           | ${cost_usd:.4f} |",
        f"| Saved cost (est.)     | ${saved_usd:.4f} |",
        f"| Bash waste            | ~{waste_tok:,} tokens |",
        "",
        "## Per-Tool Cache Performance",
        "",
        "| Tool | Calls | Hit Rate | Tokens Saved |",
        "|------|-------|----------|-------------|",
    ]
    for name, t in sorted(tools.items(), key=lambda x: -x[1].get("saved",0)):
        calls = t.get("calls", 0)
        rate  = t.get("hits", 0) / calls if calls else 0
        sv    = t.get("saved", 0)
        flag  = " ⚠️" if rate < 0.7 and calls >= 3 else ""
        lines.append(f"| `{name}` | {calls} | {rate:.0%}{flag} | ~{sv:,} |")

    if bash_waste:
        lines += ["", "## Top Token Waste (bash instead of MCP)", ""]
        seen = {}
        for cmd, waste, suggestion in bash_waste[:8]:
            key = cmd[:40]
            if key in seen: seen[key]["count"] += 1; seen[key]["waste"] += waste; continue
            seen[key] = {"cmd": cmd, "waste": waste, "suggestion": suggestion, "count": 1}
        for v in sorted(seen.values(), key=lambda x: -x["waste"])[:5]:
            times = f" ×{v['count']}" if v["count"] > 1 else ""
            lines.append(f"- `{v['cmd'][:60]}`{times} → **~{v['waste']:,} tokens wasted**")
            if v["suggestion"]:
                lines.append(f"  → Use `{v['suggestion']}` instead")

    if low_hit:
        lines += ["", "## Low Cache Hit Rate (needs investigation)", ""]
        for name, rate, calls in low_hit:
            lines.append(f"- `{name}`: {rate:.0%} hit rate over {calls} calls — check invalidation strategy")

    lines += [
        "",
        "## Recommendations",
        "",
        "- Run `wf_set_agent(agent_id)` at start of each agent session for attribution",
        "- Replace all `cat`, `git log`, `ls` with MCP tools",
        "- Check low hit rate tools — may need TTL adjustment",
    ]

    report_path = REPO / "workflows" / "dispatch" / f"step-{step}" / "token-report.md"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines) + "\n")
    print(f"Token report: {report_path.relative_to(REPO)}")

    # Clear session stats for next step
    if STATS_F.exists():
        old = json.loads(STATS_F.read_text())
        # Archive and reset
        archive = REPO / ".cache" / "mcp" / f"session-stats-step{step}.json"
        archive.write_text(json.dumps(old, indent=2))
        STATS_F.write_text(json.dumps({
            "session_start": datetime.utcnow().isoformat() + "Z",
            "previous_step": step,
        }, indent=2))

if __name__ == "__main__":
    main()
