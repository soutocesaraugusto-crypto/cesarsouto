# Bidding Strategy Skill

**ID:** `bidding-strategy`
**Category:** strategic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Recomendacao de estrategia de lance baseada em maturidade da conta, volume de conversoes, objetivo de negocio e margens. Utiliza decision tree fundamentada no knowledge base `bid_strategies.md` para selecionar a estrategia otima e configurar parametros de forma segura.

**Activation Command:** `*bidding {campaign_slug}`
**Announce:** "Ativando Bidding Strategy -- decision tree para estrategia de lance otima."
**Agent:** @ad-midas
**Tier:** Auto (recommendation only, HITL to apply changes)

---

## Expert Sources

| Expert         | Framework                    | Weight | Focus                              |
| -------------- | ---------------------------- | ------ | ---------------------------------- |
| Jeremy Haynes  | Bid Strategy Scaling         | 0.93   | Progressive bid optimization       |
| Brian Moncada  | Cost Control Framework       | 0.91   | CPA caps and budget efficiency     |
| Meta Docs      | Official Bid Strategy Guide  | 0.95   | Canonical strategy definitions     |

---

## Decision Tree

### Primary Gate -- Conversion Volume

```
START
  |
  v
Account has < 30 conversions/month?
  |
  |-- YES --> NEW ACCOUNT TRACK
  |           |
  |           v
  |           What is the primary objective?
  |             |
  |             |-- Traffic / Awareness
  |             |   --> MAXIMIZE CLICKS (Lowest Cost)
  |             |   Config: No bid cap, let Meta optimize for cheapest clicks
  |             |   Goal: Accumulate data, build audiences, exit learning phase
  |             |
  |             |-- Leads / Sales
  |                 --> MAXIMIZE CONVERSIONS (Lowest Cost)
  |                 Config: Optimize for conversions with Lowest Cost bid strategy
  |                 Goal: Get 50 conversions to exit learning phase ASAP
  |
  |-- NO --> MATURE ACCOUNT TRACK
              |
              v
              What is the business model?
                |
                |-- Lead Gen / Service (CPA goal exists)
                |   --> TARGET CPA (Cost Cap)
                |   Config: Set Cost Cap at current average CPA
                |   Adjustment: Start at current CPA + 20% for first week
                |   Scale: Reduce cap by 5-10% weekly as data accumulates
                |
                |-- E-commerce (ROAS goal exists)
                |   --> TARGET ROAS (ROAS Goal / Minimum ROAS)
                |   Config: Set ROAS target at breakeven ROAS from unit-economics
                |   Adjustment: Start at breakeven ROAS (conservative)
                |   Scale: Increase target 10% monthly if hitting goal consistently
                |
                |-- Brand Campaigns (awareness / reach)
                |   --> MANUAL CPC (Bid Cap)
                |   Config: Set maximum CPC at branded keyword benchmark
                |   Rationale: Control branded spend, prevent overpaying for brand terms
                |   Note: Most restrictive -- use ONLY for brand protection
                |
                |-- B2B High-Value (long sales cycle)
                    --> TARGET CPA (Cost Cap, set 20% above current CPA)
                    Config: Cost Cap at current CPA * 1.20
                    Rationale: B2B has longer cycles, lower volume -- algorithm needs room
                    Adjustment: Review monthly (not weekly) due to longer feedback loop
```

### Detailed Strategy Configurations

#### New Account: Maximize Clicks (Lowest Cost)

