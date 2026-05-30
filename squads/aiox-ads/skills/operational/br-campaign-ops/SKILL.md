# BR Campaign Ops Skill

**ID:** `br-campaign-ops`
**Category:** operational
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Operações de campanha adaptadas ao mercado brasileiro. Implementa as 4 Fases PAF (Know-Like-Trust-Scale), gera checklist diário de operações, aplica calendário sazonal brasileiro, cria SOPs operacionais e integra funil WhatsApp com adaptações para PIX e parcelamento.

**Activation Command:** `*br-ops`
**Announce:** "Ativando BR Campaign Ops com 4 Fases PAF e adaptação Brasil."

---

## Expert Sources

| Expert       | Framework               | Weight | Focus                          |
| ------------ | ----------------------- | ------ | ------------------------------ |
| Pedro Sobral | 4 Fases PAF (KLT)      | 0.92   | Funil perpétuo brasileiro      |
| Nick Theriot | 5-Phase BFCM System    | 0.88   | Campanhas sazonais             |
| Ryan Deiss   | 3D Playbook Process     | 0.85   | Criação de SOPs operacionais   |

---

## PAF Framework (4 Fases)

### Funil Perpétuo Brasileiro

```
┌──────────────────────────────────────────────────────────────┐
│                   4 FASES PAF (Pedro Sobral)                 │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  FASE 1: AQUECIMENTO (Know)              20-30% budget      │
│  ├── Objetivo: Alcance + Video Views                        │
│  ├── CPL benchmark: R$7-R$15                                │
│  ├── Formato: Vídeo 1min, carrossel educativo               │
│  └── Público: Frio, interesses, LAL amplo                   │
│                                                              │
│  FASE 2: ENGAJAMENTO (Like)              30-40% budget      │
│  ├── Objetivo: Engajamento + Leads                          │
│  ├── CPL benchmark: R$15-R$25                               │
│  ├── Formato: Vídeo 2-5min, depoimentos                    │
│  └── Público: Engajados, visitantes, leads                  │
│                                                              │
│  FASE 3: CONVERSAO (Trust)               30-50% budget      │
│  ├── Objetivo: Conversão + Vendas                           │
│  ├── ROAS warm: 9:1 | ROAS cold: 3:1                       │
│  ├── Formato: DSL, VSL, case studies                        │
│  └── Público: Quente, remarketing, compradores              │
│                                                              │
│  ESCALA: expand warm + replenish cold continuamente         │
│                                                              │
│  FLOW:                                                       │
│  [Aquecimento] ──> [Engajamento] ──> [Conversão] ──> ESCALA│
│       |                                                |     │
│       └──────── replenish cold audience ───────────────┘     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Phase-Specific Tactics

```yaml
fase_1_aquecimento:
  name: 'Aquecimento (Know)'
  budget_share: '20-30%'
  objective: 'Alcance / Video Views / Engajamento'
  NOT_objective: 'Conversão — NUNCA otimizar para conversão nesta fase'

  tactics:
    content:
      - 'Vídeo educativo curto (30-60s)'
      - 'Carrossel com dicas práticas'
      - 'Reels/Shorts com hooks fortes'
    audience:
      - 'Interesses amplos'
      - 'LAL 3-5% de compradores'
      - 'Broad com filtro demográfico'
    metrics:
      primary: 'CPM, Alcance, Video Views'
      benchmark_cpm: 'R$15-R$30'
      benchmark_video_view: 'R$0.02-R$0.05'

fase_2_engajamento:
  name: 'Engajamento (Like)'
  budget_share: '30-40%'
  objective: 'Engajamento / Leads / Mensagens'

  tactics:
    content:
      - 'Vídeo longo (2-5min) com storytelling'
      - 'Depoimentos e provas sociais'
      - 'Conteúdo de bastidores'
      - 'Lives gravadas'
    audience:
      - 'Video viewers 50%+ da Fase 1'
      - 'Engajados com página 14d'
      - 'Visitantes do site 30d'
    metrics:
      primary: 'CPL, Custo por Engajamento'
      benchmark_cpl: 'R$15-R$25'

