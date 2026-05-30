# Campaign Structure Skill

**ID:** `campaign-structure`
**Category:** strategic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Define estrutura otimizada de campanhas, adsets e ads para diferentes objetivos e fases do negócio. Aplica best practices de organização e nomenclatura.

**Activation Command:** `*structure-campaign`
**Announce:** "Ativando Campaign Structure com CBO vs ABO Strategy."

---

## Expert Sources

| Expert        | Framework             | Weight | Focus                      |
| ------------- | --------------------- | ------ | -------------------------- |
| Jeremy Haynes | CBO vs ABO Strategy   | 0.95   | Estrutura de budget        |
| Jeremy Haynes | Campaign Organization | 0.93   | Nomenclatura e organização |
| Brian Moncada | Andromeda Structure   | 0.90   | Testing structure          |

---

## Structure Templates

### 1. Testing Structure (ABO)

```yaml
name: 'Testing Structure'
use_case: 'Validar criativos e audiências'
budget_type: 'ABO (Adset Budget Optimization)'
expert: 'Jeremy Haynes'

structure:
  campaign:
    name: '[TEST] {Product} - {Date}'
    objective: 'Conversions'
    budget: 'Controlado por adset'

  adsets:
    - name: 'INT - {Interest 1}'
      budget: 'R$30-50/dia'
      audience: 'Interest targeting'
      ads: 3-5

    - name: 'INT - {Interest 2}'
      budget: 'R$30-50/dia'
      audience: 'Different interest'
      ads: 3-5

    - name: 'LAL - Purchase 1%'
      budget: 'R$30-50/dia'
      audience: 'Lookalike'
      ads: 3-5

  ads:
    - format: 'Video/Image'
    - variations: 'Different hooks'
    - body: 'Constant (same)'
    - cta: 'Constant (same)'

rules:
  - 'Mesmo budget para todos adsets (fair test)'
  - 'Mesmo set de ads em todos adsets'
  - 'Rodar 3-5 dias antes de decisão'
  - 'Não editar durante teste'
```

### 2. Scaling Structure (CBO)

```yaml
name: 'Scaling Structure'
use_case: 'Escalar winners comprovados'
budget_type: 'CBO (Campaign Budget Optimization)'
expert: 'Jeremy Haynes'

structure:
  campaign:
    name: '[SCALE] {Product} - {Audience Type}'
    objective: 'Conversions'
    budget: 'R$300-1000+/dia'
    optimization: 'CBO'

  adsets:
    - name: 'LAL - Purchase 1%'
      min_budget: 'Não definir'
      audience: 'Best LAL'
      ads: 'Winners only'

    - name: 'LAL - Purchase 3%'
      min_budget: 'Não definir'
      audience: 'Expanded LAL'
      ads: 'Winners only'

    - name: 'BROAD - Open'
      min_budget: 'Não definir'
      audience: 'Age + Gender only'
      ads: 'Winners only'

  ads:
    - 'Apenas winners do teste'
    - '2-3 ads por adset'

rules:
  - 'Só winners validados'
  - 'Deixar Meta otimizar distribuição'
  - 'Aumentar budget max 20%/48h'
```

### 3. Funnel Structure

```yaml
name: 'Full Funnel Structure'
use_case: 'Cold → Warm → Hot progression'
expert: 'Jeremy Haynes'

campaigns:
  cold:
    name: '[COLD] {Product} - Awareness'
    objective: 'Conversions'
    budget: '50% do total'
    audiences:
      - 'LAL Purchase 1-5%'
      - 'Broad'
      - 'Interests'

  warm:
    name: '[WARM] {Product} - Consideration'
    objective: 'Conversions'
    budget: '30% do total'
    audiences:
      - 'Video Viewers 50%+'
      - 'Engaged with Page'
      - 'Website Visitors'

  hot:
    name: '[HOT] {Product} - Remarketing'
    objective: 'Conversions'
    budget: '20% do total'
    audiences:
      - 'Add to Cart'
      - 'Initiate Checkout'
      - 'Past Purchasers'

rule: 'NUNCA misturar cold e warm no mesmo adset'
```

### 4. Launch Structure

```yaml
name: 'Launch Campaign Structure'
use_case: 'Lançamentos com aquecimento'
expert: 'Jeremy Haynes'

phases:
  warmup:
    name: '[LAUNCH-WU] {Product} - Warmup'
    duration: '7-14 dias antes'
    objective: 'Engagement/Video Views'
    content: 'Conteúdo de valor'
    budget: 'R$50-100/dia'

  ppl:
    name: '[LAUNCH-PPL] {Product} - Pre-Launch'
    duration: 'Durante inscrições'
    objective: 'Leads'
    content: 'Captura para live/webinar'
    budget: 'R$100-300/dia'

  cart_open:
    name: '[LAUNCH-OPEN] {Product} - Cart Open'
    duration: 'Período de vendas'
    objective: 'Conversions'
    audiences:
      - 'Email list'
      - 'Webinar attendees'
      - 'Engaged audience'
    budget: 'R$300-1000+/dia'

  cart_close:
    name: '[LAUNCH-CLOSE] {Product} - Urgency'
    duration: 'Últimos 2-3 dias'
    objective: 'Conversions'
    creative: 'Escassez/urgência'
    budget: 'Máximo disponível'
```