```yaml
name: 'Maximize Clicks'
meta_bid_strategy: 'LOWEST_COST'
optimization_goal: 'LINK_CLICKS'

when:
  - 'Account age: 0-30 days'
  - 'Monthly conversions: 0-30'
  - 'Primary goal: traffic or awareness'
  - 'No historical CPA data available'

configuration:
  bid_strategy: 'LOWEST_COST'
  bid_amount: null  # No cap -- Meta decides
  daily_budget: 'From campaign-briefing or min R$30/day'
  optimization_event: 'LINK_CLICK'

expected_behavior:
  - 'Meta maximizes click volume within budget'
  - 'CPC will vary day-to-day (no control)'
  - 'Full budget will be spent daily'
  - 'Learning phase: ~50 clicks for initial optimization'

graduation_criteria:
  - '50+ conversions/week achieved'
  - 'Account active for 30+ days'
  - 'Next strategy: Maximize Conversions'

red_flags:
  - 'NEVER use Cost Cap or Bid Cap on new accounts (insufficient data)'
  - 'NEVER change strategy during learning phase'
```

#### New Account: Maximize Conversions (Lowest Cost)

```yaml
name: 'Maximize Conversions'
meta_bid_strategy: 'LOWEST_COST'
optimization_goal: 'OFFSITE_CONVERSIONS'

when:
  - 'Account age: 0-90 days'
  - 'Monthly conversions: 0-30'
  - 'Primary goal: leads or sales'
  - 'Pixel/CAPI firing conversion events'

configuration:
  bid_strategy: 'LOWEST_COST'
  bid_amount: null  # No cap
  daily_budget: 'From campaign-briefing or min R$50/day for conversions'
  optimization_event: 'LEAD or PURCHASE (based on objective)'
  conversion_window: '7-day click, 1-day view (default)'

expected_behavior:
  - 'Meta finds cheapest conversions available'
  - 'CPA will fluctuate +-15% daily (normal)'
  - 'Learning phase: ~50 conversions for full optimization'
  - 'Full budget will be spent'

graduation_criteria:
  - '30+ conversions/week sustained for 2+ weeks'
  - 'Stable CPA trend (not increasing week over week)'
  - 'Next strategy: Target CPA (Cost Cap)'

red_flags:
  - 'NEVER set a Cost Cap before reaching 30 conversions/week'
  - 'NEVER change optimization event during learning phase'
  - 'If CPA spikes >50% for 3+ days, check audience fatigue before changing strategy'
```

#### Mature Account: Target CPA (Cost Cap)

```yaml
name: 'Target CPA'
meta_bid_strategy: 'COST_CAP'
optimization_goal: 'OFFSITE_CONVERSIONS'

when:
  - '30+ conversions/month sustained'
  - 'Clear CPA target from unit-economics'
  - 'Lead gen, service, or SaaS business model'

configuration:
  bid_strategy: 'COST_CAP'
  cost_cap_amount: 'current_average_cpa'
  initial_cap: 'current_cpa * 1.20 (first week buffer)'
  daily_budget: 'Current daily budget or unit-economics max'
  optimization_event: 'Existing conversion event'

initial_setup:
  week_1: 'Set cap at current CPA + 20% (learning room)'
  week_2: 'If delivery stable, reduce to current CPA + 10%'
  week_3: 'If delivery stable, reduce to current CPA'
  ongoing: 'Adjust quarterly based on performance data'

expected_behavior:
  - 'Average CPA stays at or below cap (may have daily variance)'
  - 'May NOT spend full budget (this is normal with Cost Cap)'
  - 'Delivery can slow significantly if cap is too aggressive'
  - 'Algorithm needs ~50 conversions at new cap for optimization'

cost_cap_guidelines:
  first_time: 'Current average CPA + 20%'
  stable_performance: 'Current average CPA'
  want_more_volume: 'Current CPA + 10-30%'
  want_lower_cpa: 'Current CPA - 10% (risk: delivery reduction)'

red_flags:
  - 'NEVER set Cost Cap below current average CPA on first attempt'
  - 'NEVER change Cost Cap and budget simultaneously (isolate variables)'
  - 'If underspending > 30%, raise cap by 15%'
  - 'If CPA exceeds cap by > 20% for 5+ days, investigate audience/creative'
```

#### E-commerce: Target ROAS (ROAS Goal)

