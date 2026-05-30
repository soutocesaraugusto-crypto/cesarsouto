# Funnel Selection Skill

**ID:** `funnel-selection`
**Category:** strategic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Seleção estratégica do tipo de funil ideal baseado em produto, ticket, margem e objetivo de negócio. Define a estrutura de tráfego antes de iniciar campanhas.

**Activation Command:** `*select-funnel`
**Announce:** "Ativando Funnel Selection com frameworks Jeremy Haynes."

---

## Expert Sources

| Expert        | Framework      | Weight | Focus                |
| ------------- | -------------- | ------ | -------------------- |
| Jeremy Haynes | Funnel Types   | 0.95   | Estruturas de funil  |
| Jeremy Haynes | Funil de R$1   | 0.93   | Low-ticket front-end |
| Jeremy Haynes | Aula no Zoom   | 0.92   | High-ticket funil    |
| Alex Hormozi  | Offer Stacking | 0.88   | Estrutura de oferta  |

---

## Funnel Types

### 1. Tráfego Direto

```yaml
name: 'Tráfego Direto'
flow: 'Ad → Página de Vendas → Checkout'
expert: 'Jeremy Haynes'

ideal_for:
  - 'Produtos validados (já vendem)'
  - 'Ticket R$97 - R$997'
  - 'Audiência quente/morna'
  - 'Ofertas simples'

not_ideal_for:
  - 'Produtos novos (não validados)'
  - 'High ticket (>R$2000)'
  - 'Público muito frio'

metrics_target:
  landing_to_sale: '1-5%'
  roas: '> 2.0'
  cpa: '< 30% do ticket'

structure:
  ad:
    hook: 'Benefício direto ou problema'
    cta: 'Saiba Mais / Comprar'

  landing_page:
    type: 'Página de vendas longa'
    elements:
      - 'Headline forte'
      - 'Vídeo de vendas (opcional)'
      - 'Benefícios'
      - 'Prova social'
      - 'FAQ'
      - 'Garantia'
      - 'CTA múltiplos'

  checkout:
    type: 'Checkout otimizado'
    upsells: 'Order bump + 1-2 upsells'
```

### 2. Funil de R$1 (Low-Ticket Frontend)

```yaml
name: 'Funil de R$1'
flow: 'Ad → Checkout Low-Ticket → Upsell 1 → Upsell 2 → Backend'
expert: 'Jeremy Haynes'

ideal_for:
  - 'Construir lista de compradores'
  - 'Produtos digitais'
  - 'Ticket baixo (R$1 - R$47)'
  - 'Margem alta no backend'

not_ideal_for:
  - 'Produtos físicos com custo'
  - 'Sem backend definido'
  - 'Urgência de caixa'

metrics_target:
  ad_to_purchase: '3-8%'
  upsell_1_rate: '20-40%'
  upsell_2_rate: '15-30%'
  aov_multiplier: '2-4x'

structure:
  ad:
    hook: 'Oferta irresistível por R$1-7'
    cta: 'Quero por R$1'

  checkout_page:
    product: 'Ebook / Mini-curso / Template'
    price: 'R$1 - R$47'
    urgency: 'Oferta limitada'

  upsell_1:
    type: 'Complemento lógico'
    price: 'R$47 - R$197'
    timing: 'Imediatamente após compra'

  upsell_2:
    type: 'Premium / Completo'
    price: 'R$197 - R$497'
    timing: 'Após upsell 1'

  backend:
    type: 'High ticket (mentoria, programa)'
    price: 'R$997 - R$12.000'
    timing: 'Email sequence + remarketing'

economics:
  example:
    frontend_price: 7
    upsell_1_rate: 0.30
    upsell_1_price: 97
    upsell_2_rate: 0.15
    upsell_2_price: 297
    aov: 7 + (97*0.30) + (297*0.15) = 80.75
    cpa_allowed: 40 # 50% de margem
```

### 3. Aula no Zoom (High-Ticket)

