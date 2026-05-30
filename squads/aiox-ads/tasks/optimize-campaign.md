---
task_id: optimize-campaign
version: 1.0
category: ads_optimization
squad: aiox-ads
agent: performance-analyst
elicit: true
---

# Optimize Campaign — Diagnose & Improve Performance

## Process

1. **Collect metrics** -- Request current campaign data:
   - CPA, ROAS, CTR, CVR, CPM, Frequency
   - Time period (minimum 7 days for meaningful analysis)
   - Target KPIs for comparison
2. **Diagnose root cause** -- Identify why metrics are off:
   - High CPA: audience saturation, creative fatigue, tracking issues
   - Low ROAS: wrong audience, weak offer, funnel leak
   - Low CTR: creative fatigue, wrong placement, poor targeting
3. **Apply kill/scale rules**:
   - Kill: CPA > 3x target (pause immediately)
   - Watch: CPA > 1.5x target (reduce budget, monitor)
   - Scale: ROAS > target for 7+ days (+20% budget max)
4. **Adjust budget** -- Redistribute from underperformers to winners
5. **Refresh creatives** -- Delegate to creative-analyst if fatigue detected
6. **Document changes** -- Record baseline, changes made, expected impact

## Output

Write optimization report with before/after metrics, actions taken, and monitoring plan.
