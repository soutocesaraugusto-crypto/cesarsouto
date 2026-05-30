# Scorecard Builder Skill

**ID:** `scorecard-builder`
**Category:** strategic
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Construcao de scorecards semanais/mensais para campanhas com metricas-chave, thresholds semaforo e analise de tendencia. Aplica o "Beach Vacation Question" de Ryan Deiss: se o operador sair de ferias, o scorecard sozinho deve ser suficiente para tomar decisoes. Inclui backtesting contra dados historicos para validar thresholds.

**Activation Command:** `*build-scorecard`
**Announce:** "Ativando Scorecard Builder com 3-Step Build e Beach Vacation Question."

---

## Expert Sources

| Expert      | Framework                | Weight | Focus                       |
| ----------- | ------------------------ | ------ | --------------------------- |
| Ryan Deiss  | 3-Step Scorecard Build   | 0.92   | Construcao de scorecards    |
| Ryan Deiss  | Beach Vacation Question  | 0.85   | Filtro de independencia     |
| Ryan Deiss  | Backtesting Methodology  | 0.88   | Validacao historica          |
| Ryan Deiss  | Traffic Light Leadership | 0.85   | Codificacao semaforo        |

---

## Scorecard Framework

### Beach Vacation Question Filter

```
PERGUNTA CENTRAL:
"Se o operador sair de ferias por 2 semanas,
 alguem consegue tomar decisoes APENAS olhando este scorecard?"

    +-- SIM --> Scorecard aprovado
    |
    +-- NAO --> O que falta?
            |
            +-- Metrica ambigua? -------> Renomear com contexto
            +-- Threshold nao claro? ---> Definir green/yellow/red
            +-- Metrica demais (>5)? ---> Filtrar por impacto
            +-- Sem tendencia? ---------> Adicionar trend arrows
            +-- Sem acao vinculada? ----> Vincular acao por cor
```

### Traffic Light Thresholds

```
GREEN  (on-target):     Metrica dentro ou acima do target
                        Acao: manter, considerar scale

YELLOW (attention):     Metrica 10-30% fora do target
                        Acao: monitorar 48h, preparar plano B

RED    (action needed): Metrica >30% fora do target
                        Acao: intervencao imediata, trigger metric-diagnosis
```

### Campaign Type Templates

```
ECOMMERCE:          ROAS | CPA | AOV | CVR | Frequency
LEAD GEN:           CPL | Lead Quality | CVR | Cost/Qualified Lead | Volume
WEBINAR/LAUNCH:     CPR (Reg) | Show-up Rate | CVR | CPA Final | ROAS
AWARENESS:          CPM | Reach | Frequency | Brand Lift | Engagement Rate
```

---

## Build Process

### Step 1: Identify Dashboard Categories

```yaml
category_detection:
  input: campaign_type
  mapping:
    ecommerce:
      primary: [roas, cpa, aov]
      secondary: [cvr, frequency, ctr]
    lead_gen:
      primary: [cpl, lead_quality_score, cvr]
      secondary: [cost_per_qualified, volume, ctr]
    webinar:
      primary: [cpr, show_up_rate, cpa_final]
      secondary: [cvr, roas, registrations]
    awareness:
      primary: [cpm, reach, frequency]
      secondary: [engagement_rate, brand_lift, video_views]
```

### Step 2: Brainstorm Metrics (Beach Vacation Filter)

```yaml
metric_selection:
  max_per_campaign: 5
  filter: "Beach Vacation Question"
  criteria:
    - actionable: "Alguem pode tomar uma decisao baseada neste numero?"
    - measurable: "Este numero esta disponivel em tempo real?"
    - unambiguous: "Qualquer pessoa entende o que este numero significa?"
    - threshold_clear: "Existe um ponto claro de green/yellow/red?"
  rejection_reasons:
    - vanity_metric: "Impressoes sem contexto de conversao"
    - redundant: "CPC quando ja tem CTR + CPM"
    - unavailable: "Dados nao acessiveis automaticamente"
```

### Step 3: Set Traffic Light Thresholds

```yaml
threshold_definition:
  method: "historical_baseline + business_target"
  example:
    cpa:
      green: "<= R$25 (target)"
      yellow: "R$25.01 - R$32.50 (ate 30% acima)"
      red: "> R$32.50 (mais de 30% acima)"
    roas:
      green: ">= 2.5x (target)"
      yellow: "2.0x - 2.49x (10-20% abaixo)"
      red: "< 2.0x (mais de 20% abaixo)"
    ctr:
      green: ">= 1.5%"
      yellow: "1.0% - 1.49%"
      red: "< 1.0%"
```

### Step 4: Backtest Against Historical Data

```yaml
backtesting:
  period: "ultimos 30 dias"
  method:
    - apply_proposed_thresholds_to_historical_data
    - count_false_positives: "dias que seriam RED mas performance era ok"
    - count_false_negatives: "dias que seriam GREEN mas performance era ruim"
    - adjust_thresholds_if_error_rate: "> 15%"
  validation:
    acceptable_error_rate: "<= 15%"
    if_above: "Ajustar thresholds e re-testar"
    max_iterations: 3
```

