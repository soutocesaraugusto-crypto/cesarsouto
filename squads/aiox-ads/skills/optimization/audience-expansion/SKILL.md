# Audience Expansion Skill

**ID:** `audience-expansion`
**Category:** optimization
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Estratégias para expandir audiências quando as atuais saturam ou quando há oportunidade de escala. Inclui lookalikes, interesses, broad e expansões geográficas.

**Activation Command:** `*expand-audience`
**Announce:** "Ativando Audience Expansion com Lookalike Funnel e Broad Testing."

---

## Expert Sources

| Expert        | Framework               | Weight | Focus              |
| ------------- | ----------------------- | ------ | ------------------ |
| Jeremy Haynes | Pixel Funnel Lookalike  | 0.95   | Hierarquia LAL     |
| Brian Moncada | Andromeda Broad Testing | 0.90   | Testes broad       |
| Jeremy Haynes | Audience Saturation     | 0.92   | Detecção saturação |

---

## Expansion Strategies

### 1. Lookalike Expansion Ladder

```yaml
strategy: 'Expandir LAL progressivamente'
expert: 'Jeremy Haynes'

ladder:
  step_1:
    source: 'Purchasers'
    size: '1%'
    when: 'Sempre começar aqui'
    expected_cpa: 'Mais baixo'

  step_2:
    source: 'Purchasers'
    size: '3%'
    when: '1% saturando (frequency > 3)'
    expected_cpa: '5-15% maior'

  step_3:
    source: 'Purchasers'
    size: '5%'
    when: '3% performando bem'
    expected_cpa: '10-20% maior'

  step_4:
    source: 'Initiate Checkout'
    size: '1%'
    when: 'Purchasers LAL saturando'
    expected_cpa: 'Similar ao 3% purchasers'

  step_5:
    source: 'Add to Cart'
    size: '1%'
    when: 'Expandir funil'
    expected_cpa: 'Mais variável'

  step_6:
    source: 'View Content'
    size: '1-3%'
    when: 'Alto volume necessário'
    expected_cpa: 'Mais alto, mas escala'

rule: 'Cada evento do pixel alimenta o próximo nível de LAL'
```

### 2. Interest Stacking

```yaml
strategy: 'Combinar interesses para precisão'
expert: 'Brian Moncada'

approach:
  narrow:
    method: 'Interesse A AND Interesse B'
    use_when: 'Nicho específico'
    example: 'Empreendedores AND Cursos Online'

  flex:
    method: 'Interesse A OR Interesse B'
    use_when: 'Testar volume'
    example: 'Meta Ads OR Google Ads'

  exclude:
    method: 'Interesse A EXCEPT Interesse B'
    use_when: 'Refinar qualidade'
    example: 'Marketing Digital EXCEPT Afiliados'

testing_sequence:
  - '1. Testar interesses individuais'
  - '2. Combinar winners em stack'
  - '3. Comparar stack vs broad'
  - '4. Escalar winner'
```

### 3. Broad Targeting

```yaml
strategy: 'Deixar algoritmo decidir'
expert: 'Brian Moncada - Andromeda'

when_to_use:
  - 'LAL 5% performando bem'
  - 'CPM em LAL muito alto'
  - 'Pixel com 500+ conversões'
  - 'Criativo forte (CTR > 2%)'

setup:
  targeting: 'Apenas idade + gênero + localização'
  no_interests: true
  no_lookalikes: true
  advantage_plus: true

expected_behavior:
  - 'CPA inicialmente mais alto'
  - 'Estabiliza em 5-7 dias'
  - 'CPM geralmente mais baixo'
  - 'Escala ilimitada'

monitoring:
  success_criteria: 'CPA < 130% do LAL 1%'
  kill_criteria: 'CPA > 200% após 7 dias'
```

### 4. Geographic Expansion

```yaml
strategy: 'Expandir para novas regiões'

brazil_tiers:
  tier_1:
    regions: ['SP', 'RJ', 'MG']
    population: 'Alto'
    purchasing_power: 'Alto'
    start_here: true

  tier_2:
    regions: ['PR', 'RS', 'SC', 'BA']
    population: 'Médio-alto'
    purchasing_power: 'Médio'
    expand_when: 'Tier 1 performando'

  tier_3:
    regions: ['Restante']
    population: 'Variável'
    purchasing_power: 'Menor'
    expand_when: 'Escala agressiva'

latam_expansion:
  priority_1: ['México', 'Colômbia']
  priority_2: ['Argentina', 'Chile', 'Peru']
  note: 'Requer adaptação de copy/criativo'
```

