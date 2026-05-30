# Forester Scaling System Skill

**ID:** `forester-scaling-system`
**Category:** strategic
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Implementa a estrutura Forester de 6 campanhas paralelas para escala agressiva. Define regras de promoção entre campanhas (Testing → Winner → Scale), alocação de budget, sistema de pre-sell com conteúdo de 72h, e monitoramento por tipo de campanha.

**Activation Command:** `*forester-scale`
**Announce:** "Ativando Forester 6-Campaign Scaling System com frameworks Jeremy Haynes e Alex Hormozi."

---

## Expert Sources

| Expert        | Framework                           | Weight | Focus                      |
| ------------- | ----------------------------------- | ------ | -------------------------- |
| Jeremy Haynes | Forester Strategy Upgraded (6-Camp) | 0.95   | Estrutura de 6 campanhas   |
| Jeremy Haynes | Scaling Operations Protocol         | 0.90   | Operações de escala        |
| Alex Hormozi  | Hydra Strategy                      | 0.88   | Escala multi-canal         |

---

## Forester Framework

### 6-Campaign Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    FORESTER 6-CAMPAIGN                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  [1] TESTING ──promote──> [2] WINNER ──promote──> [3] SCALE │
│      (ABO $50-200/d)        (ABO $200-1K/d)       (CBO $1K+)│
│                                                              │
│  [4] RETARGETING        [5] LOOKALIKE          [6] BROAD/AI │
│      (DPA $30-100/d)       (LAL $200-500/d)      (A+ $500+) │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Budget Allocation by Total Spend

```
┌──────────────────────────────────────────────────────────────┐
│               BUDGET ALLOCATION TABLE                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  R$10K+/dia (Full Forester - 6 campaigns):                  │
│  ┌────────────┬────────┬────────────────────────┐           │
│  │ Campaign   │ Share  │ Daily Budget            │           │
│  ├────────────┼────────┼────────────────────────┤           │
│  │ Testing    │  15%   │ R$1.500                 │           │
│  │ Winner     │  20%   │ R$2.000                 │           │
│  │ Scale      │  30%   │ R$3.000                 │           │
│  │ Retargeting│  10%   │ R$1.000                 │           │
│  │ Lookalike  │  15%   │ R$1.500                 │           │
│  │ Broad/AI   │  10%   │ R$1.000                 │           │
│  └────────────┴────────┴────────────────────────┘           │
│                                                              │
│  R$3-10K/dia (4 campaigns):                                 │
│  Testing 20% | Winner 30% | Retargeting 15% | Lookalike 35% │
│                                                              │
│  <R$3K/dia (3 campaigns):                                   │
│  Testing 30% | Winner 40% | Retargeting 30%                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Promotion Flow

```
                    PROMOTION RULES
                    ===============

[1] TESTING                    [2] WINNER                    [3] SCALE
┌─────────────┐   PROMOTE     ┌─────────────┐   PROMOTE     ┌─────────────┐
│ ABO         │──────────────>│ ABO         │──────────────>│ CBO         │
│ $50-200/dia │   IF:         │ $200-1K/dia │   IF:         │ $1K+/dia    │
│ Broad test  │   ROAS>2x 3d │ Validated   │   ROAS>3x 5d │ Top perform │
│ New creative│               │ Winners     │               │ Max budget  │
└─────────────┘               └──────┬──────┘               └─────────────┘
                                     │ DEMOTE
                                     │ IF: CPA +30%
                                     v
                              Never kill directly
                              from Scale — always
                              demote to Winner first
