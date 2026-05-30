# Metric Diagnosis Skill

**ID:** `metric-diagnosis`
**Category:** diagnostic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Diagnóstico completo de métricas de campanha para identificar problemas, gargalos e oportunidades de otimização. Usa frameworks do Brian Moncada (Andromeda) e Jeremy Haynes para análise sistemática.

**Activation Command:** `*diagnose-metrics`
**Announce:** "Ativando Metric Diagnosis com Andromeda Method e Kill Rules."

---

## Expert Sources

| Expert        | Framework              | Weight | Focus                           |
| ------------- | ---------------------- | ------ | ------------------------------- |
| Brian Moncada | Andromeda Method       | 0.90   | Análise sistemática de métricas |
| Jeremy Haynes | Kill Rules             | 0.95   | Thresholds de decisão           |
| Jeremy Haynes | Constants vs Variables | 0.95   | Isolamento de variáveis         |

---

## Diagnostic Framework

### Metric Hierarchy (Top-Down Analysis)

```
Nível 1: ROAS/CPA (Resultado Final)
    ↓
Nível 2: Conversion Rate, Cost per Conversion
    ↓
Nível 3: CTR, Landing Page Conversion
    ↓
Nível 4: Impressions, CPM, Reach
    ↓
Nível 5: Audience Quality, Creative Quality
```

### Diagnostic Matrix

| Sintoma                  | Possível Causa     | Verificar             | Skill Relacionada         |
| ------------------------ | ------------------ | --------------------- | ------------------------- |
| ROAS baixo, CTR alto     | Landing page fraca | LP conversion rate    | funnel-analysis           |
| ROAS baixo, CTR baixo    | Criativo ruim      | Hook rate, thumb stop | creative-fatigue-detector |
| CPA alto, CVR ok         | CPM alto           | Audiência saturada    | audience-expansion        |
| CPA alto, CVR baixo      | Qualificação fraca | Tracking, audience    | tracking-audit            |
| CTR baixo, impressões ok | Hook fraco         | Primeiros 3 seg       | hook-generator            |

---

## Analysis Process

### Step 1: Data Collection

```yaml
required_metrics:
  - roas
  - cpa
  - cpc
  - ctr
  - cpm
  - conversion_rate
  - impressions
  - clicks
  - conversions
  - spend
  - frequency

optional_metrics:
  - hook_rate
  - thumb_stop_ratio
  - video_completion_rates
  - landing_page_views
  - outbound_clicks
```

### Step 2: Benchmark Comparison

```yaml
benchmarks_brasil:
  ctr:
    poor: '< 0.5%'
    average: '0.5% - 1%'
    good: '1% - 2%'
    excellent: '> 2%'

  cpm:
    excellent: '< R$20'
    good: 'R$20 - R$35'
    average: 'R$35 - R$50'
    poor: '> R$50'

  roas_perpetuo:
    critical: '< 1.0'
    poor: '1.0 - 1.5'
    breakeven: '1.5 - 2.0'
    good: '2.0 - 3.0'
    excellent: '> 3.0'
```

### Step 3: Root Cause Analysis

```
IF ROAS < target:
    │
    ├── CTR ok? ─────────────┐
    │   YES → Landing Page   │
    │   NO  → Creative       │
    │                        │
    ├── CVR ok? ─────────────┤
    │   YES → Traffic Cost   │
    │   NO  → Offer/Trust    │
    │                        │
    └── CPM ok? ─────────────┘
        YES → Optimization
        NO  → Audience
```

---

## Output Format

```yaml
diagnosis:
  summary: 'CPA 45% acima do target devido a CTR baixo'

  metrics_analyzed:
    - metric: 'ctr'
      value: 0.8
      benchmark: 1.5
      status: 'below_average'
      impact: 'high'

  root_causes:
    - cause: 'Hook fraco nos primeiros 3 segundos'
      confidence: 0.85
      evidence: 'Hook rate 12% (benchmark 25%)'
      expert: 'Jeremy Haynes'

  recommendations:
    - action: 'Testar 5 novos hooks mantendo body constante'
      priority: 1
      skill: 'hook-generator'
      expected_impact: '+30% CTR'

    - action: 'Pausar ads com CTR < 0.5%'
      priority: 2
      skill: 'kill-scale-rules'
      expected_impact: '-20% CPA'

  next_steps:
    - '1. Executar hook-generator para criar variações'
    - '2. Aplicar kill-scale-rules para pausar underperformers'
    - '3. Reavaliar em 48h'
```

---

## Integration

### Dispatches To

- `hook-generator` - quando problema é hook/criativo
- `tracking-audit` - quando há discrepância de dados
- `funnel-analysis` - quando problema é pós-clique
- `kill-scale-rules` - para decisões de pause/scale

### Receives From

- `campaign-monitor` - trigger automático por métricas
- User command - `*diagnose-metrics`

### Agent Assignment

- **Primary:** @performance-analyst
- **Reports to:** @media-strategist

---

## Usage Examples

### Command Line

```
*diagnose-metrics campaign_123

*diagnose-metrics --period 7d --compare-baseline

*diagnose-metrics --focus cpa --threshold 2x
```

### Sample Output

```
📊 DIAGNÓSTICO DE MÉTRICAS - Campaign_123

╔══════════════════════════════════════════════════════╗
║ RESUMO: CPA 2.1x acima do target                     ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ ⚠️  CTR: 0.8% (benchmark: 1.5%) - ABAIXO             ║
║ ✅ CVR: 3.2% (benchmark: 2.5%) - OK                  ║
║ ⚠️  CPM: R$42 (benchmark: R$30) - ACIMA              ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ ROOT CAUSE: Hook fraco (Jeremy Haynes - Kill Rules)  ║
╠══════════════════════════════════════════════════════╣
║ AÇÃO: Gerar novos hooks → Skill: hook-generator      ║
╚══════════════════════════════════════════════════════╝
```

---

_Metric Diagnosis Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
