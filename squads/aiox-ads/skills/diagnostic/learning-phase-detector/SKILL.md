# Learning Phase Detector Skill

**ID:** `learning-phase-detector`
**Category:** diagnostic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Detecta se campanhas ou ad sets estao em Learning Phase via metricas de campanha. Quando a Learning Phase esta ativa, esta skill BLOQUEIA todas as acoes de kill/scale para proteger o investimento do anunciante. O threshold principal e < 50 conversoes desde a ultima edicao significativa.

**Activation Command:** `*detect-learning-phase`
**Announce:** "Ativando Learning Phase Detector. Verificando status de aprendizado dos ad sets."

---

## Expert Sources

| Expert | Framework | Weight | Focus |
|--------|-----------|--------|-------|
| Meta Official Docs | Learning Phase Documentation | 1.00 | Threshold de 50 conversoes, triggers de reset |
| Brian Moncada | Andromeda Method | 0.90 | Analise sistematica de metricas durante aprendizado |

---

## Knowledge Reference

- **Primary:** `data/knowledge/meta/learning_phase.md`
- **Related:** `data/knowledge/meta/performance_fluctuations.md`, `data/knowledge/meta/bid_strategies.md`

---

## Detection Framework

### Learning Phase Criteria

```yaml
learning_phase_detection:
  primary_indicator:
    metric: optimization_events_since_last_significant_edit
    threshold: 50
    window: 7_days
    status_if_below: LEARNING_ACTIVE

  meta_api_status:
    field: effective_status
    values:
      - LEARNING
      - LEARNING_LIMITED

  fallback_heuristic:
    description: "Quando API status nao esta disponivel, usar metricas"
    conditions:
      - conversions_last_7d < 50
      - last_significant_edit_within_7d: true
      - delivery_pattern: inconsistent (daily variance > 40%)
```

### Learning Phase Status Classification

| Status | Condition | Action |
|--------|-----------|--------|
| LEARNING_ACTIVE | < 50 conversoes em 7 dias, edicao recente | BLOCK todas as modificacoes |
| LEARNING_LIMITED | Meta reporta Learning Limited | ALERT + recomendar ajustes estruturais |
| LEARNING_COMPLETE | >= 50 conversoes em 7 dias, status ACTIVE | Liberar acoes normais |
| LEARNING_UNKNOWN | Dados insuficientes (< 500 impressoes) | WARN + aguardar dados |

---

## BLOCK Rules (NON-NEGOTIABLE)

Quando Learning Phase esta ATIVA, as seguintes acoes sao **BLOQUEADAS**:

```yaml
blocked_actions_during_learning:
  kill_actions:
    - pause_ad_set
    - pause_ad
    - delete_ad_set
    - reduce_budget

  scale_actions:
    - increase_budget_over_20_percent
    - duplicate_ad_set
    - expand_audience
    - add_new_creative_to_ad_set

  modification_actions:
    - change_targeting
    - change_bid_strategy
    - change_optimization_event
    - change_placements

  sole_exception:
    condition: "Campaign violando politica OU queimando orcamento com ZERO resultados apos 2x o periodo esperado de aprendizado"
    action: "Pausar com justificativa documentada no action-ledger"
    tier: Human
```

### Human Alert Template

```
ALERTA: Campaign {campaign_name} esta em Learning Phase (dia {N}/7).
Nao modifique.

Ad Set: {ad_set_name}
Conversoes acumuladas: {current_conversions}/50
Status Meta: {LEARNING | LEARNING_LIMITED}
Ultima edicao significativa: {edit_date} ({edit_type})
Estimativa de saida: {estimated_exit_date}

Acoes BLOQUEADAS ate saida da Learning Phase:
- Kill/pause de ads ou ad sets
- Mudancas de orcamento > 20%
- Edicoes de targeting, criativos, bid strategy

Acao recomendada: AGUARDAR ate {estimated_exit_date}.
```

---

## Learning Phase Reset Triggers

Edicoes que RESETAM o contador de aprendizado para zero:

| # | Trigger | Threshold | Impacto |
|---|---------|-----------|---------|
| 1 | Mudanca de orcamento | > 20% (aumento ou reducao) | Reset completo |
| 2 | Edicao de targeting | Qualquer mudanca em audiencias, localizacoes, demografia | Reset completo |
| 3 | Edicao de criativo | Novo criativo, texto alterado, nova imagem/video | Reset completo |
| 4 | Mudanca de evento de otimizacao | Ex: Clicks para Conversions | Reset completo |
| 5 | Mudanca de bid strategy | Ex: Lowest Cost para Cost Cap | Reset completo |
| 6 | Adicao de novo ad ao ad set | Inserir novo criativo no ad set existente | Reset completo |
| 7 | Pausa por 7+ dias | Periodo de pausa prolongado | Reset completo ao retomar |
| 8 | Edicao de placements | Adicionar ou remover placements | Reset completo |

