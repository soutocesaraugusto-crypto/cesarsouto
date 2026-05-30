# Accountability Loop Skill

**ID:** `accountability-loop`
**Category:** operational
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Rastreamento de todas as decisoes tomadas por cada agente (kill/scale/pause/launch/swap) com feedback loop de 48h para comparar decisao vs resultado real. Classifica erros por tipo (processo, julgamento, execucao), identifica padroes repetitivos e gera Accountability Reports semanais com hit rate de decisoes. Aplica o Mistake Response Protocol de Ryan Deiss para tratamento sistematico de falhas.

**Activation Command:** `*accountability-report`
**Announce:** "Ativando Accountability Loop com Mistake Response Protocol e Decision Tracking."

---

## Expert Sources

| Expert      | Framework                | Weight | Focus                        |
| ----------- | ------------------------ | ------ | ---------------------------- |
| Ryan Deiss  | Accountability Loop      | 0.92   | Ciclo de responsabilizacao   |
| Ryan Deiss  | Mistake Response Protocol| 0.90   | Protocolo de erros           |
| Ryan Deiss  | Traffic Light Leadership | 0.85   | Status visual                |

---

## Accountability Framework

### Decision Tracking Flow

```
Decisao tomada (kill/scale/pause/launch/swap)
    |
    +-- Log: agente, acao, razao, dados, timestamp
    |
    +-- Timer: 48h
    |
    +-- 48h depois: Comparar outcome vs expected
            |
            +-- Decisao CORRETA?
            |       |
            |       +-- SIM --> +1 hit rate
            |       |           Log success pattern
            |       |           Identificar o que funcionou
            |       |
            |       +-- NAO --> Classificar erro:
            |               |
            |               +-- PROCESS ERROR (SOP nao existia)
            |               |       |
            |               |       +-- Criar SOP
            |               |       +-- Documentar gap
            |               |       +-- Menor gravidade (sistema falhou)
            |               |
            |               +-- JUDGMENT ERROR (decisao ruim com dados bons)
            |               |       |
            |               |       +-- Revisar framework de decisao
            |               |       +-- Ajustar thresholds
            |               |       +-- Gravidade media
            |               |
            |               +-- EXECUTION ERROR (SOP existia, nao seguido)
            |                       |
            |                       +-- Alertar agente responsavel
            |                       +-- Registrar violacao
            |                       +-- Maior gravidade (negligencia)
            |
            +-- Atualizar hit rate do agente
            +-- Verificar padroes repetitivos
```

### Mistake Response Protocol Decision Tree

```
Erro detectado
    |
    +-- Existia SOP/processo para esta situacao?
    |       |
    |       +-- NAO --> PROCESS ERROR
    |       |           Acao: criar SOP, sem penalidade ao agente
    |       |
    |       +-- SIM --> O agente seguiu o SOP?
    |               |
    |               +-- NAO --> EXECUTION ERROR
    |               |           Acao: retrain, alert, registrar violacao
    |               |
    |               +-- SIM --> O SOP era adequado?
    |                       |
    |                       +-- NAO --> PROCESS ERROR (SOP desatualizado)
    |                       |           Acao: atualizar SOP
    |                       |
    |                       +-- SIM --> JUDGMENT ERROR
    |                                   Acao: revisar framework, calibrar thresholds
```

### Error Severity Matrix

```
+---------------------+------------+-----------+------------------+
| Tipo de Erro        | Gravidade  | Recorrencia| Acao             |
+---------------------+------------+-----------+------------------+
| Process Error       | BAIXA      | 1x        | Criar SOP        |
| Process Error       | MEDIA      | 2x        | Priorizar SOP    |
| Judgment Error      | MEDIA      | 1x        | Revisar framework|
| Judgment Error      | ALTA       | 3x        | Escalar review   |
| Execution Error     | ALTA       | 1x        | Alert + retrain  |
| Execution Error     | CRITICA    | 2x        | Escalar @ad-midas|
+---------------------+------------+-----------+------------------+
```

---

## Tracking Process

### Step 1: Decision Logging