---

## Saturation Detection

```yaml
saturation_indicators:
  primary:
    - metric: 'Frequency > 3'
      severity: 'High'
      action: 'Expandir imediatamente'

    - metric: 'CPM up 30%+ em 7d'
      severity: 'High'
      action: 'Testar nova audiência'

    - metric: 'CTR down 25%+ em 7d'
      severity: 'Medium'
      action: 'Refresh criativo + audiência'

  secondary:
    - metric: 'Audience overlap > 50%'
      severity: 'Medium'
      action: 'Consolidar audiências'

    - metric: 'Reach stagnating'
      severity: 'Low'
      action: 'Expandir LAL %'

detection_algorithm:
  saturation_score: |
    score = 0
    if frequency > 3: score += 30
    if cpm_change_7d > 30%: score += 25
    if ctr_change_7d < -25%: score += 25
    if audience_overlap > 50%: score += 20

    if score >= 50: "SATURATED - expand now"
    if score >= 30: "SATURATING - prepare expansion"
    if score < 30: "HEALTHY - monitor"
```

---

## Expansion Decision Tree

```
Is ROAS > target?
    │
    ├── YES → Is Frequency > 3?
    │         │
    │         ├── YES → EXPAND (LAL % or new source)
    │         │
    │         └── NO → SCALE CURRENT (budget +20%)
    │
    └── NO → Is CTR > benchmark?
              │
              ├── YES → Problem is post-click (landing/offer)
              │
              └── NO → Problem is creative/audience
                       Try different interest or refresh creative
```

---

## Output Format

```yaml
audience_expansion:
  analysis_date: '2026-02-01'
  current_audience: 'LAL 1% Purchasers - SP/RJ'

  saturation_analysis:
    frequency: 3.5
    cpm_trend: '+28%'
    ctr_trend: '-18%'
    saturation_score: 73
    status: 'SATURATED'

  expansion_options:
    - option: 1
      type: 'lookalike_expansion'
      from: 'LAL 1%'
      to: 'LAL 3%'
      expected_impact:
        cpa_change: '+12%'
        volume_change: '+150%'
      priority: 1
      expert: 'Jeremy Haynes'

    - option: 2
      type: 'source_change'
      from: 'Purchasers'
      to: 'Initiate Checkout'
      size: '1%'
      expected_impact:
        cpa_change: '+8%'
        volume_change: '+80%'
      priority: 2

    - option: 3
      type: 'broad_test'
      setup: 'Age 25-55, Brasil, Open targeting'
      expected_impact:
        cpa_change: '+20-30% initially'
        volume_change: 'Unlimited'
      priority: 3
      expert: 'Brian Moncada'

    - option: 4
      type: 'geographic'
      add_regions: ['PR', 'RS', 'SC', 'BA']
      expected_impact:
        cpa_change: '+5%'
        volume_change: '+40%'
      priority: 4

  recommendation:
    selected: 'option_1'
    action: 'Expandir LAL de 1% para 3%'
    reasoning: 'Audiência saturada, LAL 3% é próximo passo natural'
    expert: 'Jeremy Haynes - Lookalike Ladder'

  implementation:
    steps:
      - 'Duplicar adset atual'
      - 'Alterar LAL para 3%'
      - 'Manter budget igual por 3 dias'
      - 'Comparar CPA e ROAS'
      - 'Se positivo, aumentar budget'
```

---

## Integration

### Triggered By

- `campaign-monitor` - quando frequency > 3
- `kill-scale-rules` - quando escala limitada
- User command - `*expand-audience`

### Dispatches To

- Meta Ads API (execução)
- `budget-allocation` - para novo budget

### Agent Assignment

- **Primary:** @performance-analyst
- **Approval:** @media-strategist

---

## Usage Examples

```
*expand-audience --adset adset_123

*expand-audience --analyze-saturation

*expand-audience --suggest-broad
```

---

_Audience Expansion Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
