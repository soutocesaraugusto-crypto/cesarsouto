# YouTube Campaign Launcher Skill

**ID:** `youtube-campaign-launcher`
**Category:** strategic
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Executa o protocolo completo de lancamento de YouTube Ads em 6 etapas. Implementa o Targeting Timeline Pyramid, define estrategia de bidding por fase e gera pre-launch checklist completo.

**Activation Command:** `*youtube-launch`
**Announce:** "Ativando YouTube Campaign Launcher com 6-Step Launch Protocol e Targeting Timeline Pyramid."

---

## Expert Sources

| Expert        | Framework                          | Weight | Focus                      |
| ------------- | ---------------------------------- | ------ | -------------------------- |
| Brian Moncada | YouTube Ads Launch Protocol        | 0.93   | Lancamento completo        |
| Brian Moncada | Targeting Timeline Pyramid         | 0.90   | Sequencia de targeting     |
| Brian Moncada | YouTube Targeting Priority Order   | 0.87   | Priorizacao de audiences   |

---

## 6-Step Launch Protocol

### Protocol Overview

```
YOUTUBE ADS 6-STEP LAUNCH PROTOCOL (Brian Moncada)

Phase 1          Phase 2          Phase 3
PROVE            VALIDATE         SCALE
$100-500/dia     $500-2K/dia      $2K-50K/dia
    |                |                |
    v                v                v
+----------+    +----------+    +----------+
| Remarketing|   |  Custom  |    |   Broad  |
| + Custom  |   | + InMarket|   | + Demo   |
| Intent    |   |          |    |          |
+----------+    +----------+    +----------+
| Target CPV|    |Target CPA|    |Max Conv  |
+----------+    +----------+    +----------+
| 10+ hooks |    | Winners  |    | Top 2-3  |
| test      |    | only     |    | creatives|
+----------+    +----------+    +----------+

REGRA: Nao pular fases. Provar ROI antes de escalar.
```

### Step 1: Start with Remarketing

```yaml
step_1:
  name: 'Start with Remarketing'
  purpose: 'Provar ROI com audiencia quente (mais facil de converter)'
  expert: 'Brian Moncada'

  audiences:
    tier_1_highest_intent:
      - 'Website visitors (ultimos 30 dias)'
      - 'Email list (customer match)'
      - 'YouTube subscribers'
    tier_2_engaged:
      - 'Video viewers (50%+ completion)'
      - 'Website visitors (31-90 dias)'
      - 'App users'
    tier_3_broad_retarget:
      - 'Website visitors (91-180 dias)'
      - 'Social engagers (curtidas, comentarios)'

  campaign_setup:
    name: 'YT_RMK_{business}_{YYYYMMDD}'
    budget: 'R$100-300/dia'
    bidding: 'Target CPV (pagar por view)'
    format: 'TrueView InStream (skippable)'
    frequency_cap: '3-5 impressoes/semana'

  success_criteria:
    view_rate: '> 20%'
    ctr: '> 1%'
    cpa: '< target CPA'
    timeframe: '7-14 dias para avaliar'

  rules:
    - 'Comecar com remarketing SEMPRE (menor risco)'
    - 'Nao escalar ate provar CPA < target'
    - 'Excluir converted users das audiences'
```

### Step 2: Prove ROI at Small Scale

```yaml
step_2:
  name: 'Prove ROI at Small Scale'
  purpose: 'Validar economics antes de investir pesado'
  expert: 'Brian Moncada'

  budget: '$100-500/dia'

  validation_criteria:
    must_have:
      - 'CPA < target (ou dentro de 20% do target)'
      - 'View Rate > 20%'
      - 'CTR > 0.5%'
    nice_to_have:
      - 'ROAS > 2x'
      - 'View Rate > 30%'

  minimum_data:
    impressions: 10000
    views: 2000
    clicks: 50
    conversions: 5
    timeframe: '7 dias minimo'

  decision:
    pass: 'Todos must_have atingidos -> avancar para Step 3'
    partial: 'CTR ok mas CPA alto -> otimizar creative antes de escalar'
    fail: 'View Rate < 15% ou CPA > 3x target -> voltar ao criativo'
```