```yaml
decision_log:
  required_fields:
    - agent: "qual agente tomou a decisao"
    - action: "kill | scale | pause | launch | swap | budget_change"
    - campaign: "identificador da campanha"
    - reason: "justificativa baseada em dados"
    - data_snapshot:
        - metric: "valor no momento da decisao"
        - threshold: "regra que triggou a acao"
    - timestamp: "ISO 8601"
    - expected_outcome: "o que se esperava acontecer"
    - review_at: "timestamp + 48h"
```

### Step 2: 48h Outcome Comparison

```yaml
outcome_review:
  timing: "48h apos decisao"
  comparison:
    - expected_outcome: "o que foi previsto"
    - actual_outcome: "o que aconteceu de fato"
    - delta: "diferenca percentual"
    - verdict: "correct | incorrect | inconclusive"
  inconclusive_criteria:
    - "dados insuficientes no periodo"
    - "fatores externos alteraram resultado (ex: Black Friday)"
    - "mudanca de plataforma no periodo"
  inconclusive_action: "estender review para 96h"
```

### Step 3: Error Classification

```yaml
error_classification:
  process_error:
    definition: "SOP nao existia para esta situacao"
    action: "Criar SOP documentando o cenario e a decisao correta"
    blame: "sistema (nao agente)"
    example: "Nao havia regra para audiencia < 500 pessoas"

  judgment_error:
    definition: "Agente tinha dados e SOP, mas tomou decisao subotima"
    action: "Revisar framework de decisao, calibrar thresholds"
    blame: "framework (ajustar calibracao)"
    example: "Escalou budget com CPA em tendencia de alta"

  execution_error:
    definition: "SOP existia e nao foi seguido"
    action: "Alertar agente, registrar violacao, reforcar processo"
    blame: "agente (mais grave)"
    example: "Kill rule mandava pausar, agente manteve campanha ativa"
```

### Step 4: Pattern Detection

```yaml
pattern_detection:
  window: "ultimos 30 dias"
  rules:
    - if_same_error_type_3x:
        action: "gerar alerta de padrao"
        message: "Padrao detectado: {error_type} ocorreu {count}x em {period}"
        create_sop: true

    - if_same_agent_low_hit_rate:
        threshold: "< 60%"
        action: "escalar para revisao de frameworks"
        message: "Hit rate do agente {agent} esta em {rate}%. Revisar calibracao."

    - if_same_campaign_repeated_errors:
        threshold: "3+ erros em 30 dias"
        action: "flag campanha para analise profunda"
```

### Step 5: Weekly Report Generation

```yaml
weekly_report:
  generated: "toda segunda-feira 08:00"
  content:
    - hit_rate_global: "percentual de decisoes corretas"
    - hit_rate_per_agent: "breakdown por agente"
    - hit_rate_per_action_type: "kill, scale, pause, launch, swap"
    - errors_by_type: "process | judgment | execution"
    - patterns_detected: "erros recorrentes"
    - sops_created: "novos SOPs da semana"
    - lessons_learned: "insights extraidos"
    - trend: "hit rate vs semana anterior"
```

---

## SE/ENTAO Rules

```yaml
rules:
  - se: "decisao de scale resultou em CPA +50% em 48h"
    entao: "registrar como judgment error, revisar threshold de scale"
    severity: high

  - se: "mesmo tipo de erro ocorre 3x em 30 dias"
    entao: "gerar alerta de padrao + criar/atualizar SOP"
    severity: high

  - se: "hit rate de decisoes < 60%"
    entao: "escalar para revisao de frameworks pelo @ad-midas"
    severity: critical

  - se: "agente nao documenta decisao"
    entao: "warning no report, decisao marcada como undocumented"
    severity: medium

  - se: "processo existia e nao foi seguido"
    entao: "execution error (mais grave), alert imediato"
    severity: critical
```

---

## Output Format

