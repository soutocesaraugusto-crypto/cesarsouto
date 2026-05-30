# Monitoring Setup Skill

**ID:** `monitoring-setup`
**Category:** operational
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Configuracao de thresholds persistentes de monitoramento por campanha, definicao de schedule adaptativo, e integracao com os templates de output (`campaign-state.yaml` e `pulse-report.md`). Esta skill CONFIGURA o monitoramento -- a execucao continua e responsabilidade do `campaign-monitor` (skill de automacao).

**Activation Command:** `*setup-monitoring`
**Announce:** "Ativando Monitoring Setup -- configuracao de thresholds e schedule por campanha."

---

## Agent Assignment

- **Primary:** @performance-analyst
- **Tier:** Auto (configuracao e monitoramento) + HITL (acoes derivadas de alertas)
- **Reports to:** @ad-midas

---

## References

| Arquivo | Finalidade |
|---------|-----------|
| `templates/campaign-state.yaml` | Template de output -- formato para estado persistente da campanha |
| `templates/pulse-report.md` | Template de output -- formato do report diario de 5 linhas |
| `data/rate-limits.yaml` | Cadencia maxima de API calls por tier |
| `config/safety-rules.yaml` | Thresholds de budget, rampagem, learning phase |

---

## Core Capabilities

### 1. Persistent Thresholds (campaign-monitors.yaml)

Cada campanha monitorada recebe thresholds personalizados salvos em `workspace/businesses/{slug}/ads/{platform}/campaign-monitors.yaml`. Os valores abaixo sao os defaults -- o @performance-analyst pode ajustar por campanha com base no historico.

```yaml
# campaign-monitors.yaml -- thresholds persistentes por campanha
# Path: workspace/businesses/{slug}/ads/{platform}/campaign-monitors.yaml
# Managed by: @performance-analyst
# Read by: campaign-monitor skill (automation loop)

version: "1.0.0"

monitors:

  - campaign_slug: "{campaign_slug}"
    campaign_id: "{platform_campaign_id}"
    schedule_tier: "first_72h"  # first_72h | standard | stable

    thresholds:

      # ── CPA SPIKE ──────────────────────────────────
      cpa_spike:
        warn:
          condition: "CPA > target * 1.5"
          description: "CPA 50% acima do target -- investigar"
          action: "Log anomalia + incluir no pulse-report como alert"
        alert:
          condition: "CPA > target * 3"
          description: "CPA 3x acima do target -- kill rule"
          action: "HITL: recomendar pause da campanha/adset"
          tier: "HITL"

      # ── CTR DROP ────────────────────────────────────
      ctr_drop:
        warn:
          condition: "CTR < rolling_7d_avg * 0.80"
          description: "CTR caiu > 20% vs media 7 dias"
          action: "Log anomalia + dispatch para @creative-analyst"
        alert:
          condition: "CTR < rolling_7d_avg * 0.50"
          description: "CTR caiu > 50% vs media 7 dias"
          action: "HITL: recomendar pausa + analise de fadiga criativa"
          tier: "HITL"

      # ── BUDGET OVERSPEND ────────────────────────────
      budget_overspend:
        warn:
          condition: "daily_spend > daily_budget * 1.10"
          description: "Spend 10% acima do budget diario"
          action: "Log anomalia + incluir no pulse-report"
        alert:
          condition: "daily_spend > daily_budget * 1.20"
          description: "Spend 20% acima do budget diario"
          action: "HITL: recomendar ajuste de budget ou pausa"
          tier: "HITL"

      # ── FREQUENCY (CREATIVE FATIGUE) ────────────────
      frequency:
        warn:
          condition: "frequency > 2.5"
          description: "Fadiga criativa iminente -- frequencia > 2.5"
          action: "Dispatch para @creative-analyst: recomendar refresh"
        alert:
          condition: "frequency > 3.0"
          description: "Fadiga criativa confirmada -- frequencia > 3.0"
          action: "HITL: recomendar creative swap ou audience expansion"
          tier: "HITL"

      # ── LEARNING PHASE ──────────────────────────────
      learning_phase:
        check: "every_monitoring_cycle"
        description: "Verificar status de learning phase a cada ciclo"
        action: |
          SE status = "active":
            - Bloquear alteracoes de budget > 20%, targeting, criativo
            - Incluir nota no pulse-report: "Campanha em learning phase"
            - Ref: config/safety-rules.yaml > learning_phase
          SE status = "reset":
            - Alertar: "Learning phase reiniciado (instabilidade detectada)"
            - Incrementar contador de resets no campaign-state.yaml
```