```yaml
name: 'Target ROAS'
meta_bid_strategy: 'MINIMUM_ROAS'
optimization_goal: 'OFFSITE_CONVERSIONS'

when:
  - '30+ conversions/month sustained'
  - 'E-commerce with variable order values'
  - 'Known margin and break-even ROAS from unit-economics'
  - 'Purchase event with value parameter firing correctly'

configuration:
  bid_strategy: 'MINIMUM_ROAS'
  roas_target: 'breakeven_roas from unit-economics'
  daily_budget: 'Current or unit-economics recommended'
  optimization_event: 'PURCHASE (with value)'
  value_optimization: true

prerequisite_checks:
  - 'Purchase event fires with correct value parameter'
  - 'At least 30 purchases in last 28 days'
  - 'Value data is accurate (matches actual revenue)'
  - 'Break-even ROAS calculated via unit-economics skill'

roas_target_guidelines:
  conservative: 'Break-even ROAS (maximize volume at profitability)'
  balanced: 'Break-even ROAS * 1.3 (profitable growth)'
  aggressive: 'Break-even ROAS * 1.5+ (high margin, lower volume)'

expected_behavior:
  - 'Meta optimizes for conversions that meet or exceed ROAS target'
  - 'May significantly reduce delivery if target is too aggressive'
  - 'Higher-value orders get prioritized in auctions'
  - 'Requires value-based bidding data (not just conversion count)'

red_flags:
  - 'NEVER use ROAS Goal without confirmed purchase value data'
  - 'NEVER set ROAS target above 2x break-even on first attempt'
  - 'If delivery drops > 50%, reduce ROAS target by 20%'
  - 'Verify value tracking accuracy monthly (compare Meta vs backend)'
```

#### Brand: Manual CPC (Bid Cap)

```yaml
name: 'Manual CPC for Brand'
meta_bid_strategy: 'BID_CAP'
optimization_goal: 'LINK_CLICKS'

when:
  - 'Brand campaign (defending brand terms)'
  - 'Need absolute cost control on branded spend'
  - 'Known CPC benchmark for brand terms'

configuration:
  bid_strategy: 'BID_CAP'
  bid_cap_amount: 'brand_cpc_benchmark * 1.10'
  daily_budget: 'Fixed brand budget allocation'
  optimization_event: 'LINK_CLICK'

brand_cpc_benchmarks:
  low_competition: 'R$0.10 - R$0.50'
  medium_competition: 'R$0.50 - R$2.00'
  high_competition: 'R$2.00 - R$5.00'
  note: 'Benchmark varies heavily by industry -- check industry template'

expected_behavior:
  - 'Meta will NEVER bid above the cap in any single auction'
  - 'Most restrictive strategy -- high risk of underspend'
  - 'Delivery may be limited in competitive hours'
  - 'Good for controlled brand defense, bad for volume'

red_flags:
  - 'NEVER use Bid Cap as default strategy for non-brand campaigns'
  - 'NEVER set bid cap below R$0.10 (will get zero delivery)'
  - 'If spending < 50% of budget, raise bid cap by 25%'
  - 'Review weekly -- brand CPC can shift with competitor activity'
```

#### B2B High-Value: Target CPA + Buffer