### O que NAO reseta Learning Phase

- Ajustes de orcamento <= 20%
- Mudanca de nome do ad set ou campanha
- Atualizacao da data final do agendamento
- Visualizacao ou download de relatorios

---

## Analysis Process

### Step 1: Coleta de Status

```yaml
required_data:
  from_api:
    - ad_set.effective_status
    - ad_set.delivery_info
    - ad_set.last_significant_edit_date
  from_metrics:
    - conversions (7d window)
    - impressions (total)
    - daily_spend_variance
  from_campaign_state:
    - campaign-state.yaml: learning_phase section
    - action-ledger.yaml: recent edits
```

### Step 2: Classificacao

```
FOR EACH ad_set in campaign:
    IF api_status == LEARNING OR LEARNING_LIMITED:
        status = LEARNING_ACTIVE
    ELIF conversions_7d < 50 AND last_significant_edit < 7d:
        status = LEARNING_ACTIVE (heuristic)
    ELIF api_status == LEARNING_LIMITED:
        status = LEARNING_LIMITED
    ELSE:
        status = LEARNING_COMPLETE

    IF status == LEARNING_ACTIVE:
        BLOCK all kill/scale actions
        ALERT human with template
        UPDATE campaign-state.yaml learning_phase section
```

### Step 3: Monitoramento Continuo

```yaml
monitoring:
  check_frequency: daily (part of pulse report)
  track_progress:
    - conversions_accumulated vs 50 target
    - days_in_learning (max expected: 7)
    - daily_trend (accelerating, flat, decelerating)
  escalation:
    condition: "14+ dias em Learning Phase sem progresso"
    action: "Recomendar revisao estrutural (orcamento, audiencia, evento de otimizacao)"
    tier: HITL
```

---

## Output Format

```yaml
learning_phase_report:
  campaign: '{campaign_name}'
  check_date: '{date}'

  ad_sets:
    - name: '{ad_set_name}'
      status: LEARNING_ACTIVE | LEARNING_LIMITED | LEARNING_COMPLETE | LEARNING_UNKNOWN
      conversions_accumulated: {N}
      conversions_target: 50
      days_in_learning: {N}
      last_significant_edit:
        date: '{date}'
        type: '{budget_change | targeting_edit | creative_edit | ...}'
      estimated_exit: '{date or UNLIKELY}'
      blocked_actions: [kill, scale, modify]

  summary:
    total_ad_sets: {N}
    in_learning: {N}
    learning_limited: {N}
    learning_complete: {N}
    overall_recommendation: 'WAIT | RESTRUCTURE | CLEAR'
```

---

## Integration

### Dispatches To

- `metric-diagnosis` -- apos saida da Learning Phase, analisar performance real
- `kill-scale-rules` -- liberar acoes de kill/scale quando Learning Phase completa

### Receives From

- `campaign-monitor` -- trigger automatico diario
- `metric-diagnosis` -- antes de qualquer recomendacao de kill/scale
- User command -- `*detect-learning-phase`

### Agent Assignment

- **Primary:** @performance-analyst
- **Tier:** Auto (deteccao) + HITL (enforcement de bloqueio)
- **Reports to:** @media-strategist

---

## Usage Examples

### Command Line

```
*detect-learning-phase campaign_123

*detect-learning-phase --all-active

*detect-learning-phase --alert-only
```

### Sample Output

```
LEARNING PHASE DETECTOR - Campaign_123

Ad Set: Prospecting_Lookalike_1%
  Status: LEARNING_ACTIVE (dia 3/7)
  Conversoes: 18/50
  Ultima edicao: 2026-03-15 (budget +25%)
  Estimativa de saida: 2026-03-22

  BLOQUEADO: kill, scale, modify
  Acao: AGUARDAR

Ad Set: Retargeting_Visitors_30d
  Status: LEARNING_COMPLETE
  Conversoes: 67/50
  Acao: LIBERADO para otimizacao

Resumo: 1/2 ad sets em Learning Phase. NAO MODIFICAR.
```

---

_Learning Phase Detector Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
