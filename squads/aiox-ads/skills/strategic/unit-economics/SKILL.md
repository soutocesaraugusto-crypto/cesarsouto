# Unit Economics Skill

**ID:** `unit-economics`
**Category:** strategic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Cálculo e análise de economia unitária para determinar viabilidade de campanhas, CPA máximo permitido, e oportunidades de escala baseadas em LTV/CAC.

**Activation Command:** `*calculate-economics`
**Announce:** "Ativando Unit Economics com framework Alex Hormozi."

---

## Expert Sources

| Expert       | Framework                 | Weight | Focus                 |
| ------------ | ------------------------- | ------ | --------------------- |
| Alex Hormozi | Unit Economics Foundation | 0.92   | CAC/LTV/Payback       |
| Alex Hormozi | LTV Maximization          | 0.90   | Aumento de LTV        |
| Alex Hormozi | Payback Period            | 0.88   | Velocidade de retorno |

---

## Core Metrics

### Customer Acquisition Cost (CAC)

```yaml
definition: 'Custo total para adquirir um cliente'

calculation:
  formula: 'CAC = Total Ad Spend / Total Customers'
  example:
    ad_spend: 10000
    customers: 100
    cac: 100

components:
  - 'Ad spend'
  - 'Landing page costs (hosting, tools)'
  - 'Sales team costs (if applicable)'
  - 'Onboarding costs'

target: 'CAC < LTV / 3'
```

### Lifetime Value (LTV)

```yaml
definition: 'Valor total que um cliente gera ao longo do tempo'

calculation_simple:
  formula: 'LTV = AOV × Purchase Frequency × Customer Lifespan'
  example:
    aov: 500
    frequency: 2 # Compras por ano
    lifespan: 3 # Anos
    ltv: 3000

calculation_detailed:
  formula: 'LTV = (AOV × GPM × Repeat Rate) / Churn Rate'
  example:
    aov: 500
    gpm: 0.6 # 60% gross margin
    repeat: 2.5
    churn: 0.3
    ltv: 2500

cohort_tracking:
  measure_at: [30, 60, 90, 180, 365] # dias
  note: 'LTV real só conhecemos depois do tempo'
```

### LTV:CAC Ratio

```yaml
definition: 'Proporção entre valor gerado e custo de aquisição'

benchmarks:
  below_1: 'Perdendo dinheiro'
  1_to_2: 'Break-even zone'
  2_to_3: 'Healthy, sustentável'
  3_to_5: 'Bom, espaço para escala'
  above_5: 'Excelente, escalar agressivamente'

target: '> 3'
```

### Payback Period

```yaml
definition: 'Tempo para recuperar o CAC'

calculation:
  formula: 'Payback = CAC / (Monthly Revenue per Customer × GPM)'
  example:
    cac: 300
    monthly_revenue: 100
    gpm: 0.6
    payback: 5 # meses

benchmarks:
  excellent: '< 3 meses'
  good: '3-6 meses'
  acceptable: '6-12 meses'
  risky: '> 12 meses'

target: '< 6 meses'
```

---

## Break-Even Analysis

### Maximum CPA Calculation

```yaml
formula: 'Max CPA = (Product Price × Gross Margin) × Acceptable Ratio'

example:
  product_price: 997
  gross_margin: 0.7 # 70% margem
  acceptable_ratio: 0.5 # 50% do lucro bruto

  calculation:
    gross_profit: 997 × 0.7 = 697.9
    max_cpa: 697.9 × 0.5 = 348.95

rule: |
  Se CPA > Max CPA, campanha não é sustentável.
  Opções: aumentar preço, reduzir CPA, ou aumentar LTV via upsells.
```

### Break-Even ROAS

```yaml
formula: 'Break-Even ROAS = 1 / Gross Margin'

examples:
  margin_80: 'BE ROAS = 1.25'
  margin_70: 'BE ROAS = 1.43'
  margin_60: 'BE ROAS = 1.67'
  margin_50: 'BE ROAS = 2.00'
  margin_40: 'BE ROAS = 2.50'

target: 'Actual ROAS > BE ROAS × 1.5'
```

---

## AOV Optimization

### Order Bump Strategy