fase_3_conversao:
  name: 'Conversão (Trust)'
  budget_share: '30-50%'
  objective: 'Conversão / Vendas / Remarketing'

  tactics:
    content:
      - 'DSL (Direct Sales Letter)'
      - 'VSL (Video Sales Letter)'
      - 'Case studies detalhados'
      - 'Ofertas com urgência/escassez'
    audience:
      - 'Leads da Fase 2'
      - 'Remarketing (ATC, IC, viewers)'
      - 'LAL 1% de compradores'
    metrics:
      primary: 'CPA, ROAS'
      benchmark_roas_warm: '9:1'
      benchmark_roas_cold: '3:1'
```

### SE/ENTAO Rules

```yaml
rules:
  - id: 'BR-001'
    se: 'Campanha em fase PAF "Aquecimento"'
    entao: 'Objetivo = engajamento/alcance, NUNCA conversão'
    expert: 'Pedro Sobral'

  - id: 'BR-002'
    se: 'Data próxima a Black Friday (30 dias antes)'
    entao: 'Ativar BFCM protocol (5 fases Nick Theriot)'
    expert: 'Nick Theriot'

  - id: 'BR-003'
    se: 'Operador novo (onboarding)'
    entao: 'Fornecer SOP completo + checklist diário'
    expert: 'Ryan Deiss'

  - id: 'BR-004'
    se: 'Métrica fora do benchmark BR'
    entao: 'Usar benchmarks-brasil para calibrar expectativa'
    expert: 'Pedro Sobral'

  - id: 'BR-005'
    se: 'WhatsApp habilitado no funil'
    entao: 'Capturar lead → enviar para WA nurture → medir conversão'
    expert: 'Pedro Sobral'

  - id: 'BR-006'
    se: 'PIX disponível como método de pagamento'
    entao: 'Destacar desconto PIX na copy (10-15% boost conversão)'
    expert: 'Pedro Sobral'

  - id: 'BR-007'
    se: 'Parcelamento > 6x'
    entao: 'Ajustar CPA target (ticket efetivo menor por parcela)'
    expert: 'Pedro Sobral'
```

---

## Daily Operations Checklist

### Morning Check (08:00)

```yaml
morning_08h:
  - task: 'Verificar gastos vs orçamento'
    alert: 'SE gasto > 110% do planejado → pausar campanhas excedentes'
    priority: 'CRITICAL'

  - task: 'Checar campanhas pausadas/rejeitadas'
    alert: 'SE campanha rejeitada → revisar compliance → resubmeter'
    priority: 'HIGH'

  - task: 'Verificar learning phase status'
    alert: 'SE learning limited > 7 dias → reestruturar adset'
    priority: 'MEDIUM'
```

### Analysis (10:00)

```yaml
analysis_10h:
  metrics_to_check:
    - 'CPA vs target (alert SE > 1.5x)'
    - 'ROAS vs target (alert SE < 1.5)'
    - 'CTR por ad (kill SE < 0.5%)'
    - 'CPM vs benchmark BR (alert SE > R$50)'
    - 'Frequency por adset (alert SE > 3)'

  actions:
    - 'Kill underperformers (CPA > 2x, CTR < 0.5%)'
    - 'Identificar winners para promoção'
    - 'Documentar anomalias'
```

### Midday Optimization (14:00)

```yaml
midday_14h:
  - task: 'Budget reallocation'
    action: 'Mover budget de underperformers para winners'
    limit: 'Máximo 20% de realocação por dia'

  - task: 'Creative health check'
    action: 'Verificar fadiga (CTR declining 3+ dias)'
    dispatch: 'creative-fatigue-detector se necessário'

  - task: 'Audience saturation check'
    action: 'Verificar frequency e overlap'
```

### EOD Report (17:00)

```yaml
eod_17h:
  report_contents:
    - 'Resumo do dia: spend, CPA, ROAS, leads, vendas'
    - 'Ações tomadas: kills, scales, reallocations'
    - 'Anomalias detectadas e diagnóstico'
    - 'Prioridades para amanhã'

  format: 'Bullet points — máximo 10 linhas'
  destination: 'Relatório diário + stakeholder update'
