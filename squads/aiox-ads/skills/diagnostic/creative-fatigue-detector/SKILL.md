# Creative Fatigue Detector Skill

**ID:** `creative-fatigue-detector`
**Category:** diagnostic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Detecta fadiga criativa em anúncios através de análise de tendências de métricas. Identifica quando criativos precisam ser renovados antes que a performance degrade significativamente.

**Activation Command:** `*detect-fatigue`
**Announce:** "Ativando Creative Fatigue Detector com Fatigue Indicators Framework."

---

## Expert Sources

| Expert         | Framework               | Weight | Focus              |
| -------------- | ----------------------- | ------ | ------------------ |
| Jeremy Haynes  | Fatigue Indicators      | 0.92   | Métricas de fadiga |
| Jeremy Haynes  | Creative Refresh Timing | 0.90   | Timing de refresh  |
| Brandon Carter | Constants vs Variables  | 0.88   | Teste científico   |

---

## Fatigue Indicators

### Primary Indicators

| Indicador       | Threshold  | Urgência | Ação                  |
| --------------- | ---------- | -------- | --------------------- |
| CTR Drop        | -30% em 7d | High     | Refresh hooks         |
| Frequency       | > 3.0      | High     | Expand audience       |
| CPM Spike       | +50% em 7d | Medium   | Test new creative     |
| Hook Rate Drop  | -25% em 7d | High     | New hooks urgente     |
| Conversion Drop | -40% em 7d | Critical | Full creative refresh |

### Secondary Indicators

| Indicador         | Threshold      | Significado                |
| ----------------- | -------------- | -------------------------- |
| Thumb Stop Ratio  | < 15%          | Visual não para scroll     |
| Video 25%         | < 30%          | Conteúdo não engaja        |
| Share Rate Drop   | -50%           | Criativo perdeu viralidade |
| Comment Sentiment | Negative trend | Audiência cansada          |

---

## Detection Algorithm

```python
def detect_fatigue(creative_metrics, window_days=7):
    fatigue_score = 0
    indicators = []

    # CTR Trend Analysis
    ctr_change = calculate_trend(metrics.ctr, window_days)
    if ctr_change < -30:
        fatigue_score += 30
        indicators.append({
            'type': 'ctr_drop',
            'change': ctr_change,
            'urgency': 'high'
        })

    # Frequency Analysis
    if metrics.frequency > 3:
        fatigue_score += 25
        indicators.append({
            'type': 'high_frequency',
            'value': metrics.frequency,
            'urgency': 'high'
        })

    # CPM Trend
    cpm_change = calculate_trend(metrics.cpm, window_days)
    if cpm_change > 50:
        fatigue_score += 20
        indicators.append({
            'type': 'cpm_spike',
            'change': cpm_change,
            'urgency': 'medium'
        })

    # Hook Rate (if video)
    if metrics.hook_rate:
        hook_change = calculate_trend(metrics.hook_rate, window_days)
        if hook_change < -25:
            fatigue_score += 25
            indicators.append({
                'type': 'hook_degradation',
                'change': hook_change,
                'urgency': 'high'
            })

    return {
        'fatigue_score': fatigue_score,
        'is_fatigued': fatigue_score >= 50,
        'indicators': indicators,
        'recommendation': get_recommendation(fatigue_score)
    }
```

---

## Fatigue Stages

### Stage 1: Early Warning (Score 25-49)

```yaml
symptoms:
  - CTR caindo levemente (-10% a -20%)
  - Frequência aumentando (2.0 - 2.5)
  - CPM estável ou levemente subindo

action: 'Monitorar de perto, preparar variações'
timeline: 'Criar novos criativos em 1 semana'
```

### Stage 2: Active Fatigue (Score 50-74)

```yaml
symptoms:
  - CTR caiu -30%+
  - Frequência > 3
  - CPM subindo +30%+
  - Hook rate degradando

action: 'Lançar novos criativos imediatamente'
timeline: 'Refresh em 48h'
skill_chain: [hook-generator, creative-brief]
```

### Stage 3: Critical Fatigue (Score 75+)

```yaml
symptoms:
  - CTR < 50% do inicial
  - Frequência > 4
  - Conversões caindo drasticamente
  - ROAS impactado

action: 'Pausar criativo, lançar substituição'
timeline: 'Ação imediata'
skill_chain: [kill-scale-rules, creative-brief, hook-generator]
```

---

## Output Format

```yaml
fatigue_analysis:
  creative_id: 'ad_123456'
  analysis_date: '2026-02-01'
  window_days: 7

  fatigue_score: 65
  stage: 'active_fatigue'

  current_metrics:
    ctr: 0.8
    frequency: 3.2
    cpm: 45
    hook_rate: 18

  trends:
    ctr_change: -35%
    frequency_change: +60%
    cpm_change: +28%
    hook_rate_change: -22%

  indicators:
    - type: 'ctr_drop'
      severity: 'high'
      value: '-35%'
      expert: 'Jeremy Haynes'

    - type: 'high_frequency'
      severity: 'high'
      value: 3.2
      expert: 'Jeremy Haynes'

  recommendation:
    action: 'Refresh criativo urgente'
    priority: 1
    skills_to_dispatch:
      - skill: 'hook-generator'
        reason: 'Criar 5+ variações de hook'
      - skill: 'creative-brief'
        reason: 'Novo brief para designer'

  expected_recovery:
    timeline: '3-5 dias após novos criativos'
    target_improvement: '+40% CTR'
```

---

## Integration

### Triggers

```yaml
metric_triggers:
  - condition: 'ctr_7d_change < -25%'
    action: 'run_fatigue_analysis'
  - condition: 'frequency > 3'
    action: 'run_fatigue_analysis'
  - condition: 'cpm_7d_change > 40%'
    action: 'run_fatigue_analysis'
```

### Dispatches To

- `hook-generator` - para criar novos hooks
- `creative-brief` - para brief completo
- `kill-scale-rules` - para pausar fatigados

### Agent Assignment

- **Primary:** @creative-analyst
- **Reports to:** @media-strategist

---

## Usage Examples

```
*detect-fatigue campaign_123

*detect-fatigue --all-active --threshold 50

*detect-fatigue --creative ad_456 --window 14d
```

### Sample Output

```
🎨 ANÁLISE DE FADIGA CRIATIVA

╔══════════════════════════════════════════════════════╗
║ CRIATIVO: ad_123456                                  ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ 🔴 FATIGUE SCORE: 65/100 - FADIGA ATIVA             ║
║                                                      ║
║ Indicadores Detectados:                              ║
║ • CTR: -35% em 7 dias (Jeremy Haynes)               ║
║ • Frequência: 3.2 (acima do limite 3.0)             ║
║ • Hook Rate: -22% (degradação do hook)              ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ AÇÃO: Refresh urgente em 48h                         ║
║ DISPATCH: hook-generator → @creative-analyst        ║
╚══════════════════════════════════════════════════════╝
```

---

_Creative Fatigue Detector Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