### Step 3: Expand to Custom Audiences

```yaml
step_3:
  name: 'Expand to Custom Audiences'
  purpose: 'Ampliar reach mantendo relevancia'
  expert: 'Brian Moncada'

  audiences:
    custom_intent:
      description: 'Pessoas que buscaram keywords relacionados'
      setup: 'Adicionar 10-15 keywords de alta intent'
      examples:
        - 'mentoria empresarial'
        - 'como escalar meu negocio'
        - 'coaching para empresarios'
      budget: 'R$200-500/dia'

    custom_affinity:
      description: 'Pessoas com interesses alinhados'
      setup: 'URLs de sites/canais que o target frequenta'
      examples:
        - 'URLs de blogs do nicho'
        - 'URLs de canais YouTube concorrentes'
        - 'URLs de ferramentas que o target usa'
      budget: 'R$200-500/dia'

    in_market:
      description: 'Pessoas ativamente pesquisando solucoes'
      setup: 'Selecionar categorias Google In-Market'
      examples:
        - 'Business Services'
        - 'Marketing Services'
        - 'Education > Professional'
      budget: 'R$200-500/dia'

  campaign_setup:
    name: 'YT_PROSP_{audience_type}_{YYYYMMDD}'
    budget: 'R$500-2000/dia total'
    bidding: 'Target CPA (baseado no CPA provado no Step 2)'
    note: 'Cada audience type em ad group separado'
```

### Step 4: Test 10+ Hooks

```yaml
step_4:
  name: 'Test 10+ Hooks Per Script'
  purpose: 'Encontrar os hooks que mais retém e convertem'
  expert: 'Brian Moncada'

  testing_protocol:
    hooks_per_script: '10+ (minimo 5)'
    budget_per_hook: 'R$50-100/dia'
    test_duration: '24-48h por hook'
    body_script: 'CONSTANTE (mesmo para todos os hooks)'

  kill_criteria:
    view_rate_below: '15% apos 48h'
    ctr_below: '0.3% apos 48h'
    action: 'Pausar imediatamente'

  scale_criteria:
    view_rate_above: '25%'
    ctr_above: '1%'
    cpa_below: 'target CPA'
    action: 'Aumentar budget 20% a cada 48h'

  hook_rotation:
    strategy: 'Rodar 3-5 hooks winners simultaneamente'
    refresh_cycle: 'A cada 2-4 semanas (ou quando View Rate cair)'
    note: 'YouTube creative fatigue e mais lento que Meta'

  decision_matrix:
    winner: 'View Rate > 25% + CPA < target -> SCALE'
    potential: 'View Rate 20-25% + CPA ok -> KEEP + otimizar'
    loser: 'View Rate < 15% OU CPA > 2x target -> KILL'
```

### Step 5: Scale Winners to Demographics

```yaml
step_5:
  name: 'Scale Winners to Broad Demographics'
  purpose: 'Maximizar volume com creatives comprovados'
  expert: 'Brian Moncada'

  pre_requisites:
    - 'CPA validado nos Steps 2-4'
    - 'Pelo menos 2-3 hooks winners identificados'
    - '50+ conversoes totais na conta'

  audiences:
    demographics_only:
      age: 'Definir range relevante (ex: 25-54)'
      gender: 'All ou especifico'
      income: 'Top 30% (se high-ticket)'
      parental_status: 'Se relevante'
    topic_targeting:
      purpose: 'Broad mas com contexto'
      examples: ['Business', 'Entrepreneurship', 'Finance']
    placement_targeting:
      purpose: 'Canais especificos de alto desempenho'
      method: 'Identificar placements winners do Step 3-4'

  campaign_setup:
    name: 'YT_SCALE_{audience}_{YYYYMMDD}'
    budget: 'R$2.000-50.000/dia'
    bidding: 'Maximize Conversions (Google otimiza delivery)'
    note: 'Somente apos provar economics'

  scaling_rules:
    - 'Aumentar budget max 20% a cada 48h'
    - 'Monitorar CPA diariamente durante escala'
    - 'Se CPA subir > 30%, pausar aumento'
    - 'Manter 3+ creatives ativos (evitar fadiga)'
```