```

---

## Brazil-Specific Calendar

### Seasonal Calendar

```
┌──────────────────────────────────────────────────────────────┐
│               CALENDARIO SAZONAL BRASIL                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  JAN  Volta às Aulas                                        │
│       Ressaca financeira — CPA tende a subir                │
│                                                              │
│  MAR  Dia do Consumidor (15/03)                             │
│       Mini Black Friday — preparar 15 dias antes            │
│                                                              │
│  MAI  Dia das Mães                                          │
│       2a maior data — campanhas 30 dias antes               │
│                                                              │
│  JUN  Dia dos Namorados (12/06)                             │
│       Importante para presentes — 20 dias antes             │
│                                                              │
│  AGO  Dia dos Pais                                          │
│       Ticket médio menor que Mães — ajustar CPA             │
│                                                              │
│  SET  Semana do Brasil                                      │
│       Aquecimento para Black Friday                         │
│                                                              │
│  NOV  Black Friday + Cyber Monday                           │
│       MAIOR DATA — preparar 45 dias antes                   │
│       Ativar BFCM protocol (5 fases)                        │
│                                                              │
│  DEZ  Natal                                                 │
│       Última janela — urgência máxima                       │
│                                                              │
│  *** Carnaval (FEV/MAR): performance cai em muitos nichos  │
│  *** Eleições: CPM sobe por competição política             │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### BFCM Protocol (5 Fases - Nick Theriot)

```yaml
bfcm_protocol:
  expert: 'Nick Theriot'
  trigger: '45 dias antes da Black Friday'

  phases:
    phase_1_warmup:
      timing: '45-30 dias antes'
      objective: 'Audience building + awareness'
      budget: '20% do total BFCM'
      tactics: 'Conteúdo de valor, vídeos, engajamento'

    phase_2_pre_launch:
      timing: '30-14 dias antes'
      objective: 'Lista de espera + leads'
      budget: '25% do total BFCM'
      tactics: 'Captura, early access, countdown'

    phase_3_launch:
      timing: '7 dias antes até D-Day'
      objective: 'Conversões máximas'
      budget: '30% do total BFCM'
      tactics: 'Ofertas, urgência, remarketing pesado'

    phase_4_peak:
      timing: 'Black Friday + Cyber Monday'
      objective: 'All-out conversão'
      budget: '20% do total BFCM'
      tactics: 'Budget máximo, broad + retargeting'

    phase_5_extension:
      timing: '3-5 dias após'
      objective: 'Capturar atrasados'
      budget: '5% do total BFCM'
      tactics: 'Última chance, estoque limitado'
```

---

## WhatsApp Funnel Integration

### WA Funnel Structure

```
┌──────────────────────────────────────────────────────────────┐
│              WHATSAPP FUNNEL (Brasil)                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  META AD (Click-to-WA) → WA WELCOME → QUALIFICACAO          │
│                              |                               │
│                              v                               │
│                     ┌─── Qualificado? ───┐                  │
│                     │                     │                  │
│                    SIM                   NAO                 │
│                     │                     │                  │
│                     v                     v                  │
│               NURTURE (3-5 msgs)    TAG + NURTURE LONGO     │
│                     │                                        │
│                     v                                        │
│               OFERTA DIRETA                                  │
│                     │                                        │
│                     v                                        │
│               ┌── Comprou? ──┐                              │
│               │               │                              │
│              SIM             NAO                             │
│               │               │                              │
│               v               v                              │
│          ONBOARDING     FOLLOW-UP (3x)                      │
│                               │                              │
│                               v                              │
│                          REOFERTA (7 dias)                   │
│                                                              │
│  METRICAS WA:                                                │
│  • Taxa de resposta: >60% (benchmark BR)                    │
│  • Conversão WA→Venda: 5-15%                                │
│  • Tempo médio resposta: <5min                              │
│  • Mensagens até venda: 3-7                                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### PIX & Parcelamento Adaptation

```yaml
pix_adaptation:
  desconto_pix: '5-15% de desconto'
  conversion_boost: '10-15% aumento de conversão'
  copy_examples:
    - 'PIX: R$997 (desconto de R$200)'
    - 'PIX na hora = desconto exclusivo'
    - 'Pagou no PIX, comeca agora'

  rules:
    - 'Sempre mostrar preço PIX vs parcelado'
    - 'Destacar economia no PIX'
    - 'Urgência: PIX = acesso imediato'