```

### Pre-Sell Content System (72h)

```
┌──────────────────────────────────────────────────────────────┐
│              PRE-SELL CONTENT SYSTEM (72h)                    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Before sales contact, nurture with 72h of content:         │
│                                                              │
│  Hour 0-24:   AWARENESS content (value, education)          │
│  Hour 24-48:  TRUST content (proof, testimonials, cases)    │
│  Hour 48-72:  INTENT content (offers, scarcity, CTA)        │
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Value    │───>│ Proof    │───>│ Offer    │              │
│  │ Content  │    │ Content  │    │ Content  │              │
│  │ (educate)│    │ (trust)  │    │ (convert)│              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                                                              │
│  Retargeting campaign [4] handles delivery automatically    │
│  Budget: $10-30/day | 30-100 pieces | $0.03-0.07/impression │
└──────────────────────────────────────────────────────────────┘
```

### SE/ENTAO Rules

```yaml
rules:
  - id: 'FS-001'
    se: 'Ad em Testing tem ROAS > 2x por 3 dias consecutivos'
    entao: 'Promover para Winner campaign'
    expert: 'Jeremy Haynes'

  - id: 'FS-002'
    se: 'Ad em Winner tem ROAS > 3x por 5 dias consecutivos'
    entao: 'Promover para Scale campaign'
    expert: 'Jeremy Haynes'

  - id: 'FS-003'
    se: 'Total budget > R$10k/dia'
    entao: 'Ativar todas 6 campanhas (Full Forester)'
    expert: 'Jeremy Haynes'

  - id: 'FS-004'
    se: 'Budget < R$3k/dia'
    entao: 'Usar apenas Testing + Winner + Retargeting (3 campanhas)'
    expert: 'Jeremy Haynes'

  - id: 'FS-005'
    se: 'Budget R$3-10k/dia'
    entao: 'Adicionar Lookalike (4 campanhas)'
    expert: 'Jeremy Haynes'

  - id: 'FS-006'
    se: 'Ad em Scale tem CPA subindo > 30%'
    entao: 'Rebaixar para Winner (NUNCA matar direto do Scale)'
    expert: 'Jeremy Haynes'

  - id: 'FS-007'
    se: 'Retargeting frequency > 5'
    entao: 'Expandir audience pool ou reduzir budget retargeting'
    expert: 'Alex Hormozi'
```

---

## Campaign Detail Specs

### [1] Testing Campaign

```yaml
testing:
  name: '[TEST] {Product} - Forester Testing'
  budget_type: 'ABO'
  daily_budget: 'R$50-200/dia'
  objective: 'Conversions'

  purpose: 'Proving ground — validar criativos e ângulos novos'

  audience:
    type: 'Broad'
    age: '25-55'
    targeting: 'Minimal interests or broad'

  ads:
    per_adset: '3-5 new creatives'
    rotation: 'Semanal — novo batch toda semana'

  evaluation:
    window: '48-72h'
    promote_if: 'ROAS > 2x por 3 dias'
    kill_if: 'CPA > 2x target após 48h'
```

### [2] Winner Campaign

```yaml
winner:
  name: '[WINNER] {Product} - Forester Validated'
  budget_type: 'ABO'
  daily_budget: 'R$200-1.000/dia'
  objective: 'Conversions'

  purpose: 'Bridge — validar winners antes do scale máximo'

  audience:
    type: 'Proven audiences from Testing'
    expansion: 'LAL 1-3%'

  ads:
    source: 'Promoted from Testing'
    min_active: 5

  evaluation:
    window: '5 dias'
    promote_if: 'ROAS > 3x por 5 dias'
    demote_if: 'CPA sobe > 20% por 3 dias'
```

### [3] Scale Campaign

```yaml
scale:
  name: '[SCALE] {Product} - Forester Scale'
  budget_type: 'CBO'
  daily_budget: 'R$1.000+/dia'
  objective: 'Conversions'

  purpose: 'Main revenue driver — top performers em budget máximo'

  audience:
    type: 'Best from Winner + Broad'
    optimization: 'Meta CBO distribui automaticamente'

  ads:
    source: 'Promoted from Winner'
    min_active: 3

  rules:
    - 'Nunca matar ad direto do Scale — rebaixar para Winner'
    - 'Aumentar budget máximo 20% a cada 48h'
    - 'Se CPA sobe > 30%, rebaixar para Winner'
```

### [4] Retargeting Campaign

```yaml
retargeting:
  name: '[RETARGET] {Product} - Forester Retargeting'
  budget_type: 'ABO'
  daily_budget: 'R$30-100/dia'
  objective: 'Conversions / Catalog Sales'

  purpose: 'Recapturar engajados e abandonos'

  audience:
    type: 'Custom audiences'
    segments:
      - 'Website visitors 7-30d'
      - 'Engaged with page 14d'
      - 'Video viewers 50%+'
      - 'Cart abandoners'
      - 'DPA (Dynamic Product Ads)'

  content:
    pre_sell: '72h content bombardment'
    formats: 'Testimonials, cases, urgency'

  rules:
    - 'Frequency cap: máximo 5'
    - 'Se frequency > 5, expandir pool ou reduzir budget'
