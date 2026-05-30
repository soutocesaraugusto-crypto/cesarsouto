# Funnel Analysis Skill

**ID:** `funnel-analysis`
**Category:** diagnostic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Análise completa de funil de conversão para identificar gargalos, drop-offs e oportunidades de otimização em cada etapa do processo de venda.

**Activation Command:** `*analyze-funnel`
**Announce:** "Ativando Funnel Analysis com frameworks Alex Hormozi e Jeremy Haynes."

---

## Expert Sources

| Expert        | Framework                  | Weight | Focus                |
| ------------- | -------------------------- | ------ | -------------------- |
| Alex Hormozi  | Funnel Conversion Analysis | 0.92   | Economia de funil    |
| Jeremy Haynes | E-commerce Funnel Health   | 0.90   | Métricas por etapa   |
| Jeremy Haynes | Mini Webinar 2.0           | 0.88   | Funis de high-ticket |

---

## Funnel Types

### 1. Direct Traffic Funnel

```
Ad → Landing Page → Checkout → Thank You

Benchmarks:
├── Ad → LP: CTR 1-3%
├── LP → Checkout: 5-15%
├── Checkout → Purchase: 30-60%
└── Overall: 0.5-3%
```

### 2. Lead Funnel

```
Ad → Landing Page → Lead Capture → Email Sequence → Sales Page → Checkout

Benchmarks:
├── Ad → LP: CTR 1-3%
├── LP → Lead: 20-40%
├── Lead → Open Email: 20-30%
├── Email → Sales Page: 5-15%
├── Sales → Checkout: 5-10%
└── Checkout → Purchase: 30-50%
```

### 3. Webinar Funnel (Mini Webinar 2.0)

```
Ad → Registration → Show Up → Watch → Application → Call → Close

Benchmarks (Jeremy Haynes):
├── Ad → Registration: 20-40%
├── Registration → Show Up: 30-50%
├── Show Up → Watch 50%+: 40-60%
├── Watch → Application: 10-20%
├── Application → Call: 50-70%
└── Call → Close: 20-40%
```

### 4. Funil de R$1

```
Ad → Checkout Low-Ticket → Upsell 1 → Upsell 2 → Backend

Benchmarks:
├── Ad → Checkout: 3-8%
├── Checkout → Purchase: 40-60%
├── Purchase → Upsell 1: 20-40%
├── Upsell 1 → Upsell 2: 15-30%
└── AOV Increase: 2-4x
```

---

## Analysis Framework

### Stage-by-Stage Analysis

```yaml
analysis_per_stage:
  - stage: 'ad_to_landing'
    metrics:
      - ctr
      - cpc
      - outbound_clicks
    benchmarks:
      good: '> 1.5%'
      average: '1-1.5%'
      poor: '< 1%'
    issues:
      low_ctr: 'Hook fraco ou audiência errada'
      high_cpc: 'Competição alta ou qualidade baixa'

  - stage: 'landing_to_action'
    metrics:
      - landing_page_views
      - add_to_cart
      - initiate_checkout
      - lead_submit
    benchmarks:
      ecommerce: '> 5% ATC'
      lead_gen: '> 25% lead'
    issues:
      low_conversion: 'Copy fraca, oferta ruim, página lenta'
      high_bounce: 'Mismatch ad vs landing'

  - stage: 'action_to_purchase'
    metrics:
      - checkout_started
      - payment_info_added
      - purchase_completed
    benchmarks:
      good: '> 50%'
      average: '30-50%'
      poor: '< 30%'
    issues:
      cart_abandonment: 'Preço, frete, confiança'
      checkout_drop: 'UX ruim, pagamento problemático'
```

### Drop-off Analysis

```javascript
function analyzeDropoffs(funnelData) {
  const stages = Object.keys(funnelData);
  const dropoffs = [];

  for (let i = 1; i < stages.length; i++) {
    const prevStage = stages[i - 1];
    const currStage = stages[i];
    const prevValue = funnelData[prevStage];
    const currValue = funnelData[currStage];

    const dropoffRate = ((prevValue - currValue) / prevValue) * 100;

    dropoffs.push({
      from: prevStage,
      to: currStage,
      dropoffRate,
      severity: getSeverity(dropoffRate, currStage),
      recommendation: getRecommendation(currStage, dropoffRate),
    });
  }

  return dropoffs.sort((a, b) => b.dropoffRate - a.dropoffRate);
}
```