### 2. Monitoring Schedule

Schedule adaptativo baseado na idade e estabilidade da campanha. A frequencia diminui conforme a campanha estabiliza.

```yaml
schedule_tiers:

  first_72h:
    label: "Primeiras 72 horas"
    interval: "every 4 hours"
    cycles_per_day: 6
    description: |
      Monitoramento intensivo nos primeiros 3 dias apos ativacao.
      Campanha esta em fase critica de learning + validacao.
    transition_to: "standard"
    transition_condition: "72h desde ativacao E sem alertas criticos"

  standard:
    label: "Monitoramento padrao"
    interval: "every 24 hours"
    cycles_per_day: 1
    description: |
      Monitoramento diario para campanhas ativas em operacao normal.
      Coleta metricas, gera pulse-report, verifica thresholds.
    transition_to: "stable"
    transition_condition: |
      14 dias sem nenhum ALERT (apenas WARNs toleraveis) E
      CPA dentro de 1.2x target por 7 dias consecutivos

  stable:
    label: "Campanha estavel"
    interval: "every 48 hours"
    cycles_per_day: 0.5
    description: |
      Monitoramento reduzido para campanhas comprovadamente estaveis.
      Economia de quota API sem comprometer deteccao de anomalias.
    revert_to: "standard"
    revert_condition: |
      Qualquer ALERT disparado OU
      CPA > target * 1.5 em qualquer ciclo
```

**Regra de seguranca para quota API:** A cadencia de monitoramento deve respeitar os limites de `data/rate-limits.yaml`. Em tier Development (60 points/hora), NAO rodar monitoring loop automatico.

### 3. Monitoring Cycle Execution

Cada ciclo de monitoramento segue este fluxo:

```
┌─────────────────────────────────────────────────────────┐
│              MONITORING CYCLE EXECUTION                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐        │
│   │ COLLECT  │───▶│ EVALUATE │───▶│ UPDATE   │        │
│   │ METRICS  │    │THRESHOLDS│    │ STATE    │        │
│   │ (API)    │    │          │    │          │        │
│   └──────────┘    └──────────┘    └──────────┘        │
│                        │               │               │
│                   ┌────┴────┐          │               │
│                   │THRESHOLD│          ▼               │
│                   │BREACHED?│    ┌──────────┐         │
│                   └────┬────┘    │ campaign │         │
│                   YES  │ NO     │-state.yaml│         │
│                        │  │     └──────────┘         │
│                        ▼  │                           │
│                   ┌──────┐│          ┌──────────┐    │
│                   │ALERT ││          │ GENERATE │    │
│                   │OR    │└────────▶ │ PULSE    │    │
│                   │ WARN │           │ REPORT   │    │
│                   └──┬───┘           └──────────┘    │
│                      │                    │           │
│                 ┌────┴────┐               ▼           │
│                 │ WARN?   │         pulse-report.md   │
│                 │ ALERT?  │                           │
│                 └────┬────┘                           │
│            WARN:     │     ALERT:                     │
│            Log +     │     HITL action                │
│            Report    │     + escalate                 │
│                      │     to human                   │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### 4. Output Integration

#### campaign-state.yaml

Cada ciclo de monitoramento ATUALIZA o `campaign-state.yaml` da campanha correspondente.

**Referencia canonica:** `templates/campaign-state.yaml`

Campos atualizados por ciclo:

| Campo | Fonte | Frequencia |
|-------|-------|-----------|
| `current_metrics.*` | API (collect-campaign-metrics) | Todo ciclo |
| `rolling_7d.avg_cpa` | Calculo local | Diariamente |
| `rolling_7d.avg_roas` | Calculo local | Diariamente |
| `rolling_7d.trend` | Comparacao vs ciclo anterior | Diariamente |
| `rolling_30d.*` | Calculo local | Diariamente |
| `learning_phase.status` | API (campaign status) | Todo ciclo |
| `learning_phase.conversions_in_phase` | API (conversions count) | Todo ciclo |
| `memory.winning_patterns` | @performance-analyst insights | Quando identificado (max 5) |
| `memory.failed_patterns` | @performance-analyst insights | Quando identificado (max 5) |
| `memory.notes` | Observacoes contextuais | Quando relevante (max 10) |

#### pulse-report.md

Cada ciclo gera um pulse-report no formato de 5 linhas definido em `templates/pulse-report.md`.

**Formato (imutavel):**

```
# Pulse -- {campaign_name} -- {date}
Spend: R${spend} | CPA: R${cpa} ({trend} vs 7d avg) | ROAS: {roas}
Top Winner: {best_ad_name} (CTR {ctr}%)
Alert: {alert_or_none}
Action: {auto_action_taken_or_none} | Tier: {Auto/HITL/Human}
```

**Path de output:** `workspace/businesses/{slug}/ads/{platform}/{campaign_slug}/reports/daily/pulse-{date}.md`

---

## SE/ENTAO Rules

```yaml
rules:
  # ── CPA ────────────────────────────────────
  - condition: "SE CPA > target * 1.5"
    action: "WARN: log anomalia no pulse-report"
    severity: warning

  - condition: "SE CPA > target * 3"
    action: "ALERT: recomendar kill (HITL) + registrar no action-ledger"
    severity: critical

  # ── CTR ────────────────────────────────────
  - condition: "SE CTR cai > 20% vs media 7 dias"
    action: "WARN: dispatch para @creative-analyst"
    severity: warning

  - condition: "SE CTR cai > 50% vs media 7 dias"
    action: "ALERT: recomendar pausa (HITL) + analise de fadiga"
    severity: critical

  # ── BUDGET ─────────────────────────────────
  - condition: "SE daily spend > budget * 1.10"
    action: "WARN: incluir no pulse-report"
    severity: warning

  - condition: "SE daily spend > budget * 1.20"
    action: "ALERT: recomendar ajuste (HITL)"
    severity: critical

  # ── FREQUENCY ──────────────────────────────
  - condition: "SE frequency > 2.5"
    action: "WARN: dispatch @creative-analyst para creative refresh"
    severity: warning

  - condition: "SE frequency > 3.0"
    action: "ALERT: recomendar creative swap (HITL)"
    severity: critical

  # ── LEARNING PHASE ─────────────────────────
  - condition: "SE campanha em learning phase"
    action: "BLOCK alteracoes de budget > 20%, targeting, criativo"
    severity: high
    ref: "config/safety-rules.yaml > learning_phase"

  - condition: "SE learning phase reiniciado (reset)"
    action: "ALERT: notificar instabilidade + incrementar contador"
    severity: high

  # ── SCHEDULE ───────────────────────────────
  - condition: "SE campanha ativa ha < 72h"
    action: "Monitorar a cada 4h (first_72h tier)"
    severity: info

  - condition: "SE 14 dias sem ALERT E CPA estavel"
    action: "Transicionar para stable tier (48h interval)"
    severity: info

  - condition: "SE ALERT disparado em campanha stable"
    action: "Reverter para standard tier (24h interval)"
    severity: high
```

---

## Setup Process

### Step 1: Load Campaign Context

```yaml
load:
  - campaign-state.yaml      # Estado atual da campanha
  - campaign-briefing.yaml   # Target CPA, ROAS, budget definidos no briefing
  - rate-limits.yaml         # Tier da API para calcular cadencia maxima