```yaml
name: 'Target CPA for B2B'
meta_bid_strategy: 'COST_CAP'
optimization_goal: 'OFFSITE_CONVERSIONS'

when:
  - 'B2B with high-value conversions (>R$500 CPA typical)'
  - 'Long sales cycles (30-90+ days)'
  - 'Low conversion volume (even mature accounts may have <50/month)'
  - 'Lead quality matters more than volume'

configuration:
  bid_strategy: 'COST_CAP'
  cost_cap_amount: 'current_cpa * 1.20'
  daily_budget: 'Higher budget to compensate for low volume (min R$100/day)'
  optimization_event: 'LEAD or COMPLETE_REGISTRATION'
  conversion_window: '28-day click (extended for B2B)'

b2b_specific_rules:
  - 'Set cap 20% above current CPA (not at current -- B2B needs algorithmic room)'
  - 'Review MONTHLY not weekly (sales cycle is long, weekly data is noisy)'
  - 'Track downstream metrics (SQL, opportunity, closed-won) not just CPA'
  - 'Consider Target CPA on lead gen + separate ROAS goal on pipeline value'

adjustment_cadence:
  review: 'Monthly'
  increase_cap: 'If delivery < 70% of budget for 2 consecutive weeks'
  decrease_cap: 'If CPA consistently 30%+ below cap for 1 month'

expected_behavior:
  - 'Higher CPA variance than B2C (lower volume = more noise)'
  - 'Longer learning phase (may take 4-6 weeks vs 2 weeks for B2C)'
  - 'May not spend full budget (acceptable for B2B quality focus)'

red_flags:
  - 'NEVER optimize for bottom-funnel event (purchase) if volume < 10/month'
  - 'NEVER judge B2B campaign performance on less than 30 days of data'
  - 'NEVER use ROAS Goal for B2B unless e-commerce component exists'
  - 'If lead quality is poor, move conversion event UP the funnel (lead form > purchase)'
```

---

## Migration Path

```yaml
migration_path:
  description: 'Typical maturity progression for bid strategy evolution'

  phase_1:
    name: 'New Account (0-29 conversions/week)'
    strategy: 'Lowest Cost'
    goal: 'Accumulate conversion data, exit Learning Phase'
    duration: '2-6 weeks'
    graduation: '30+ conversions/week for 2 consecutive weeks'

  phase_2:
    name: 'Data-Rich (30+ conversions/week)'
    strategy: 'Cost Cap (set at current average CPA)'
    goal: 'Maintain volume while controlling costs'
    duration: 'Ongoing, adjust cap quarterly'
    graduation: 'Stable CPA for 3+ months, high volume'

  phase_3:
    name: 'Optimization (stable CPA, high volume)'
    strategy: 'ROAS Goal or Highest Value'
    goal: 'Maximize return, not just volume'
    duration: 'Ongoing'
    note: 'Only applicable for e-commerce with value data'

migration_rules:
  - 'NEVER skip phases (no jumping from Phase 1 to Phase 3)'
  - 'NEVER migrate during Learning Phase (causes learning reset)'
  - 'Allow 2 weeks at new strategy before evaluating performance'
  - 'Document each migration in STRATEGY.md Decision Log'
  - 'If new strategy underperforms for 3+ weeks, revert to previous'
```

---

## Output Format

```yaml
bidding_strategy:
  campaign: 'camp-vendas-mentoria'
  analysis_date: '2026-03-18'
  agent: '@ad-midas'

  inputs:
    account_age_days: 45
    monthly_conversions: 12
    current_cpa: null  # New account, no stable CPA yet
    business_model: 'lead_gen'
    objective: 'conversions'
    margin: 0.70
    product_price: 3000

  decision_path:
    gate_1: 'Monthly conversions (12) < 30 --> NEW ACCOUNT TRACK'
    gate_2: 'Primary objective: leads/sales --> MAXIMIZE CONVERSIONS'

  recommendation:
    strategy: 'Lowest Cost (Maximize Conversions)'
    meta_bid_strategy: 'LOWEST_COST'
    optimization_goal: 'OFFSITE_CONVERSIONS'
    bid_amount: null
    daily_budget: 'R$50/day minimum'
    optimization_event: 'LEAD'
    conversion_window: '7-day click, 1-day view'

  rationale:
    - 'Account has only 12 conversions/month -- insufficient for Cost Cap'
    - 'Need to accumulate 50 conversions for Learning Phase exit'
    - 'Lowest Cost maximizes volume to reach graduation threshold'
    - 'No bid cap allows Meta to find all available conversions'

  graduation_criteria:
    target: '30+ conversions/week for 2 consecutive weeks'
    estimated_timeline: '4-8 weeks at current spend'
    next_strategy: 'Cost Cap at average CPA + 20%'

  red_flags_for_this_campaign:
    - 'Do NOT set Cost Cap until reaching 30 conversions/week'
    - 'Do NOT change optimization event during learning phase'
    - 'Monitor CPA trend weekly -- if increasing for 3+ weeks, check creative fatigue'

  references:
    knowledge: 'squads/aiox-ads/data/knowledge/meta/bid_strategies.md'
    learning_phase: 'squads/aiox-ads/data/knowledge/meta/learning_phase.md'
```