### Step 6: Maintain View Rate

```yaml
step_6:
  name: 'Maintain 20-30% View Rate'
  purpose: 'Saude continua das campanhas'
  expert: 'Brian Moncada'

  monitoring:
    frequency: 'Diario'
    primary_metric: 'View Rate'
    target: '20-30%'
    alert: 'View Rate < 20% por 3 dias consecutivos'

  refresh_triggers:
    - 'View Rate cai abaixo de 20%'
    - 'CPA aumenta > 20% vs baseline'
    - 'Frequency > 5x/semana'
    - 'CTR cai > 30% vs pico'

  refresh_actions:
    - 'Produzir novo batch de 5-10 hooks'
    - 'Testar novo formato (talking head vs B-roll)'
    - 'Atualizar proof section (novos cases)'
    - 'Mudar cenario/ambiente do video'
    - 'Testar novo presenter (se aplicavel)'

  creative_lifecycle:
    fresh: '0-2 semanas (performance crescente)'
    peak: '2-6 semanas (performance estavel)'
    fatigue: '6-12 semanas (performance declinante)'
    retired: '12+ semanas (pausar e renovar)'
```

---

## SE/ENTAO Rules

```
SE fase 1 (testes iniciais)
  ENTAO Custom Intent targeting + Target CPV bidding + R$100-500/dia
  RAZAO: Provar conceito com minimo investimento

SE fase 2 (validacao de economics)
  ENTAO In-Market audiences + Target CPA + R$500-2K/dia
  RAZAO: Escalar para audiences maiores com CPA controlado

SE fase 3 (escala agressiva)
  ENTAO Broad audiences + Maximize Conversions + R$2K-50K/dia
  RAZAO: Volume maximo com creatives comprovados

SE budget < R$100/dia
  ENTAO foco em Custom Intent only
  RAZAO: Budget pequeno precisa de alta relevancia para converter

SE View Rate < 20% apos 72h
  ENTAO creative saturado, produzir novo batch de hooks
  RAZAO: View Rate baixo = hook nao esta capturando atencao

SE CTR < 0.5% apos 72h
  ENTAO matar campanha (creative nao converte)
  RAZAO: CTR muito baixo indica desconexao total ad-audience

SE CPA > 2x meta apos 7 dias
  ENTAO matar campanha e reavaliar funil
  RAZAO: Economics inviaveis, nao resolver com otimizacao
```

---

## Targeting Timeline Pyramid

```
TARGETING TIMELINE PYRAMID (Brian Moncada)

                    +--------+
                   /  BROAD   \          Fase 3: ESCALA
                  / Demographics\        R$2K-50K/dia
                 / Age+Gender+Inc\       Maximize Conversions
                +------------------+
               /                    \
              /  IN-MARKET AUDIENCES  \  Fase 2: VALIDACAO
             /  Actively searching     \ R$500-2K/dia
            /   related solutions       \Target CPA
           +----------------------------+
          /                              \
         /   CUSTOM AUDIENCES             \  Fase 1: PROVA
        /    Custom Intent (keywords)      \ R$100-500/dia
       /     Custom Affinity (URLs/channels)\ Target CPV
      +--------------------------------------+
     /                                        \
    /          REMARKETING                      \  Sempre ativo
   /   Website visitors, email lists,            \ R$100-300/dia
  /    YouTube subscribers, video viewers          \ Target CPV
 +--------------------------------------------------+

PRIORIDADE (de cima para baixo = menor para maior prioridade)
EXECUCAO (de baixo para cima = ordem de lancamento)
```

### Targeting Priority Order

