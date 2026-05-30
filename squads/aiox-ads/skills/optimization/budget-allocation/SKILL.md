# Budget Allocation Skill

**ID:** `budget-allocation`
**Category:** optimization
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Otimiza alocação de budget entre campanhas, adsets e ads para maximizar ROAS geral. Realoca investimento de underperformers para winners.

**Activation Command:** `*allocate-budget`
**Announce:** "Ativando Budget Allocation com Andromeda Budget Distribution."

---

## Expert Sources

| Expert        | Framework                     | Weight | Focus               |
| ------------- | ----------------------------- | ------ | ------------------- |
| Brian Moncada | Andromeda Budget Distribution | 0.90   | Alocação otimizada  |
| Jeremy Haynes | CBO vs ABO Strategy           | 0.92   | Estrutura de budget |
| Alex Hormozi  | Aggressive Allocation         | 0.88   | Escala de winners   |

---

## Allocation Strategies

### 1. Performance-Based Allocation

```yaml
strategy: 'Alocar baseado em ROAS'
principle: 'Mais budget para quem performa melhor'

tiers:
  top_performers:
    criteria: 'ROAS > média × 1.3'
    allocation: '40-50% do budget total'
    action: 'Aumentar até frequência limitar'

  average_performers:
    criteria: 'ROAS entre média × 0.7 e 1.3'
    allocation: '30-40% do budget total'
    action: 'Manter e otimizar'

  underperformers:
    criteria: 'ROAS < média × 0.7'
    allocation: '10-20% do budget total'
    action: 'Reduzir ou pausar'

  testing:
    criteria: 'Novos ads/adsets'
    allocation: '10-15% do budget total'
    action: 'Testar com budget fixo'
```

### 2. Funnel-Based Allocation (Jeremy Haynes)

```yaml
strategy: 'Alocar por temperatura de audiência'

allocation:
  cold:
    percentage: '50%'
    purpose: 'Prospecção, awareness'
    expectations: 'CPA mais alto, LTV feeding'

  warm:
    percentage: '30%'
    purpose: 'Engajados, visitantes, video viewers'
    expectations: 'CPA médio, conversão progressiva'

  hot:
    percentage: '20%'
    purpose: 'Carrinho abandonado, IC, compradores'
    expectations: 'CPA baixo, ROI imediato'

  rule: |
    Nunca misturar cold e warm no mesmo adset.
    Hot sempre em campanha separada (remarketing).
```

### 3. CBO vs ABO Decision

```yaml
cbo_when:
  - '3+ adsets lucrativos no mesmo campaign'
  - 'Fase de escala (winners comprovados)'
  - 'Budget diário > R$200'
  - 'Quer simplicidade de gestão'

abo_when:
  - 'Fase de teste (explorando)'
  - 'Precisa controlar budget por adset'
  - 'Adsets com performances muito diferentes'
  - 'Novos lançamentos'

migration_rule: |
  Começar em ABO, validar winners,
  migrar para CBO quando tiver 3+ winners.
  (Jeremy Haynes - CBO Rules)
```

---

## Reallocation Algorithm

```python
def calculate_reallocation(campaigns, total_budget):
    """
    Realoca budget baseado em performance.
    Brian Moncada - Andromeda Method
    """

    # 1. Calcular scores de performance
    for campaign in campaigns:
        campaign.score = calculate_score(
            roas=campaign.roas,
            cpa=campaign.cpa,
            volume=campaign.conversions
        )

    # 2. Categorizar
    avg_score = mean([c.score for c in campaigns])
    top = [c for c in campaigns if c.score > avg_score * 1.3]
    mid = [c for c in campaigns if avg_score * 0.7 <= c.score <= avg_score * 1.3]
    low = [c for c in campaigns if c.score < avg_score * 0.7]

    # 3. Alocar
    top_budget = total_budget * 0.45
    mid_budget = total_budget * 0.35
    low_budget = total_budget * 0.10
    test_budget = total_budget * 0.10

    # 4. Distribuir dentro de cada tier
    allocations = {}
    for campaign in top:
        share = campaign.score / sum([c.score for c in top])
        allocations[campaign.id] = top_budget * share

    # ... similar para mid e low

    return allocations
```