```

### Step 2: Calculate Thresholds

```yaml
calculate:
  cpa_target: campaign-briefing.yaml > fase_2.cpa_meta_target
  daily_budget: campaign-briefing.yaml > fase_2.budget_diario

  derived:
    cpa_warn: cpa_target * 1.5
    cpa_alert: cpa_target * 3.0
    budget_warn: daily_budget * 1.10
    budget_alert: daily_budget * 1.20
    ctr_baseline: "coleta automatica apos 7 dias de dados"
```

### Step 3: Determine Schedule Tier

```yaml
determine_schedule:
  if: campaign_age < 72h
  then: first_72h (4h interval)

  elif: campaign_age >= 72h AND no_critical_alerts_14d
  then: stable (48h interval)

  else: standard (24h interval)
```

### Step 4: Save Configuration

```yaml
save:
  path: "workspace/businesses/{slug}/ads/{platform}/campaign-monitors.yaml"
  action: "append monitor entry for this campaign"
  validation: "confirm all required thresholds are set before saving"
```

### Step 5: Activate Monitoring

```yaml
activate:
  handoff_to: "campaign-monitor skill (automation)"
  message: "Monitor configurado para {campaign_name}. Schedule: {tier}. Thresholds salvos."
```

---

## Integration

| Sistema | Conexao |
|---------|---------|
| `templates/campaign-state.yaml` | Template de output -- formato do estado persistente |
| `templates/pulse-report.md` | Template de output -- formato do pulse diario |
| `config/safety-rules.yaml` | Learning phase protection, budget thresholds |
| `data/rate-limits.yaml` | Cadencia maxima de API calls por tier |
| `config/autonomy-tiers.yaml` | `configure-monitoring` (Auto), `execute-monitoring-action` (HITL) |
| `skills/automation/campaign-monitor` | Consome thresholds para execucao do loop |

---

## Usage Examples

### Configurar Monitoramento para Nova Campanha

```
User: *setup-monitoring launch-meta-cold-cbo
Agent: Ativando Monitoring Setup -- configuracao de thresholds e schedule.

Campanha: Launch Meta Ads Pro - Cold - CBO
Target CPA: R$45 (do briefing)
Budget diario: R$200

Thresholds configurados:
  CPA: WARN > R$67.50 | ALERT > R$135.00
  CTR: WARN > -20% vs 7d avg | ALERT > -50%
  Budget: WARN > R$220 | ALERT > R$240
  Frequency: WARN > 2.5 | ALERT > 3.0
  Learning Phase: check a cada ciclo

Schedule: first_72h (monitoramento a cada 4h)

Salvo em: workspace/businesses/aiox/ads/meta/campaign-monitors.yaml
Handoff: campaign-monitor loop ativado.
```

### Verificar Monitors Ativos

```
User: *list-monitors

Monitors Ativos:
| Campanha | Schedule | Ultimo Ciclo | Status |
|----------|----------|-------------|--------|
| launch-meta-cold-cbo | first_72h (4h) | 17/mar 14:00 | OK |
| promo-verao | standard (24h) | 17/mar 08:00 | WARN: frequency 2.7 |
| trafego-blog | stable (48h) | 16/mar 08:00 | OK |
```

---

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Esta documentacao |

---

## Dependencies

```yaml
requires:
  templates:
    - templates/campaign-state.yaml    # Output format
    - templates/pulse-report.md        # Report format

  data:
    - data/rate-limits.yaml            # API cadence limits
    - config/safety-rules.yaml         # Safety thresholds

  skills:
    - campaign-monitor                 # Consumes thresholds for execution loop

  agents:
    - '@performance-analyst'           # Primary operator
    - '@creative-analyst'              # Receives creative fatigue dispatches
    - '@ad-midas'                      # Escalation target
```

---

_Monitoring Setup Skill v1.0.0_
_AIOX Ads Squad_