```yaml
targeting_priority:
  1_highest:
    name: 'Remarketing Existing'
    audience: 'Website visitors, email list, YT subscribers'
    expected_cpa: 'Lowest'
    budget_share: '20-30%'

  2_high:
    name: 'High-Intent Keywords'
    audience: 'Custom Intent segments (search keywords)'
    expected_cpa: 'Low-Medium'
    budget_share: '25-35%'

  3_medium:
    name: 'Video/Channel Targeting'
    audience: 'Viewers de canais especificos, Custom Affinity'
    expected_cpa: 'Medium'
    budget_share: '15-25%'

  4_low:
    name: 'Adjacent Keywords'
    audience: 'Keywords relacionados mas nao diretos'
    expected_cpa: 'Medium-High'
    budget_share: '10-15%'

  5_lowest:
    name: 'Broad Demographics'
    audience: 'Age + Gender + Income (sem behavior targeting)'
    expected_cpa: 'Highest'
    budget_share: '10-20%'
    prerequisite: 'Somente apos provar ROI nas fases anteriores'
```

---

## Bidding Strategy by Phase

```
BIDDING STRATEGY EVOLUTION

Fase 1: PROVA
+---------------------------+
| Target CPV (Cost Per View) |
| Pagar por view completado  |
| Budget: R$100-500/dia      |
| Meta: Validar engajamento  |
+---------------------------+
          |
          | CPA validado + 30+ conversoes
          v
Fase 2: VALIDACAO
+---------------------------+
| Target CPA                 |
| Pagar por conversao         |
| Budget: R$500-2K/dia       |
| Meta: Confirmar economics   |
+---------------------------+
          |
          | 50+ conversoes + CPA estavel
          v
Fase 3: ESCALA
+---------------------------+
| Maximize Conversions        |
| Google otimiza delivery     |
| Budget: R$2K-50K/dia       |
| Meta: Volume maximo         |
+---------------------------+
```

---

## YouTube-Specific Benchmarks

```yaml
benchmarks:
  view_rate:
    excellent: '> 30%'
    good: '20-30%'
    acceptable: '15-20%'
    poor: '< 15%'
    action_if_poor: 'Trocar hook/creative'

  ctr:
    excellent: '> 2%'
    good: '1-2%'
    acceptable: '0.5-1%'
    poor: '< 0.5%'
    action_if_poor: 'Matar campanha, reavaliar creative'

  cpc:
    us_market: '$3-5'
    br_market: 'R$1-3'
    note: 'CPC YouTube e mais caro que Display mas mais barato que Search'

  frequency:
    optimal: '3-5x/semana'
    max: '7x/semana'
    action_if_high: 'Expandir audience ou reduzir budget'

  cpv:
    us_market: '$0.05-0.15'
    br_market: 'R$0.03-0.10'
    note: 'Pago quando viewer assiste 30s ou interage'
```

---

## Pre-Launch Checklist

```yaml
pre_launch_checklist:
  tracking:
    - check: 'Google Ads conversion tracking configurado'
      severity: 'critical'
    - check: 'Google Analytics 4 linked'
      severity: 'high'
    - check: 'Enhanced Conversions ativo'
      severity: 'high'
    - check: 'YouTube channel linked ao Google Ads'
      severity: 'critical'

  creative:
    - check: 'Video uploaded ao YouTube (unlisted)'
      severity: 'critical'
    - check: 'Thumbnail customizado'
      severity: 'medium'
    - check: '3+ hook variants prontos'
      severity: 'high'
    - check: 'CTA claro no final do video'
      severity: 'high'

  targeting:
    - check: 'Remarketing audiences criadas (min 1000 users)'
      severity: 'critical'
    - check: 'Custom Intent segments configurados'
      severity: 'high'
    - check: 'Negative placements definidos (kids content, music videos)'
      severity: 'high'
    - check: 'Geographic targeting correto'
      severity: 'critical'

  landing_page:
    - check: 'LP alinhada com ad (Relevance Triangle)'
      severity: 'critical'
    - check: 'Mobile responsive'
      severity: 'critical'
    - check: 'Page speed < 3s'
      severity: 'high'
    - check: 'CTA above the fold'
      severity: 'high'

  budget:
    - check: 'Budget diario definido'
      severity: 'critical'
    - check: 'Bidding strategy configurada (Target CPV para fase 1)'
      severity: 'critical'
    - check: 'Frequency cap configurado (5x/semana)'
      severity: 'high'
    - check: 'Schedule definido (horario de pico do target)'
      severity: 'medium'
```