---

## Naming Convention

### Standard Format

```
[TYPE] Product - Audience - Date

Examples:
[TEST] Curso Meta Ads - INT Marketing Digital - 0201
[SCALE] Mentoria - LAL Purchase 3% - 0201
[COLD] Ebook - Broad 25-45 - 0201
[WARM] Curso - Video Viewers 50% - 0201
[HOT] Curso - Cart Abandoners - 0201
```

### Type Prefixes

```yaml
prefixes:
  TEST: 'Campanhas de teste'
  SCALE: 'Campanhas de escala'
  COLD: 'Prospecção (público frio)'
  WARM: 'Nurturing (público morno)'
  HOT: 'Remarketing (público quente)'
  LAUNCH: 'Campanhas de lançamento'
  EVERGREEN: 'Campanhas perpétuas'
```

### Adset Naming

```
{Audience Type} - {Audience Detail} - {Placement}

Examples:
LAL - Purchase 1% - All
INT - Empreendedores + Cursos - Feed
BROAD - 25-55 M/F - Auto
RMK - ATC 7d - All
```

### Ad Naming

```
{Creative Type} - {Hook Type} - {Version}

Examples:
VID - Hook Problema - V1
IMG - Hook Resultado - V2
CAR - Hook Tutorial - V1
```

---

## Structure Decision Tree

```
What's the objective?
    │
    ├── Testing new creative/audience
    │   └── Use TESTING STRUCTURE (ABO)
    │
    ├── Scaling proven winners
    │   └── Use SCALING STRUCTURE (CBO)
    │
    ├── Building full funnel
    │   └── Use FUNNEL STRUCTURE (3 campaigns)
    │
    └── Product launch
        └── Use LAUNCH STRUCTURE (4 phases)
```

---

## Output Format

```yaml
campaign_structure:
  product: 'Curso Meta Ads'
  objective: 'Validar e escalar'
  budget_total: 500
  analysis_date: '2026-02-01'

  recommended_structure:
    type: 'testing_then_scale'
    phase: 'testing'

    campaigns:
      - name: '[TEST] Curso Meta Ads - 0201'
        objective: 'Conversions'
        budget_type: 'ABO'
        daily_budget: 150

        adsets:
          - name: 'LAL - Purchase 1%'
            budget: 50
            audience:
              type: 'lookalike'
              source: 'purchasers'
              size: '1%'
            ads:
              - name: 'VID - Hook Problema - V1'
              - name: 'VID - Hook Resultado - V1'
              - name: 'VID - Hook Curiosidade - V1'

          - name: 'INT - Marketing Digital'
            budget: 50
            audience:
              type: 'interest'
              interests: ['Marketing Digital', 'Empreendedorismo']
            ads:
              - name: 'VID - Hook Problema - V1'
              - name: 'VID - Hook Resultado - V1'
              - name: 'VID - Hook Curiosidade - V1'

          - name: 'BROAD - 25-55'
            budget: 50
            audience:
              type: 'broad'
              age: '25-55'
              gender: 'all'
            ads:
              - name: 'VID - Hook Problema - V1'
              - name: 'VID - Hook Resultado - V1'
              - name: 'VID - Hook Curiosidade - V1'

    naming_convention:
      campaign: '[TYPE] Product - Date'
      adset: '{Audience Type} - {Detail}'
      ad: '{Format} - {Hook Type} - {Version}'

    timeline:
      testing: '5 dias'
      evaluation: 'Dia 6'
      scale_decision: 'Baseado em ROAS e CPA'

    success_criteria:
      promote_to_scale:
        - 'ROAS > 2.0'
        - 'CPA < R$35'
        - '50+ conversões'

    next_phase:
      if_successful:
        structure: 'SCALING (CBO)'
        budget: '3-5x testing'
        adsets: 'Winners only'

  expert_attribution:
    structure: 'Jeremy Haynes - CBO vs ABO Strategy'
    testing: 'Jeremy Haynes - Constants vs Variables'
```

---

## Integration

### Triggered By

- `funnel-selection` - após escolher funil
- `unit-economics` - após validar economia
- User command - `*structure-campaign`

### Dispatches To

- Meta Ads API (criação)
- `creative-brief` - para criativos
- `tracking-audit` - para setup de tracking

### Agent Assignment

- **Primary:** @media-strategist
- **Execution:** @performance-analyst

---

## Usage Examples

```
*structure-campaign "Curso Meta Ads" --type testing --budget 150

*structure-campaign --type scale --from-test test_campaign_123

*structure-campaign --type funnel --budget 500
```

---

_Campaign Structure Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