### Step 5: Generate Scorecard with Trends

```yaml
trend_analysis:
  period_comparison: "semana atual vs semana anterior"
  trend_symbols:
    ascending: "^"
    descending: "v"
    stable: "->"
    insufficient_data: "?"
  escalation:
    three_weeks_descending: "trigger metric-diagnosis"
    three_metrics_red: "escalar para @ad-midas"
```

---

## SE/ENTAO Rules

```yaml
rules:
  - se: "campanha ativa > 7 dias SEM scorecard"
    entao: "gerar scorecard automatico com metricas default do tipo de campanha"
    severity: high

  - se: "3+ metricas em vermelho"
    entao: "escalar para @ad-midas com resumo de situacao"
    severity: critical

  - se: "tendencia descendente 3 semanas consecutivas"
    entao: "trigger metric-diagnosis automatico"
    severity: high

  - se: "backtest mostra decisao errada (error rate > 15%)"
    entao: "documentar lesson learned, ajustar thresholds"
    severity: medium

  - se: "metrica proposta nao tem dados historicos"
    entao: "substituir por proxy ou remover do scorecard"
    severity: medium
```

---

## Output Format

```yaml
scorecard:
  campaign: "FB_CONV_COLD-LOOKALIKE_VID01"
  type: "ecommerce"
  period: "2026-03-09 a 2026-03-15"
  generated_at: "2026-03-16T08:00:00Z"
  beach_vacation_approved: true

  metrics:
    - metric: "ROAS"
      value: 2.8
      target: 2.5
      status: "green"
      trend: "ascending"
      trend_weeks: 2
      action: "Manter. Considerar scale se estavel por mais 1 semana."

    - metric: "CPA"
      value: 28.50
      target: 25.00
      status: "yellow"
      trend: "ascending"
      trend_weeks: 1
      action: "Monitorar 48h. Se subir mais, revisar audiencia."

    - metric: "CVR"
      value: 3.1
      target: 3.0
      status: "green"
      trend: "stable"
      trend_weeks: 3
      action: "Estavel. Nenhuma acao necessaria."

    - metric: "AOV"
      value: 147.00
      target: 150.00
      status: "green"
      trend: "stable"
      trend_weeks: 4
      action: "Dentro do range. Testar upsell para aumentar."

    - metric: "Frequency"
      value: 2.8
      target: 3.0
      status: "green"
      trend: "ascending"
      trend_weeks: 2
      action: "Aproximando do limite. Preparar refresh de criativo."

  backtesting:
    period_tested: "ultimos 30 dias"
    false_positives: 2
    false_negatives: 1
    error_rate: "10%"
    validation: "APPROVED (< 15%)"

  summary:
    green: 4
    yellow: 1
    red: 0
    overall: "Campaign saudavel. CPA em atencao."
    escalation: false

  next_review: "2026-03-23T08:00:00Z"
```

---

## Integration

### Dispatches To

- `metric-diagnosis` - quando metricas em vermelho ou tendencia descendente 3+ semanas
- `@ad-midas` - escalacao quando 3+ metricas em vermelho

### Receives From

- `campaign-monitor` - trigger automatico semanal
- User command - `*build-scorecard`

### Agent Assignment

- **Primary:** @fiscal (Sentinel)
- **Reports to:** @ad-midas

---

## Usage Examples

### Command Line

```
*build-scorecard campaign_456

*build-scorecard --type ecommerce --period weekly

*build-scorecard --backtest --period 30d --campaign FB_CONV_COLD

*build-scorecard --all-active --compare-previous
```

### Sample Output

```
SCORECARD - FB_CONV_COLD-LOOKALIKE_VID01
Periodo: 2026-03-09 a 2026-03-15 | Tipo: ecommerce
Beach Vacation Approved: SIM

+-----+-----------+---------+--------+----------+-------+
|  #  | Metrica   | Valor   | Target | Status   | Trend |
+-----+-----------+---------+--------+----------+-------+
|  1  | ROAS      | 2.8x    | 2.5x   | GREEN    |   ^   |
|  2  | CPA       | R$28.50 | R$25   | YELLOW   |   ^   |
|  3  | CVR       | 3.1%    | 3.0%   | GREEN    |  ->   |
|  4  | AOV       | R$147   | R$150  | GREEN    |  ->   |
|  5  | Frequency | 2.8     | 3.0    | GREEN    |   ^   |
+-----+-----------+---------+--------+----------+-------+

Backtest: 30 dias | Error rate: 10% | APPROVED

RESUMO: 4 GREEN | 1 YELLOW | 0 RED
Status geral: Campanha saudavel. CPA em atencao.
Proximo review: 2026-03-23
```

---

_Scorecard Builder Skill v1.0.0_
_AIOX Ads Squad - AIOS Synkra_