```yaml
accountability_report:
  period: "2026-03-09 a 2026-03-15"
  generated_at: "2026-03-16T08:00:00Z"

  overall:
    total_decisions: 23
    correct: 17
    incorrect: 4
    inconclusive: 2
    hit_rate: "73.9%"
    trend: "ascending"
    trend_vs_previous: "+5.2%"

  by_agent:
    - agent: "@ad-midas"
      decisions: 8
      correct: 7
      hit_rate: "87.5%"
      trend: "stable"

    - agent: "@fiscal"
      decisions: 6
      correct: 5
      hit_rate: "83.3%"
      trend: "ascending"

    - agent: "@performance-analyst"
      decisions: 9
      correct: 5
      hit_rate: "55.5%"
      trend: "descending"
      alert: "Hit rate abaixo de 60%. Revisar frameworks."

  by_action_type:
    - action: "kill"
      total: 7
      correct: 6
      hit_rate: "85.7%"

    - action: "scale"
      total: 5
      correct: 2
      hit_rate: "40.0%"
      alert: "Scale decisions com hit rate baixo. Calibrar thresholds."

    - action: "pause"
      total: 6
      correct: 5
      hit_rate: "83.3%"

    - action: "launch"
      total: 3
      correct: 2
      hit_rate: "66.7%"

    - action: "swap"
      total: 2
      correct: 2
      hit_rate: "100%"

  errors:
    - type: "judgment_error"
      count: 3
      examples:
        - "Scale de FB_CONV_COLD_VID03 com CPA em tendencia de alta"
        - "Launch de audiencia lookalike sem teste A/B previo"
      action: "Revisar thresholds de scale e launch criteria"

    - type: "process_error"
      count: 1
      examples:
        - "Sem SOP para budget allocation em campanhas de awareness"
      action: "SOP criado: awareness-budget-allocation-v1"

    - type: "execution_error"
      count: 0

  patterns_detected:
    - pattern: "Scale prematuro"
      occurrences: 2
      period: "ultimas 3 semanas"
      recommendation: "Adicionar gate de 72h de estabilidade antes de scale"

  sops_created:
    - "awareness-budget-allocation-v1"

  lessons_learned:
    - "Scale decisions precisam de 72h de CPA estavel, nao apenas 24h"
    - "Lookalike audiences precisam de teste A/B antes de launch full budget"

  next_actions:
    - "Calibrar threshold de scale: exigir 72h de estabilidade"
    - "Criar checklist pre-launch para audiencias novas"
    - "Review de frameworks com @ad-midas para @performance-analyst"
```

---

## Integration

### Dispatches To

- `@ad-midas` - report semanal e escalacoes (hit rate < 60%, 3+ red)
- Agente responsavel - alertas de execution error e padroes detectados
- `metric-diagnosis` - quando padrao de erro sugere problema em metricas

### Receives From

- `campaign-monitor` - cada decisao executada (log automatico)
- `kill-scale-rules` - pos-acao (log de kill/scale decisions)
- User command - `*accountability-report`

### Agent Assignment

- **Primary:** @fiscal (Sentinel)
- **Reports to:** @ad-midas

---

## Usage Examples

### Command Line

```
*accountability-report

*accountability-report --period 30d

*accountability-report --agent @performance-analyst --focus errors

*accountability-report --action-type scale --backtest
```

### Sample Output

```
ACCOUNTABILITY REPORT - Semana 2026-03-09 a 2026-03-15

+------+---------------------+----------+---------+----------+-------+
|  #   | Agente              | Decisoes | Acertos | Hit Rate | Trend |
+------+---------------------+----------+---------+----------+-------+
|  1   | @ad-midas           |     8    |    7    | 87.5%    |  ->   |
|  2   | @fiscal             |     6    |    5    | 83.3%    |   ^   |
|  3   | @performance-analyst|     9    |    5    | 55.5%    |   v   |
+------+---------------------+----------+---------+----------+-------+

GLOBAL: 23 decisoes | 17 acertos | Hit Rate: 73.9% (^ +5.2%)

ERROS DA SEMANA:
  Judgment:  3 (scale prematuro, launch sem teste)
  Process:   1 (SOP criado: awareness-budget-allocation-v1)
  Execution: 0

PADROES DETECTADOS:
  Scale prematuro: 2x em 3 semanas --> Gate 72h proposto

ACOES:
  1. Calibrar threshold de scale (72h estabilidade)
  2. Checklist pre-launch para audiencias novas
  3. Review de frameworks: @performance-analyst (hit rate 55.5%)
```

---

_Accountability Loop Skill v1.0.0_
_AIOX Ads Squad - AIOS Synkra_
