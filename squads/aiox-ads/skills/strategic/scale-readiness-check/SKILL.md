# Scale Readiness Check Skill

**ID:** `scale-readiness-check`
**Category:** strategic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Avaliação completa de prontidão para escalar campanhas. Verifica métricas, infraestrutura, tracking, criativos e capacidade operacional antes de aumentar investimento.

**Activation Command:** `*check-scale-readiness`
**Announce:** "Ativando Scale Readiness Check com frameworks Jeremy Haynes e Alex Hormozi."

---

## Expert Sources

| Expert        | Framework           | Weight | Focus                 |
| ------------- | ------------------- | ------ | --------------------- |
| Jeremy Haynes | Scale Prerequisites | 0.95   | Métricas de prontidão |
| Alex Hormozi  | Hydra Strategy      | 0.90   | Escala agressiva      |
| Brian Moncada | Andromeda Scale     | 0.88   | Validação de escala   |

---

## Readiness Checklist

### 1. Metric Stability (Peso: 30%)

```yaml
checks:
  roas_stability:
    requirement: 'ROAS > target por 3+ dias'
    variance_max: '±10%'
    score_weight: 10

  cpa_stability:
    requirement: 'CPA < target por 3+ dias'
    variance_max: '±15%'
    score_weight: 10

  conversion_volume:
    requirement: '50+ conversões/semana'
    reason: 'Dados suficientes para otimização'
    score_weight: 10

passing_score: 25/30
```

### 2. Creative Health (Peso: 25%)

```yaml
checks:
  fatigue_status:
    requirement: 'CTR não caindo'
    window: '7 dias'
    score_weight: 8

  variation_count:
    requirement: '3+ criativos ativos performando'
    reason: 'Backup se um fatigar'
    score_weight: 8

  hook_rate:
    requirement: 'Hook rate > 20%'
    score_weight: 9

passing_score: 20/25
```

### 3. Tracking Integrity (Peso: 20%)

```yaml
checks:
  capi_status:
    requirement: 'CAPI ativo e funcionando'
    score_weight: 7

  event_match_quality:
    requirement: 'EMQ >= 7'
    score_weight: 7

  data_consistency:
    requirement: 'Meta vs Backend variance < 20%'
    score_weight: 6

passing_score: 16/20
```

### 4. Audience Headroom (Peso: 15%)

```yaml
checks:
  frequency:
    requirement: 'Frequency < 2.5'
    reason: 'Espaço para mais impressões'
    score_weight: 5

  saturation:
    requirement: 'Saturation < 60%'
    score_weight: 5

  expansion_options:
    requirement: 'LAL expansão ou broad viável'
    score_weight: 5

passing_score: 12/15
```

### 5. Infrastructure Capacity (Peso: 10%)

```yaml
checks:
  landing_page:
    requirement: 'Page load < 3s, uptime > 99.5%'
    score_weight: 3

  checkout:
    requirement: 'Checkout conversion > 30%'
    score_weight: 3

  support_capacity:
    requirement: 'Pode atender volume maior'
    score_weight: 4

passing_score: 8/10
```

---

## Scoring System

```yaml
total_score: 100

thresholds:
  ready_to_scale: '> 85'
  minor_fixes_needed: '70-85'
  significant_work_needed: '50-70'
  not_ready: '< 50'

category_weights:
  metrics: 30
  creative: 25
  tracking: 20
  audience: 15
  infrastructure: 10
```

---

## Scale Strategies by Score

### Score 90-100: Full Speed Ahead

```yaml
recommendation: 'Escalar agressivamente'
actions:
  - 'Aumentar budget 30-50%'
  - 'Duplicar em novas audiências'
  - 'Considerar múltiplas estruturas'
expert: 'Alex Hormozi - Hydra Strategy'
```

### Score 85-89: Scale with Monitoring

```yaml
recommendation: 'Escalar com atenção'
actions:
  - 'Aumentar budget 20%'
  - 'Monitorar métricas diariamente'
  - 'Preparar criativos backup'
```

### Score 70-84: Fix Then Scale

```yaml
recommendation: 'Corrigir gaps primeiro'
actions:
  - 'Endereçar pontos vermelhos'
  - 'Aguardar 3-5 dias'
  - 'Reavaliar'
common_fixes:
  - 'Melhorar criativos'
  - 'Otimizar tracking'
  - 'Estabilizar métricas'
```

### Score 50-69: Significant Work

```yaml
recommendation: 'Trabalho significativo necessário'
actions:
  - 'Não escalar'
  - 'Diagnosticar problemas'
  - 'Possivelmente reestruturar'
```

