# Creative Bombardment Skill

**ID:** `creative-bombardment`
**Category:** optimization
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Sistema de bombardeio multi-criativo: lanca 10-20 criativos simultaneamente, mata underperformers em 48h, escala winners com variacoes. Implementa o Creative Lab Pipeline e a matriz de combinacao (hooks x bodies x CTAs) para gerar volume exponencial de variacoes testáveis.

**Activation Command:** `*bombardment`
**Announce:** "Ativando Creative Bombardment com Creative Lab Protocol e Constants vs Variables."

---

## Expert Sources

| Expert        | Framework                       | Weight | Focus                        |
| ------------- | ------------------------------- | ------ | ---------------------------- |
| Jeremy Haynes | Hammer Them Bombardment System  | 0.95   | Bombardeio multi-creative    |
| Jeremy Haynes | Creative Lab Protocol           | 0.90   | Fábrica de criativos         |
| Brandon Carter| Constants vs Variables          | 0.88   | Teste científico de criativos|

---

## Bombardment Framework

### Creative Lab Pipeline

```
BRIEF → PRODUCE (batch 10-20) → TEST (48h each) → ANALYZE
    |                                                  |
    v                                                  v
  Winners (top 20%) ──── VARIATE (5 versions each) ── SCALE
    |
    v
  Losers (bottom 80%) ── KILL immediately
```

### Combination Matrix

```
┌──────────────────────────────────────────────────────────────┐
│                    COMBINATION MATRIX                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  HOOKS (N)  x  BODIES (M)  x  CTAs (P)  =  TOTAL VARIATIONS│
│                                                              │
│  Example:                                                    │
│  5 hooks x 3 bodies x 2 CTAs = 30 variations from 10 assets │
│                                                              │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐                   │
│  │ Hook A  │   │ Body 1  │   │ CTA X   │                   │
│  │ Hook B  │ x │ Body 2  │ x │ CTA Y   │ = 30 combos      │
│  │ Hook C  │   │ Body 3  │   └─────────┘                   │
│  │ Hook D  │   └─────────┘                                  │
│  │ Hook E  │                                                 │
│  └─────────┘                                                 │
│                                                              │
│  RULE: Change ONE element at a time between variations       │
│  (Constants vs Variables - Brandon Carter)                   │
└──────────────────────────────────────────────────────────────┘
```

### Retargeting Bombardment (72h Protocol)

```
┌──────────────────────────────────────────────────────────────┐
│              RETARGETING BOMBARDMENT - 72h                    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  CONTENT VOLUME: 30-100 peças de conteúdo                   │
│  BUDGET: $10-$30/dia                                        │
│  CPM TARGET: $0.03-$0.07 por impressão                      │
│                                                              │
│  Hour 0 ────────── Hour 24 ────────── Hour 48 ── Hour 72   │
│    |                  |                  |           |       │
│  Launch             Analyze            Kill/Scale  Report   │
│  30-100 ads         Performance        Bottom 80%  Winners  │
│  $10-30/day         CTR+Engage         Top 20%     Scale    │
│                                                              │
│  PURPOSE: Saturate retargeting audience with value           │
│  RESULT: Pre-sell before sales contact                       │
└──────────────────────────────────────────────────────────────┘
```

### SE/ENTAO Rules

```yaml
rules:
  - id: 'CB-001'
    se: 'Campanha em escala (>R$5k/dia)'
    entao: 'Mínimo 15 criativos ativos'
    expert: 'Jeremy Haynes'

  - id: 'CB-002'
    se: '<5 criativos ativos em campanha de escala'
    entao: 'Trigger bombardeio imediato (batch 10-20)'
    expert: 'Jeremy Haynes'

  - id: 'CB-003'
    se: 'Creative win rate < 20%'
    entao: 'Revisar briefing e ângulos (não aumentar volume)'
    expert: 'Brandon Carter'

  - id: 'CB-004'
    se: 'Winner identificado (top 20%)'
    entao: 'Gerar 5 variações imediatas (same body, different hooks)'
    expert: 'Jeremy Haynes'

  - id: 'CB-005'
    se: 'Todos criativos CTR < 1% após 48h'
    entao: 'Problema no briefing, não no volume — revisar ângulos'
    expert: 'Brandon Carter'

  - id: 'CB-006'
    se: 'Retargeting ativo'
    entao: 'Bombardear com 30-100 peças de conteúdo em 72h'
    expert: 'Jeremy Haynes'
```

---

## Bombardment Process

### Step 1: Audit Current Creatives

```yaml
audit:
  check:
    - total_active_creatives: 'Quantos ativos?'
    - win_rate: 'Top 20% vs bottom 80%'
    - fatigue_signals: 'CTR declining? Frequency > 3?'
    - last_refresh: 'Quando último batch novo?'

  thresholds:
    critical: 'Menos de 3 criativos ativos'
    warning: 'Menos de 10 criativos ativos em escala'
    healthy: '15+ criativos ativos com win rate > 20%'
```

### Step 2: Generate Combination Matrix

```yaml
matrix_generation:
  inputs:
    hooks: 'Listar N hooks (mínimo 5)'
    bodies: 'Listar M bodies/scripts (mínimo 3)'
    ctas: 'Listar P CTAs (mínimo 2)'

  output:
    total_variations: 'N x M x P'
    priority_batch: 'Top 10-20 combinações por diversidade'

  rule: 'Constants vs Variables — mudar UM elemento por variação'
  expert: 'Brandon Carter'
```