---

## Output Format

```yaml
youtube_campaign_launch:
  business: 'Mentoria Empresarial'
  launch_date: '2026-03-16'
  total_monthly_budget: 15000
  launch_phase: 'Phase 1 - Prove ROI'

  strategy_applied:
    protocol: 'Brian Moncada - 6-Step YouTube Ads Launch Protocol'
    targeting: 'Brian Moncada - Targeting Timeline Pyramid'
    bidding: 'Brian Moncada - Phase-Based Bidding Strategy'

  campaigns:
    phase_1_remarketing:
      name: 'YT_RMK_MENTORIA_20260316'
      objective: 'conversions'
      daily_budget: 200
      bidding: 'Target CPV R$0.08'
      format: 'TrueView InStream (skippable)'
      frequency_cap: '5/week'
      audiences:
        - type: 'website_visitors_30d'
          size: 5200
        - type: 'email_list'
          size: 3400
        - type: 'youtube_subscribers'
          size: 1800
      creatives:
        - 'Hook V1 (statistic) + Body A'
        - 'Hook V2 (contrarian) + Body A'
        - 'Hook V3 (story) + Body A'
        - 'Hook V4 (direct) + Body A'
      exclusions:
        - 'Converted users (ultimos 90 dias)'
        - 'Kids content placements'
        - 'Music video placements'

    phase_1_custom_intent:
      name: 'YT_CI_MENTORIA_20260316'
      objective: 'conversions'
      daily_budget: 300
      bidding: 'Target CPV R$0.10'
      format: 'TrueView InStream (skippable)'
      frequency_cap: '5/week'
      keywords:
        - 'mentoria empresarial'
        - 'como escalar meu negocio'
        - 'coaching para empresarios'
        - 'consultoria de negocios'
        - 'escalar faturamento'
        - 'mentoria de negocios online'
        - 'crescimento empresarial'
        - 'acelerar meu negocio'
        - 'estrategia de crescimento'
        - 'mentoria 1 a 1'
      creatives:
        - 'Same 4 hook variants as remarketing'

  timeline:
    week_1_2:
      phase: 'Phase 1 - Prove'
      budget: 'R$500/dia'
      focus: 'Remarketing + Custom Intent'
      goal: 'Validar CPA + View Rate'

    week_3_4:
      phase: 'Phase 2 - Validate (se Phase 1 OK)'
      budget: 'R$1000-2000/dia'
      focus: 'In-Market + Custom Affinity'
      goal: 'Confirmar economics em audiences maiores'

    week_5_plus:
      phase: 'Phase 3 - Scale (se Phase 2 OK)'
      budget: 'R$2000-5000/dia'
      focus: 'Demographics + Topics'
      goal: 'Volume maximo com creatives comprovados'

  kill_criteria:
    view_rate_below_20: 'Apos 72h -> trocar creative'
    ctr_below_05: 'Apos 72h -> matar campanha'
    cpa_above_2x: 'Apos 7 dias -> matar campanha'

  success_metrics:
    phase_1_target:
      view_rate: '> 20%'
      ctr: '> 1%'
      cpa: '< R$200'
      conversions: '15+'
    phase_2_target:
      view_rate: '> 20%'
      ctr: '> 0.8%'
      cpa: '< R$250'
      conversions: '50+'

  pre_launch_checklist:
    tracking: 'PASS - 4/4 checks OK'
    creative: 'PASS - 4 hooks prontos'
    targeting: 'PASS - RMK audiences > 1000'
    landing_page: 'PASS - Relevance Triangle alinhado'
    budget: 'PASS - Budget e bidding configurados'
    overall: 'READY TO LAUNCH'

  next_steps:
    - 'Lancar Phase 1 (Remarketing + Custom Intent)'
    - 'Monitorar View Rate e CPA diariamente'
    - 'Kill hooks com View Rate < 15% em 48h'
    - 'Apos 7-14 dias: avaliar para Phase 2'
    - 'Solicitar youtube-ad-scriptwriter para novo batch se necessario'

  expert_attribution:
    launch_protocol: 'Brian Moncada - 6-Step YouTube Ads Launch Protocol'
    targeting: 'Brian Moncada - Targeting Timeline Pyramid'
    benchmarks: 'Brian Moncada - YouTube Ads Benchmarks'
```