---

## Budget Protection Rules

```yaml
protection_rules:
  - rule: 'Max 20% increase per 48h'
    reason: 'Evitar resetar learning phase'
    expert: 'Jeremy Haynes'

  - rule: 'Min 10% of original budget'
    reason: 'Manter dados mínimos para avaliação'

  - rule: 'No changes within 24h of last change'
    reason: 'Cooldown para estabilização'

  - rule: 'Test budget fixed for 3-5 days'
    reason: 'Dados suficientes para decisão'

  - rule: 'Alert if total spend > daily cap'
    reason: 'Controle financeiro'
```

---

## Output Format

```yaml
budget_allocation:
  analysis_date: '2026-02-01'
  total_daily_budget: 1000

  current_distribution:
    campaign_A:
      current_budget: 400
      roas: 3.2
      tier: 'top'
      recommendation: 'increase'

    campaign_B:
      current_budget: 350
      roas: 1.8
      tier: 'average'
      recommendation: 'maintain'

    campaign_C:
      current_budget: 250
      roas: 0.9
      tier: 'underperformer'
      recommendation: 'reduce'

  recommended_distribution:
    campaign_A:
      new_budget: 480
      change: '+20%'
      rationale: 'Top performer, ROAS 3.2'

    campaign_B:
      new_budget: 350
      change: '0%'
      rationale: 'Average, manter para otimizar'

    campaign_C:
      new_budget: 120
      change: '-52%'
      rationale: 'ROAS < 1, reduzir exposição'

    test_reserve:
      budget: 50
      purpose: 'Novos testes'

  impact_projection:
    current_blended_roas: 2.1
    projected_roas: 2.5
    improvement: '+19%'

  safety_checks:
    max_increase_rule: '✅ Respeitado (max 20%)'
    min_budget_rule: '✅ Respeitado (min 10%)'
    cooldown_rule: '✅ Nenhuma mudança nas últimas 24h'

  expert_attribution:
    method: 'Brian Moncada - Andromeda Budget Distribution'
```

---

## Integration

### Triggered By

- `kill-scale-rules` - após decisões de scale
- `campaign-monitor` - em otimização rotineira
- User command - `*allocate-budget`

### Dispatches To

- Meta Ads API (execução)
- `metric-diagnosis` - se underperformer precisa análise

### Agent Assignment

- **Primary:** @performance-analyst
- **Approval:** @media-strategist (se mudança > 30%)

---

## Usage Examples

```
*allocate-budget --total 1000

*allocate-budget --optimize-for roas

*allocate-budget --dry-run --show-impact
```

### Sample Output

```
💰 BUDGET ALLOCATION

╔══════════════════════════════════════════════════════╗
║ BUDGET TOTAL: R$1.000/dia                            ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ ATUAL → RECOMENDADO                                  ║
║                                                      ║
║ Campaign A (ROAS 3.2)                                ║
║ R$400 → R$480 (+20%) 🟢 TOP PERFORMER               ║
║                                                      ║
║ Campaign B (ROAS 1.8)                                ║
║ R$350 → R$350 (0%) 🟡 AVERAGE                       ║
║                                                      ║
║ Campaign C (ROAS 0.9)                                ║
║ R$250 → R$120 (-52%) 🔴 UNDERPERFORMER              ║
║                                                      ║
║ Test Reserve                                         ║
║ R$0 → R$50 📊 NOVOS TESTES                          ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ IMPACTO PROJETADO                                    ║
║ ROAS Atual: 2.1 → Projetado: 2.5 (+19%)             ║
╠══════════════════════════════════════════════════════╣
║ EXPERT: Brian Moncada - Andromeda Method            ║
╚══════════════════════════════════════════════════════╝
```

---

_Budget Allocation Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