parcelamento_adaptation:
  rules:
    - 'Ticket > R$200: sempre oferecer parcelamento'
    - 'Mostrar valor da parcela na copy (12x R$49,70)'
    - 'Ajustar CPA target: ticket efetivo = valor parcela mensal'

  copy_examples:
    - '12x de R$49,70 no cartão'
    - 'Cabe no seu bolso: R$49,70/mês'
    - 'Menos que um cafezinho por dia'

  cpa_adjustment:
    formula: 'CPA target = (ticket / parcelas) x ROAS target'
    example: 'Produto R$997, 12x, ROAS 3x → CPA target R$27,69'
```

---

## Operational SOPs

### SOP: Campaign Launch

```yaml
sop_launch:
  name: 'Lançar Campanha Nova'
  steps:
    1: 'Definir fase PAF (Aquecimento/Engajamento/Conversão)'
    2: 'Configurar naming convention: [FASE] - [Produto] - [Data]'
    3: 'Definir audience conforme fase'
    4: 'Configurar budget conforme fase (% allocation)'
    5: 'Upload criativos (mínimo 3 por adset)'
    6: 'Configurar tracking (Pixel + CAPI)'
    7: 'Review compliance (texto, imagem, LP)'
    8: 'Publicar e registrar no monitoring'

  checklist_pre_launch:
    - 'Pixel instalado e disparando'
    - 'CAPI configurado'
    - 'UTMs corretos'
    - 'LP responsiva e rápida (<3s)'
    - 'Copy revisada (compliance Meta)'
    - 'Budget aprovado'
```

### SOP: Pause Campaign

```yaml
sop_pause:
  name: 'Pausar Campanha'
  steps:
    1: 'Identificar motivo da pausa (kill rule, budget, estratégia)'
    2: 'Pausar no Ads Manager (nunca deletar)'
    3: 'Documentar motivo e métricas no momento da pausa'
    4: 'Atualizar relatório diário'
    5: 'Se kill rule → dispatch metric-diagnosis para root cause'

  never_do:
    - 'Deletar campanha (sempre pausar)'
    - 'Pausar sem documentar motivo'
    - 'Pausar durante learning phase ativa (aguardar 72h)'
```

### SOP: Creative Swap

```yaml
sop_creative_swap:
  name: 'Trocar Criativo em Campanha Ativa'
  steps:
    1: 'Identificar ad com fadiga (CTR declining 3+ dias)'
    2: 'Preparar novo criativo (aprovado em compliance)'
    3: 'Adicionar novo ad ao adset (NÃO substituir o antigo)'
    4: 'Monitorar por 48h ambos rodando'
    5: 'Após 48h: manter winner, pausar loser'

  rule: 'NUNCA editar ad existente — sempre adicionar novo'