```

### [5] Lookalike Campaign

```yaml
lookalike:
  name: '[LAL] {Product} - Forester Expansion'
  budget_type: 'CBO'
  daily_budget: 'R$200-500/dia'
  objective: 'Conversions'

  purpose: 'Expandir alcance com audiências similares aos compradores'

  audience:
    tiers:
      - 'LAL Purchase 1% (mais preciso)'
      - 'LAL Purchase 3% (expansão)'
      - 'LAL Purchase 5% (máxima expansão)'
    progression: 'Começar 1% → expandir conforme performance'

  ads:
    source: 'Winners validados do Scale'

  rules:
    - 'Ativar apenas com budget > R$3k/dia'
    - 'Se LAL 1% satura, expandir para 3%'
```

### [6] Broad/AI Campaign

```yaml
broad_ai:
  name: '[BROAD] {Product} - Forester AI'
  budget_type: 'CBO / Advantage+'
  daily_budget: 'R$500+/dia'
  objective: 'Conversions'

  purpose: 'Deixar algoritmo Meta encontrar público ideal'

  audience:
    type: 'Advantage+ / Broad (age+gender only)'
    targeting: 'Mínimo possível — confiança no algoritmo'

  ads:
    source: 'Top performers de todas campanhas'
    min_active: 5

  rules:
    - 'Ativar apenas com budget > R$10k/dia'
    - 'Precisa de pixel maduro (1000+ conversões)'
    - 'Advantage+ Shopping para e-commerce'
```

---

## Forester Process

### Step 1: Audit Current Structure

```yaml
audit:
  check:
    - current_campaigns: 'Quantas campanhas ativas?'
    - budget_total: 'Budget total diário?'
    - campaign_types: 'Quais tipos existem?'
    - promotion_rules: 'Existem regras de promoção?'

  gap_analysis:
    - 'Quantas das 6 campanhas faltam?'
    - 'Budget justifica quantas campanhas?'
    - 'Criativos suficientes para alimentar todas?'
```

### Step 2: Design 6-Campaign Architecture

```yaml
design:
  based_on_budget:
    under_3k: 'Ativar 3: Testing + Winner + Retargeting'
    3k_to_10k: 'Ativar 4: + Lookalike'
    over_10k: 'Ativar 6: Full Forester'

  naming: '[TYPE] {Product} - Forester {Campaign}'

  structure:
    - campaign_type: 'Testing'
      budget_share: '15%'
      budget_type: 'ABO'
    - campaign_type: 'Winner'
      budget_share: '20%'
      budget_type: 'ABO'
    - campaign_type: 'Scale'
      budget_share: '30%'
      budget_type: 'CBO'
    - campaign_type: 'Retargeting'
      budget_share: '10%'
      budget_type: 'ABO'
    - campaign_type: 'Lookalike'
      budget_share: '15%'
      budget_type: 'CBO'
    - campaign_type: 'Broad/AI'
      budget_share: '10%'
      budget_type: 'CBO/A+'
```

### Step 3: Set Promotion Rules

```yaml
promotion_rules:
  testing_to_winner:
    condition: 'ROAS > 2x por 3 dias consecutivos'
    action: 'Mover ad para Winner campaign'
    budget_adjustment: 'Aumentar para R$200-1K/dia range'

  winner_to_scale:
    condition: 'ROAS > 3x por 5 dias consecutivos'
    action: 'Mover ad para Scale campaign (CBO)'
    budget_adjustment: 'CBO distribui automaticamente'

  scale_demotion:
    condition: 'CPA sobe > 30%'
    action: 'Rebaixar para Winner — NUNCA matar direto'
    cooldown: '5 dias em Winner antes de reavaliar'
```

### Step 4: Allocate Budget

```yaml
allocation:
  method: 'Percentage-based by campaign type'
  rebalance_frequency: 'Semanal'

  rules:
    - 'Scale sempre recebe maior share (30%)'
    - 'Testing nunca abaixo de 15% (pipeline)'
    - 'Se nenhum winner, redirecionar Scale budget para Testing'
    - 'Retargeting mínimo 10% (sempre ativo)'
```

### Step 5: Monitor + Promote/Demote

```yaml
monitoring:
  frequency: 'Diário'

  daily_check:
    - 'ROAS por campanha-tipo'
    - 'CPA por campanha-tipo'
    - 'Promotion candidates (Testing → Winner)'
    - 'Demotion candidates (Scale → Winner)'
    - 'Creative health per campaign'

  weekly_review:
    - 'Budget reallocation necessária?'
    - 'Novas campanhas a ativar/desativar?'
    - 'Pipeline de criativos suficiente?'