```yaml
name: 'Aula no Zoom'
flow: 'Ad → Registro → Aula ao Vivo → Aplicação → Call de Vendas → Fechamento'
expert: 'Jeremy Haynes'

ideal_for:
  - 'High ticket (>R$2000)'
  - 'Serviços e mentorias'
  - 'Venda consultiva'
  - 'Produtos complexos'

not_ideal_for:
  - 'Produtos simples'
  - 'Ticket baixo'
  - 'Sem equipe de vendas'

metrics_target:
  ad_to_registration: '20-40%'
  show_up_rate: '30-50%'
  application_rate: '10-20%'
  call_show_rate: '50-70%'
  close_rate: '20-40%'

structure:
  ad:
    hook: 'Valor educacional + resultado'
    cta: 'Reservar Vaga / Assistir Aula'

  registration_page:
    type: 'Landing page simples'
    elements:
      - 'O que vai aprender'
      - 'Para quem é'
      - 'Data/hora'
      - 'Bônus por participar'

  zoom_class:
    duration: '60-90 minutos'
    structure:
      - '0-10 min: Introdução + credibilidade'
      - '10-40 min: Conteúdo de valor'
      - '40-60 min: Pitch da oferta'
      - '60+ min: Q&A'

  application:
    type: 'Formulário de qualificação'
    questions:
      - 'Situação atual'
      - 'Objetivo'
      - 'Investimento disponível'
      - 'Timeline'

  sales_call:
    duration: '30-60 minutos'
    closer: 'Vendedor treinado'
    follow_up: 'WhatsApp + email'
```

### 4. Lead Magnet + Email Sequence

```yaml
name: 'Lead Capture Funnel'
flow: 'Ad → Lead Magnet → Email Sequence → Oferta'
expert: 'Classic funnel'

ideal_for:
  - 'Construir autoridade'
  - 'Produtos de consideração'
  - 'Público muito frio'
  - 'Lançamentos'

not_ideal_for:
  - 'Urgência de vendas'
  - 'Produtos impulso'

metrics_target:
  ad_to_lead: '20-40%'
  email_open_rate: '25-35%'
  email_to_sale: '2-5%'

structure:
  lead_magnet:
    type: 'Ebook / Checklist / Aula'
    value: 'Alto valor percebido'

  email_sequence:
    day_1: 'Entrega + boas-vindas'
    day_2: 'Valor + história'
    day_3: 'Case study'
    day_4: 'Objeções'
    day_5: 'Oferta soft'
    day_7: 'Oferta + urgência'
```

---

## Selection Decision Tree

```
Qual o ticket do produto?
    │
    ├── < R$100
    │   └── Funil de R$1 (frontend para backend)
    │
    ├── R$100 - R$2000
    │   │
    │   ├── Produto validado?
    │   │   ├── SIM → Tráfego Direto
    │   │   └── NÃO → Lead Magnet + Nurturing
    │   │
    │   └── Público quente?
    │       ├── SIM → Tráfego Direto
    │       └── NÃO → Lead Magnet
    │
    └── > R$2000
        │
        └── Aula no Zoom / VSL / Aplicação
```

---

## Output Format

```yaml
funnel_selection:
  product: 'Mentoria de Meta Ads'
  ticket: 5000
  analysis_date: '2026-02-01'

  inputs:
    product_type: 'mentoria'
    ticket_price: 5000
    product_validated: false
    backend_exists: true
    sales_team: true
    audience_temperature: 'cold'

  recommendation:
    funnel_type: 'Aula no Zoom'
    confidence: 0.92
    expert: 'Jeremy Haynes'

    rationale:
      - 'High ticket (R$5000) requer venda consultiva'
      - 'Produto não validado - precisa educar'
      - 'Audiência fria - precisa aquecimento'
      - 'Equipe de vendas disponível'

  structure:
    ad:
      format: 'Video 60s'
      hook: 'Como escalar para R$100k/mês com Meta Ads'
      cta: 'Reservar vaga na aula'

    registration:
      type: 'Landing page'
      conversion_target: '30%'

    live_class:
      duration: '75 min'
      platform: 'Zoom'
      frequency: '2x por semana'

    application:
      questions: 5
      qualification_score: true

    sales_call:
      duration: '45 min'
      script: 'SPIN Selling adaptado'

  metrics_targets:
    cpl: 'R$15-30'
    show_rate: '40%'
    application_rate: '15%'
    close_rate: '25%'
    cac: 'R$600-1200'
    ltv_cac: '> 4'

  alternatives:
    - funnel: 'DSL + Application'
      when: 'Sem capacidade de lives frequentes'

    - funnel: 'VSL + Call'
      when: 'Escala automatizada'
```

---

## Integration

### Triggered By

- Início de nova campanha
- `unit-economics` - após análise econômica
- User command - `*select-funnel`

### Dispatches To

- `campaign-structure` - para estruturar campanha
- `creative-brief` - para briefar criativos
- `dsl-structure` - se funil DSL

### Agent Assignment

- **Primary:** @media-strategist
- **Input:** @performance-analyst

---

## Usage Examples

```
*select-funnel "Mentoria High Ticket" --ticket 5000

*select-funnel --analyze-current

*select-funnel --compare-options
```

---

_Funnel Selection Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