```yaml
definition: 'Oferta adicional no checkout'

best_practices:
  price: '20-40% do produto principal'
  relevance: 'Complementar ao produto principal'
  conversion_rate: '20-40%'

example:
  main_product: 497
  order_bump: 97 # 20% do principal
  bump_rate: 0.30
  new_aov: 497 + (97 × 0.30) = 526.1
  aov_increase: '+5.9%'
```

### Upsell Strategy

```yaml
definition: 'Oferta após a compra'

best_practices:
  upsell_1:
    timing: 'Imediatamente após compra'
    price: '1-2x do produto principal'
    conversion: '20-35%'

  upsell_2:
    timing: 'Após upsell 1'
    price: '0.5-1x do principal'
    conversion: '15-25%'

example:
  main: 497
  upsell_1: 697
  upsell_1_rate: 0.25
  upsell_2: 297
  upsell_2_rate: 0.15

  new_aov: 497 + (697×0.25) + (297×0.15) = 715.80
  aov_increase: '+44%'
```

---

## Scaling Decision Framework

### Scale Aggressively (LTV:CAC > 4)

```yaml
actions:
  - 'Aumentar budget 30-50%'
  - 'Expandir para novas audiências'
  - 'Testar novos canais'
  - 'Investir em criativos'

risk: 'Baixo'
expert: 'Alex Hormozi'
```

### Scale Moderately (LTV:CAC 2-4)

```yaml
actions:
  - 'Aumentar budget 15-20%'
  - 'Otimizar funil para aumentar LTV'
  - 'Melhorar criativos para reduzir CAC'

risk: 'Médio'
```

### Optimize First (LTV:CAC 1-2)

```yaml
actions:
  - 'Não escalar ainda'
  - 'Adicionar upsells/order bumps'
  - 'Testar preços mais altos'
  - 'Melhorar retention'

risk: 'Alto se escalar'
```

### Fix or Pivot (LTV:CAC < 1)

```yaml
actions:
  - 'Pausar aquisição paga'
  - 'Revisar produto/oferta'
  - 'Considerar pivô'

risk: 'Muito alto'
```

---

## Output Format

```yaml
unit_economics:
  product: 'Mentoria Meta Ads'
  analysis_date: '2026-02-01'

  inputs:
    product_price: 3000
    gross_margin: 0.80
    ad_spend_monthly: 15000
    customers_monthly: 25
    repeat_purchase_rate: 0.15
    avg_customer_lifespan: 18 # meses
    order_bump_price: 497
    order_bump_rate: 0.30

  calculated_metrics:
    cac: 600
    ltv_simple: 3000
    ltv_with_repeats: 3450
    ltv_with_upsells: 3599
    ltv_cac_ratio: 6.0
    payback_period_months: 0.25 # Recebimento imediato

    max_cpa: 1200 # 50% da margem bruta
    break_even_roas: 1.25
    current_roas: 5.0

  health_status:
    ltv_cac: '🟢 EXCELENTE (>5)'
    payback: '🟢 IMEDIATO'
    roas: '🟢 5x acima do break-even'

  recommendations:
    - action: 'ESCALAR AGRESSIVAMENTE'
      rationale: 'LTV:CAC de 6.0 indica margem excelente'
      budget_increase: '+50%'
      expert: 'Alex Hormozi'

    - action: 'Adicionar upsell de R$997'
      rationale: 'Aumentar LTV em ~15%'
      expected_impact: 'LTV → R$4100'

    - action: 'Testar CPA até R$900'
      rationale: 'Ainda dentro de LTV:CAC > 4'
      note: 'Permite audiências mais caras'

  projections:
    if_scale_50_percent:
      new_budget: 22500
      expected_customers: 37
      expected_revenue: 111000
      expected_profit: 66600

  expert_attribution:
    framework: 'Alex Hormozi - Unit Economics'
```

---

## Integration

### Triggered By

- Início de nova campanha
- `funnel-selection` - para validar funil
- User command - `*calculate-economics`

### Dispatches To

- `kill-scale-rules` - com max CPA
- `funnel-selection` - se unidades não fecham

### Agent Assignment

- **Primary:** @media-strategist
- **Input:** @performance-analyst

---

## Usage Examples

```
*calculate-economics "Mentoria Meta Ads" --price 3000 --margin 80

*calculate-economics --analyze-current-campaigns

*calculate-economics --ltv-projection 12m
```

---

_Unit Economics Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