### Step 3: Produce Batch

```yaml
production:
  batch_size: '10-20 criativos por ciclo'
  formats:
    - 'Video (15-60s)'
    - 'Image/Carousel'
    - 'UGC-style'

  per_creative:
    - hook: 'Único (variável principal)'
    - body: 'Constante dentro do teste'
    - cta: 'Constante dentro do teste'
    - format: 'Variável secundário'
```

### Step 4: Launch All Simultaneously

```yaml
launch:
  structure: 'ABO — budget igual por ad'
  budget_per_ad: 'R$30-50/dia'
  audience: 'Broad ou proven audience'
  placements: 'Automatic (Meta otimiza)'

  rule: 'NUNCA editar durante teste'
  observation_window: '48h mínimo'
```

### Step 5: Kill/Scale at 48h

```yaml
evaluation_48h:
  kill_criteria:
    - 'CTR < 1% após 48h'
    - 'CPA > 2x target'
    - 'Zero conversões com 50% budget gasto'

  scale_criteria:
    - 'CTR > média + 50%'
    - 'CPA < target'
    - 'ROAS > 2x'

  action:
    kill: 'Pausar imediatamente (bottom 80%)'
    hold: 'Monitorar mais 24h (middle performers)'
    scale: 'Promover para Winner campaign (top 20%)'
```

### Step 6: Winner Variation Cycle

```yaml
variation_cycle:
  trigger: 'Winner identificado no Step 5'

  production:
    - 'Same body + 5 new hooks'
    - 'Same hook + 3 new bodies'
    - 'Winner hook + different format (UGC, carousel, static)'

  output: '8-13 variações do winner'

  cycle_cadence: 'Semanal — toda semana novo batch'
  expert: 'Jeremy Haynes - Creative Lab Protocol'
```

---

## Output Format

```yaml
bombardment_report:
  campaign_id: '123456'
  analysis_date: '2026-02-15'
  analyst: '@ralph-burns'

  current_state:
    total_active_creatives: 4
    win_rate: '15%'
    fatigue_detected: true
    last_refresh: '21 dias atrás'
    status: 'CRITICAL — bombardeio necessário'

  combination_matrix:
    hooks: 5
    bodies: 3
    ctas: 2
    total_possible: 30
    priority_batch: 15

  batch_produced:
    total: 15
    formats:
      video: 8
      image: 4
      ugc: 3

  launch_config:
    structure: 'ABO'
    budget_per_ad: 'R$40/dia'
    total_daily: 'R$600/dia'
    audience: 'Proven LAL 1-3%'
    observation_window: '48h'

  results_48h:
    winners:
      count: 3
      ads:
        - ad_id: 'ad_001'
          hook: 'Hook Problema V1'
          ctr: 2.4
          cpa: 18
          roas: 3.2
          action: 'SCALE + gerar 5 variações'

    killed:
      count: 10
      reason: 'CTR < 1% ou CPA > 2x target'

    monitoring:
      count: 2
      reason: 'Métricas borderline — aguardar +24h'

  next_actions:
    - '1. Gerar 5 variações de cada winner (15 novos criativos)'
    - '2. Promover 3 winners para Winner campaign'
    - '3. Preparar próximo batch para semana seguinte'

  expert_attribution:
    bombardment: 'Jeremy Haynes - Hammer Them Bombardment System'
    testing: 'Brandon Carter - Constants vs Variables'
    pipeline: 'Jeremy Haynes - Creative Lab Protocol'
```

---

## Integration

### Triggered By

- `creative-fatigue-detector` - quando fadiga detectada (batch mode)
- `scale-readiness-check` - quando gap de criativos identificado (score < 85)
- User command - `*bombardment`

### Dispatches To

- `hook-generator` - gerar hooks para a matriz de combinação
- `copy-generator` - gerar copies/bodies para variações
- `creative-brief` - briefs de produção para o batch

### Agent Assignment

- **Primary:** @ralph-burns
- **Execution:** @creative-analyst

---

## Usage Examples

### Command Line

```
*bombardment campaign_123

*bombardment --batch-size 20 --focus retargeting

*bombardment --audit-only

*bombardment --variation-cycle winner_ad_001
```

### Sample Output

```
CREATIVE BOMBARDMENT - Campaign_123

+======================================================+
| STATUS: CRITICAL — apenas 4 criativos ativos          |
| WIN RATE: 15% (abaixo do threshold 20%)               |
+======================================================+
|                                                        |
| COMBINATION MATRIX:                                    |
| 5 hooks x 3 bodies x 2 CTAs = 30 variações possíveis |
| Batch prioritário: 15 criativos                        |
|                                                        |
+======================================================+
| LAUNCH CONFIG:                                         |
| Estrutura: ABO | Budget: R$40/ad | Total: R$600/dia  |
| Audiência: LAL 1-3% | Window: 48h                     |
+======================================================+
|                                                        |
| RESULTADOS 48h:                                        |
| Winners: 3 (top 20%) → SCALE + 5 variações cada      |
| Killed: 10 (bottom 67%) → PAUSADOS                    |
| Monitoring: 2 → aguardando +24h                        |
|                                                        |
+======================================================+
| NEXT: Gerar 15 variações dos winners                  |
|       Dispatch → hook-generator, copy-generator        |
| EXPERT: Jeremy Haynes - Bombardment System             |
+======================================================+
```

---

_Creative Bombardment Skill v1.0.0_
_Ads Squad - AIOS Synkra_