```

---

## Output Format

```yaml
br_ops_report:
  account_id: '123456'
  analysis_date: '2026-02-15'
  operator: '@br-traffic-operator'

  paf_status:
    current_phase: 'Engajamento (Like)'
    phase_health: 'HEALTHY'
    metrics:
      cpl: 'R$18 (benchmark R$15-R$25)'
      engagement_rate: '4.2%'
      video_views_50pct: 12450
    budget_allocation:
      aquecimento: '25% — R$1.250/dia'
      engajamento: '35% — R$1.750/dia'
      conversao: '40% — R$2.000/dia'

  daily_checklist:
    morning_08h:
      gastos_vs_orcamento: 'OK (98%)'
      campanhas_pausadas: '0'
      campanhas_rejeitadas: '0'
      status: 'CLEAR'

    analysis_10h:
      cpa_vs_target: 'R$22 vs R$25 target — OK'
      roas: '3.2 (warm) / 1.8 (cold) — COLD BELOW'
      ctr_avg: '1.4% — OK'
      cpm_avg: 'R$28 — OK'
      actions_taken:
        - 'Pausado 2 ads com CTR < 0.5%'
        - 'Identificado 1 winner para promoção'

    midday_14h:
      budget_reallocation: 'Movido R$200 de cold para warm'
      creative_health: 'OK — 8 criativos ativos'

    eod_17h:
      summary: 'Dia estável. ROAS cold precisa melhorar.'
      spend_today: 'R$4.850'
      leads_today: 42
      vendas_today: 8
      priorities_tomorrow:
        - 'Testar 3 novos hooks no cold'
        - 'Avaliar promoção de winner para conversão'

  seasonal_alert:
    next_date: 'Dia do Consumidor (15/03)'
    days_until: 28
    preparation_status: 'NOT STARTED'
    action_needed: 'Iniciar campanha sazonal em 14 dias'

  whatsapp_metrics:
    enabled: true
    response_rate: '68%'
    wa_to_sale: '11%'
    avg_response_time: '3min'
    status: 'HEALTHY'

  pix_parcelamento:
    pix_share: '42% das vendas'
    avg_discount: '10%'
    parcelamento_avg: '8x'
    cpa_adjusted: 'R$22 (ajustado por parcela)'

  next_actions:
    - '1. Melhorar ROAS cold (testar novos hooks)'
    - '2. Preparar campanha Dia do Consumidor'
    - '3. Adicionar 3 criativos ao pipeline'

  expert_attribution:
    paf_framework: 'Pedro Sobral - 4 Fases PAF'
    seasonal: 'Nick Theriot - BFCM System (adaptado BR)'
    sops: 'Ryan Deiss - 3D Playbook Process'
```

---

## Integration

### Triggered By

- User command - `*br-ops`
- User command - `*daily-checklist`
- User command - `*bfcm-prep`
- Calendar triggers - datas sazonais brasileiras (30 dias antes)

### Dispatches To

- `campaign-monitor` - dados de monitoramento diário
- `metric-diagnosis` - quando métrica fora do benchmark BR
- `creative-brief` - criativos sazonais e novos batches

### Agent Assignment

- **Primary:** @br-traffic-operator
- **Reports to:** @ad-midas

---

## Usage Examples

### Command Line

```
*br-ops account_123

*daily-checklist

*br-ops --phase aquecimento --budget 5000

*bfcm-prep --days-until 45

*br-ops --whatsapp-funnel --product "Curso Ads"
```

### Sample Output

```
BR CAMPAIGN OPS - Account_123

+======================================================+
| FASE PAF: Engajamento (Like) | HEALTH: OK            |
| BUDGET: R$5.000/dia | 3 fases ativas                 |
+======================================================+
|                                                        |
| DAILY CHECKLIST (10:00 analysis):                      |
| CPA: R$22 vs R$25 target                    OK        |
| ROAS warm: 3.2                               OK        |
| ROAS cold: 1.8                               BELOW     |
| CTR: 1.4%                                    OK        |
| CPM: R$28                                    OK        |
|                                                        |
+======================================================+
| ACOES TOMADAS:                                         |
| - Pausados 2 ads (CTR < 0.5%)                         |
| - 1 winner identificado para promoção                  |
| - Budget reallocado: R$200 cold → warm                |
|                                                        |
+======================================================+
| WHATSAPP FUNNEL:                                       |
| Taxa resposta: 68% | WA→Venda: 11% | Resp: 3min     |
|                                                        |
+======================================================+
| ALERTA SAZONAL:                                        |
| Dia do Consumidor em 28 dias — preparar em 14 dias    |
|                                                        |
+======================================================+
| PIX: 42% das vendas | Parcelamento médio: 8x          |
| EXPERT: Pedro Sobral - 4 Fases PAF                    |
+======================================================+
```

---

_BR Campaign Ops Skill v1.0.0_
_Ads Squad - AIOS Synkra_