---

## Output Format

```yaml
funnel_analysis:
  funnel_type: 'direct_traffic'
  analysis_date: '2026-02-01'
  period: 'last_7_days'

  overview:
    total_impressions: 50000
    total_clicks: 750
    total_conversions: 15
    overall_cvr: 2%
    target_cvr: 3%
    gap: -1%

  stages:
    - stage: 'ad_to_click'
      volume: 50000 → 750
      rate: 1.5%
      benchmark: 2%
      status: 'below_average'
      drop_off: 98.5%

    - stage: 'click_to_landing'
      volume: 750 → 680
      rate: 90.7%
      benchmark: 95%
      status: 'below_average'
      issue: 'Page load time'

    - stage: 'landing_to_atc'
      volume: 680 → 85
      rate: 12.5%
      benchmark: 8%
      status: 'above_average'

    - stage: 'atc_to_checkout'
      volume: 85 → 45
      rate: 52.9%
      benchmark: 60%
      status: 'below_average'
      issue: 'Cart abandonment'

    - stage: 'checkout_to_purchase'
      volume: 45 → 15
      rate: 33.3%
      benchmark: 50%
      status: 'critical'
      issue: 'Checkout drop-off'

  biggest_leaks:
    - stage: 'checkout_to_purchase'
      lost_potential: 22.5 conversões
      revenue_impact: 'R$ X'
      priority: 1

    - stage: 'atc_to_checkout'
      lost_potential: 6 conversões
      revenue_impact: 'R$ Y'
      priority: 2

  recommendations:
    - priority: 1
      stage: 'checkout_to_purchase'
      action: 'Adicionar trust signals, simplificar checkout'
      expected_impact: '+17% CVR = +7 conversões/semana'
      expert: 'Alex Hormozi'

    - priority: 2
      stage: 'ad_to_click'
      action: 'Testar novos hooks'
      expected_impact: '+0.5% CTR = +250 clicks/semana'
      expert: 'Jeremy Haynes'
```

---

## Integration

### Triggers

```yaml
triggers:
  - condition: 'atc_to_purchase_rate < 20%'
    action: 'run_funnel_analysis'
    focus: 'checkout'

  - condition: 'overall_cvr < benchmark * 0.5'
    action: 'run_funnel_analysis'
    focus: 'all'

  - condition: 'lead_to_sale_rate < benchmark * 0.6'
    action: 'run_funnel_analysis'
    focus: 'post_lead'
```

### Dispatches To

- `metric-diagnosis` - para problemas de tráfego
- `tracking-audit` - se dados inconsistentes
- `hook-generator` - se problema é CTR

### Agent Assignment

- **Primary:** @performance-analyst
- **Reports to:** @media-strategist

---

## Usage Examples

```
*analyze-funnel --type direct

*analyze-funnel --campaign campaign_123 --period 30d

*analyze-funnel --focus checkout --compare-baseline
```

### Sample Output

```
📈 ANÁLISE DE FUNIL

╔══════════════════════════════════════════════════════╗
║ TIPO: Direct Traffic | PERÍODO: 7 dias              ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ 50,000 impressões                                    ║
║    ↓ 1.5% CTR                                       ║
║ 750 clicks                                          ║
║    ↓ 12.5% LP CVR ✅                                ║
║ 85 add to cart                                      ║
║    ↓ 52.9% ⚠️ (benchmark: 60%)                      ║
║ 45 checkout                                         ║
║    ↓ 33.3% 🔴 (benchmark: 50%)                      ║
║ 15 purchases                                        ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ MAIOR VAZAMENTO: Checkout → Purchase (-17%)          ║
║ IMPACTO: ~22 conversões perdidas/semana             ║
║ AÇÃO: Otimizar checkout (Alex Hormozi)              ║
╚══════════════════════════════════════════════════════╝
```

---

_Funnel Analysis Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