```

---

## Output Format

```yaml
forester_plan:
  campaign_id: 'account_123'
  analysis_date: '2026-02-15'
  strategist: '@ralph-burns'

  current_state:
    total_budget: 'R$8.000/dia'
    active_campaigns: 3
    structure: 'Básica (Testing + Scaling + Retargeting)'
    gap: 'Faltam Winner, Lookalike, Broad/AI'

  recommended_structure:
    tier: '4 campaigns (R$3-10K range)'
    campaigns:
      - type: 'Testing'
        name: '[TEST] Curso Ads - Forester Testing'
        budget: 'R$1.600/dia (20%)'
        budget_type: 'ABO'
        status: 'EXISTING — reestruturar'

      - type: 'Winner'
        name: '[WINNER] Curso Ads - Forester Validated'
        budget: 'R$2.400/dia (30%)'
        budget_type: 'ABO'
        status: 'NEW — criar'

      - type: 'Retargeting'
        name: '[RETARGET] Curso Ads - Forester Retargeting'
        budget: 'R$1.200/dia (15%)'
        budget_type: 'ABO'
        status: 'EXISTING — ajustar budget'

      - type: 'Lookalike'
        name: '[LAL] Curso Ads - Forester Expansion'
        budget: 'R$2.800/dia (35%)'
        budget_type: 'CBO'
        status: 'NEW — criar'

  promotion_rules:
    testing_to_winner: 'ROAS > 2x por 3 dias'
    winner_to_scale: 'ROAS > 3x por 5 dias (ativar Scale quando budget > R$10K)'
    demotion: 'CPA +30% → rebaixar para Winner'

  scale_path:
    current: 'R$8K/dia — 4 campaigns'
    next_tier: 'R$10K/dia — ativar Scale + Broad/AI (6 campaigns)'
    timeline: 'Quando Winner campaign produzir 3+ ads com ROAS > 3x'

  next_actions:
    - '1. Criar Winner campaign com ads promovidos do Testing'
    - '2. Criar Lookalike campaign com LAL Purchase 1-3%'
    - '3. Ajustar budget allocation conforme tabela'
    - '4. Configurar regras de promoção no monitoring'
    - '5. Dispatch creative-bombardment para garantir pipeline'

  expert_attribution:
    structure: 'Jeremy Haynes - Forester Strategy Upgraded'
    scaling_ops: 'Jeremy Haynes - Scaling Operations Protocol'
    hydra: 'Alex Hormozi - Hydra Strategy (para > R$10K/dia)'
```

---

## Integration

### Triggered By

- `scale-readiness-check` - quando aprovado (score > 85)
- User command - `*forester-scale`

### Dispatches To

- `budget-allocation` - distribuir budget entre as 6 campanhas
- `creative-bombardment` - garantir pipeline de criativos suficiente
- `campaign-monitor` - monitorar todas 6 campanhas em paralelo

### Agent Assignment

- **Primary:** @ralph-burns
- **Approval:** @ad-midas

---

## Usage Examples

### Command Line

```
*forester-scale account_123

*forester-scale --budget 10000 --tier full

*forester-scale --audit-only

*forester-scale --promote testing_ad_456 winner
```

### Sample Output

```
FORESTER 6-CAMPAIGN SYSTEM - Account_123

+======================================================+
| BUDGET: R$8.000/dia | TIER: 4 campaigns              |
| STATUS: Reestruturação necessária                      |
+======================================================+
|                                                        |
| ESTRUTURA ATUAL:                                       |
| [1] Testing  R$2.400  (existente)                     |
| [4] Retarget R$800    (existente)                     |
| [?] Scaling  R$4.800  (sem estrutura Forester)        |
|                                                        |
+======================================================+
| ESTRUTURA RECOMENDADA (4 campaigns):                  |
|                                                        |
| [1] Testing    R$1.600 (20%) ABO  -- reestruturar     |
| [2] Winner     R$2.400 (30%) ABO  -- CRIAR            |
| [4] Retarget   R$1.200 (15%) ABO  -- ajustar          |
| [5] Lookalike  R$2.800 (35%) CBO  -- CRIAR            |
|                                                        |
+======================================================+
| PROMOTION RULES:                                       |
| Testing → Winner: ROAS > 2x por 3 dias               |
| Winner → Scale: ROAS > 3x por 5 dias (quando >R$10K) |
| Scale → Winner: CPA +30% (nunca matar direto)         |
+======================================================+
| SCALE PATH: R$8K → R$10K → Full Forester (6 camps)   |
| EXPERT: Jeremy Haynes - Forester Strategy Upgraded     |
+======================================================+
```

---

_Forester Scaling System Skill v1.0.0_
_Ads Squad - AIOS Synkra_