### Score <50: Not Ready

```yaml
recommendation: 'Não pronto para escala'
actions:
  - 'Voltar ao básico'
  - 'Validar oferta'
  - 'Reconstruir fundação'
```

---

## Output Format

```yaml
scale_readiness:
  campaign_id: '123456'
  analysis_date: '2026-02-01'
  analyst: '@performance-analyst'

  overall_score: 87
  status: 'SCALE WITH MONITORING'

  category_scores:
    metrics:
      score: 28/30
      status: '🟢 PASS'
      details:
        roas_stability: '✅ 2.8 avg, ±7% variance, 5 days'
        cpa_stability: '✅ R$25 avg, ±12% variance'
        conversion_volume: '✅ 72 conversões/semana'

    creative:
      score: 22/25
      status: '🟡 NEAR PASS'
      details:
        fatigue_status: '✅ CTR estável'
        variation_count: '⚠️ Apenas 2 criativos ativos'
        hook_rate: '✅ 24%'
      action_needed: 'Adicionar 2+ criativos backup'

    tracking:
      score: 18/20
      status: '🟢 PASS'
      details:
        capi_status: '✅ Ativo'
        emq: '✅ 7.8'
        data_consistency: '⚠️ 18% variance'

    audience:
      score: 12/15
      status: '🟢 PASS'
      details:
        frequency: '✅ 1.8'
        saturation: '✅ 45%'
        expansion_options: '✅ LAL 3% disponível'

    infrastructure:
      score: 7/10
      status: '🟡 NEAR PASS'
      details:
        landing_page: '✅ 2.1s load'
        checkout: '⚠️ 28% conversion'
        support_capacity: '✅ OK'
      action_needed: 'Otimizar checkout'

  blockers:
    critical: []
    high:
      - 'Apenas 2 criativos ativos - risco de fadiga'
    medium:
      - 'Checkout conversion 28% (target 30%)'
      - 'Data variance 18% (target <15%)'

  recommendations:
    before_scaling:
      - action: 'Adicionar 2-3 criativos novos'
        priority: 1
        timeline: 'Antes de escalar'

      - action: 'Otimizar checkout'
        priority: 2
        timeline: 'Em paralelo'

    scale_plan:
      phase_1:
        timing: 'Após criativos prontos'
        budget_increase: '+20%'
        monitor: 'Diário'

      phase_2:
        timing: '5 dias após phase 1'
        condition: 'Se métricas mantidas'
        budget_increase: '+20% adicional'

  expert_attribution:
    readiness_check: 'Jeremy Haynes - Scale Prerequisites'
    scale_strategy: 'Alex Hormozi - Hydra Strategy'
```

---

## Integration

### Triggered By

- `kill-scale-rules` - antes de escalar
- `unit-economics` - após validar economia
- User command - `*check-scale-readiness`

### Dispatches To

- `budget-allocation` - se aprovado
- `creative-brief` - se precisa criativos
- `tracking-audit` - se tracking tem gaps

### Agent Assignment

- **Primary:** @performance-analyst
- **Approval:** @media-strategist

---

## Usage Examples

```
*check-scale-readiness campaign_123

*check-scale-readiness --all-profitable

*check-scale-readiness --detailed-gaps
```

### Sample Output

```
🚀 SCALE READINESS CHECK - Campaign_123

╔══════════════════════════════════════════════════════╗
║ OVERALL SCORE: 87/100                                ║
║ STATUS: 🟡 SCALE WITH MONITORING                    ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ 📊 Metrics:      28/30 🟢                           ║
║ 🎨 Creative:     22/25 🟡 (precisa +2 criativos)   ║
║ 📍 Tracking:     18/20 🟢                           ║
║ 👥 Audience:     12/15 🟢                           ║
║ 🏗️  Infra:        7/10 🟡 (checkout 28%)           ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ BLOQUEADORES:                                        ║
║ 🔴 Critical: 0                                       ║
║ 🟠 High: 1 (poucos criativos)                       ║
║ 🟡 Medium: 2                                         ║
╠══════════════════════════════════════════════════════╣
║ RECOMENDAÇÃO:                                        ║
║ 1. Adicionar 2-3 criativos → dispatch @creative    ║
║ 2. Otimizar checkout → 28% → 30%+                   ║
║ 3. Escalar +20% após correções                      ║
╠══════════════════════════════════════════════════════╣
║ EXPERT: Jeremy Haynes - Scale Prerequisites          ║
╚══════════════════════════════════════════════════════╝
```

---

_Scale Readiness Check Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