---

## Integration

### Triggered By

- User command - `*youtube-launch`
- `funnel-selection` - quando platform=youtube
- `campaign-structure` - quando youtube selected

### Dispatches To

- `youtube-ad-scriptwriter` - para producao de scripts/hooks
- `ad-compliance-gate` - validacao pre-publish
- `tracking-audit` - para validar YouTube tracking setup
- `campaign-monitor` - apos lancamento para monitoramento

### Agent Assignment

- **Primary:** @tom-breeze
- **Support:** @performance-analyst (metricas e benchmarks)
- **Creative:** @creative-analyst (producao de hooks)
- **Escalation:** @ad-midas (decisoes de budget >R$5K/dia)

---

## Usage Examples

```
*youtube-launch "Mentoria Empresarial" --budget 15000 --phase 1

*youtube-launch --phase 2 --from-phase-1 YT_RMK_MENTORIA_20260316

*youtube-launch --checklist-only

*youtube-launch "SaaS Product" --budget 50000 --phase 3
```

### Sample Output

```
YOUTUBE CAMPAIGN LAUNCHER

+======================================================+
| BUSINESS: Mentoria Empresarial                        |
| PHASE: 1 - Prove ROI | BUDGET: R$500/dia             |
+======================================================+
|                                                       |
| 6-STEP LAUNCH PROTOCOL                               |
|                                                       |
| [x] Step 1: Remarketing audiences criadas             |
| [x] Step 2: Budget R$100-500/dia (prove ROI)          |
| [ ] Step 3: Custom Audiences (apos validacao)         |
| [ ] Step 4: 10+ hooks em teste                        |
| [ ] Step 5: Scale to Demographics                     |
| [ ] Step 6: Maintain 20-30% View Rate                 |
|                                                       |
+---------- CAMPANHAS CONFIGURADAS ----------+          |
|                                            |          |
| 1. YT_RMK_MENTORIA (R$200/dia)             |          |
|    3 audiences: visitors+email+subs        |          |
|    4 hook variants                         |          |
|    Bidding: Target CPV R$0.08              |          |
|                                            |          |
| 2. YT_CI_MENTORIA (R$300/dia)              |          |
|    10 custom intent keywords               |          |
|    4 hook variants                         |          |
|    Bidding: Target CPV R$0.10              |          |
|                                            |          |
+--------------------------------------------+          |
|                                                       |
| PRE-LAUNCH CHECKLIST                                  |
| Tracking:     PASS                                    |
| Creative:     PASS (4 hooks)                          |
| Targeting:    PASS (audiences > 1K)                   |
| Landing Page: PASS (triangle OK)                      |
| Budget:       PASS                                    |
| STATUS:       READY TO LAUNCH                         |
|                                                       |
+-------------------------------------------------------+
| KILL CRITERIA                                         |
| View Rate < 20% apos 72h -> trocar creative           |
| CTR < 0.5% apos 72h -> matar campanha                 |
| CPA > 2x meta apos 7d -> matar campanha               |
+-------------------------------------------------------+
| EXPERT: Brian Moncada - YouTube Launch Protocol       |
+======================================================+
```

---

_YouTube Campaign Launcher Skill v1.0.0_
_AIOX Ads Squad - AIOS Synkra_