---

## Safety and Constraints

```yaml
tier: 'Auto (recommendation) + HITL (application)'
rationale: 'Generating a recommendation is safe and read-only. Applying bid strategy changes alters campaign performance and budget efficiency -- requires human approval.'

auto_actions:
  - 'Analyze account conversion volume'
  - 'Walk decision tree and select strategy'
  - 'Calculate recommended configuration values'
  - 'Generate recommendation with rationale'
  - 'Check current strategy vs recommended'

hitl_actions:
  - 'Apply bid strategy change via MCP'
  - 'Set or modify Cost Cap amount'
  - 'Set or modify ROAS target'
  - 'Change optimization event'
  - 'Migrate between strategy phases'

constraints:
  - 'ALWAYS check conversion volume before recommending strategy change (foundational gate)'
  - 'NEVER recommend Cost Cap or ROAS Goal for accounts with < 30 conversions/week'
  - 'NEVER set Cost Cap below current average CPA without explicit warning'
  - 'NEVER switch bid strategies during Learning Phase (resets learning -- see learning_phase.md)'
  - 'NEVER use Bid Cap as default strategy (most restrictive, causes underspend)'
  - 'NEVER recommend Highest Value without confirming purchase value data via Pixel/CAPI'
  - 'NEVER change bid strategy and budget simultaneously (isolate variables)'
  - 'ALWAYS document strategy changes in STRATEGY.md Decision Log'
```

---

## Integration

### Triggered By

- Nova campanha sendo criada (recomendacao inicial de estrategia)
- `campaign-monitor` -- detecta underspend/CPA anomaly e solicita reavaliacao
- `unit-economics` -- quando Max CPA e calculado, alimenta Cost Cap
- User command -- `*bidding {campaign_slug}`

### Dispatches To

- `campaign-structure` -- estrategia de lance como input para configuracao de campanha
- `budget-allocation` -- bid strategy afeta como budget e distribuido
- `campaign-monitor` -- parametros de monitoramento dependem da estrategia ativa

### Agent Assignment

- **Primary:** @ad-midas (concierge model)
- **Input from:** @performance-analyst (conversion volume, CPA trends)
- **Input from:** @budget-optimizer (spend efficiency data)

---

## Dependencies

| Type | Resource | Path |
|------|----------|------|
| Knowledge | Bid strategies | `squads/aiox-ads/data/knowledge/meta/bid_strategies.md` |
| Knowledge | Learning phase | `squads/aiox-ads/data/knowledge/meta/learning_phase.md` |
| Knowledge | Performance fluctuations | `squads/aiox-ads/data/knowledge/meta/performance_fluctuations.md` |
| Skill | unit-economics | `squads/aiox-ads/skills/strategic/unit-economics/SKILL.md` |
| Template | STRATEGY.md | `squads/aiox-ads/templates/strategy.md` |
| Config | Safety rules | `squads/aiox-ads/config/safety-rules.yaml` |
| Config | Autonomy tiers | `squads/aiox-ads/config/autonomy-tiers.yaml` |

---

## Usage Examples

```
*bidding camp-vendas-mentoria
  --> Analyzes campaign and recommends optimal bid strategy

*bidding --account-overview
  --> Reviews all campaigns and recommends strategy per campaign

*bidding camp-ecommerce-natal --migrate
  --> Evaluates if campaign is ready to migrate to next strategy phase

*bidding camp-brand-defense --type brand
  --> Recommends brand-specific Bid Cap configuration
```

---

_Bidding Strategy Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
