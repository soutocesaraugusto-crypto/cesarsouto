# Google Campaign Architect Skill

**ID:** `google-campaign-architect`
**Category:** strategic
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Arquiteta campanhas Google Ads completas: Performance Max, Search, Display e YouTube. Define estrutura de PMax com asset groups otimizados, implementa segmentacao por tipo de campanha e aplica targeting high-ticket.

**Activation Command:** `*google-campaign`
**Announce:** "Ativando Google Campaign Architect com PMax Architecture e 5 Categories Strategy."

---

## Expert Sources

| Expert        | Framework                      | Weight | Focus                          |
| ------------- | ------------------------------ | ------ | ------------------------------ |
| Kasim Aslam   | PMax Architecture              | 0.95   | Performance Max setup          |
| Kasim Aslam   | Search/Display Segmentation    | 0.90   | Separacao de campanhas         |
| Jeremy Haynes | 5 Categories for Rich People   | 0.88   | Segmentacao high-ticket        |

---

## Campaign Architecture Framework

### Decision Flow

```
Qual o objetivo?
    |
    +-- Ecommerce com feed de produtos
    |   +-- PMax (asset groups por categoria) + Search Brand Protection
    |
    +-- Lead Gen / High-Ticket
    |   +-- Search (intent keywords) + Display Remarketing
    |   +-- SE ticket > R$2000 -> "5 Categories" targeting
    |
    +-- Brand Awareness
    |   +-- Display + YouTube (video campaigns)
    |
    +-- Budget < R$3000/mes
        +-- Search Only (nao PMax)
```

### SE/ENTAO Rules

```
SE ticket > R$2000
  ENTAO usar segmentacao "5 Categories for Rich People"
  (Jeremy Haynes: Business Owners, Investors, Doctors/Lawyers, Tech Executives, Luxury Consumers)

SE ecommerce com produto fisico
  ENTAO PMax com Merchant Center feed + Search brand protection
  RAZAO: PMax precisa de feed para funcionar em Shopping/Display/Discovery

SE lead gen (servico, consultoria, mentoria)
  ENTAO Search com intent keywords + Display remarketing
  RAZAO: Search captura demanda existente, Display retargeta visitantes

SE budget < R$3000/mes
  ENTAO foco em Search only (nao PMax)
  RAZAO: PMax precisa de volume minimo (~R$100/dia) para otimizar

SE competitor keywords detectados no mercado
  ENTAO criar campanha separada de competitor
  RAZAO: Isolar CPC alto de competitors do Search principal
```

---

## Campaign Types

### 1. Performance Max (PMax)

```yaml
name: 'Performance Max Structure'
use_case: 'Ecommerce com feed, multi-channel reach'
expert: 'Kasim Aslam'

structure:
  campaign:
    name: 'GADS_PMAX_{product_category}_{YYYYMMDD}'
    budget: 'Min R$100/dia (recomendado R$200+)'
    bidding: 'Maximize Conversions (com Target CPA apos 30 conversoes)'
    conversion_goals: ['Purchase', 'Lead']

  asset_groups:
    - name: 'AG1 - {Categoria Principal}'
      signals:
        audience_signals:
          - 'Custom Segments (search terms)'
          - 'Your Data (website visitors, customer list)'
          - 'In-Market audiences'
        demographics:
          - 'Age: product-specific'
          - 'Income: top 30% (se high-ticket)'
      listing_groups: 'Filtrar por categoria do feed'
      assets:
        headlines: 15  # maximo
        long_headlines: 5
        descriptions: 5
        images: 20  # maximo
        videos: 5
        logos: 5

    - name: 'AG2 - {Categoria Secundaria}'
      signals:
        audience_signals:
          - 'Different custom segment'
          - 'Different in-market'
      listing_groups: 'Filtrar por segunda categoria'

rules:
  - 'Cada asset group = 1 tema/categoria de produto'
  - 'NUNCA misturar categorias no mesmo asset group'
  - 'Audience signals sao SINAIS, nao restricoes (PMax decide)'
  - 'Rodar 2-4 semanas antes de avaliar (learning period longo)'
  - 'Excluir brand keywords do PMax (proteger com Search separado)'
```

### 2. Search Campaigns

```yaml
name: 'Search Campaign Structure'
use_case: 'Capturar demanda existente, intent keywords'
expert: 'Kasim Aslam'

campaigns:
  brand:
    name: 'GADS_SEARCH_BRAND_{business}_{YYYYMMDD}'
    purpose: 'Proteger nome da marca'
    budget: '10-15% do total'
    keywords:
      match_type: 'Exact + Phrase'
      examples: ['[marca]', '[marca produto]', '"comprar marca"']
    bidding: 'Maximize Clicks (brand e barato)'

  non_brand:
    name: 'GADS_SEARCH_NONBRAND_{category}_{YYYYMMDD}'
    purpose: 'Capturar intent generica'
    budget: '50-60% do total'
    keywords:
      match_type: 'Exact → Phrase → Broad (escalar nessa ordem)'
      structure: '1 tema por ad group, 5-15 keywords por grupo'
    bidding: 'Target CPA ou Maximize Conversions'

  competitor:
    name: 'GADS_SEARCH_COMP_{competitor}_{YYYYMMDD}'
    purpose: 'Aparecer em buscas de concorrentes'
    budget: '10-15% do total'
    keywords:
      match_type: 'Exact only'
      examples: ['[concorrente]', '[concorrente produto]']
    bidding: 'Manual CPC (controlar custo alto)'
    note: 'CPC geralmente 2-5x maior que non-brand'

rules:
  - 'SEMPRE separar brand vs non-brand vs competitor'
  - 'Ad groups tematicos: 5-15 keywords por grupo'
  - 'RSAs: 15 headlines, 4 descriptions, pinning estrategico'
  - 'Negative keywords desde o dia 1'
```

### 3. Display Campaigns

```yaml
name: 'Display Campaign Structure'
use_case: 'Remarketing, awareness visual'
expert: 'Kasim Aslam'

campaigns:
  remarketing:
    name: 'GADS_DISPLAY_RMK_{audience}_{YYYYMMDD}'
    audiences:
      - 'Website visitors (30d, 90d, 180d)'
      - 'Cart abandoners'
      - 'Video viewers'
      - 'Customer match list'
    budget: '15-20% do total'
    bidding: 'Target CPA'

  prospecting:
    name: 'GADS_DISPLAY_PROSP_{segment}_{YYYYMMDD}'
    audiences:
      - 'In-market segments'
      - 'Custom intent audiences'
      - 'Similar audiences (se disponivel)'
    budget: '10-15% do total'
    bidding: 'Maximize Conversions'

rules:
  - 'Remarketing SEMPRE em campanha separada de prospecting'
  - 'Excluir placements de baixa qualidade (apps, games)'
  - 'Frequency cap: 5-7 impressoes/semana'
```

### 4. 5 Categories for Rich People (High-Ticket)

```yaml
name: '5 Categories Strategy'
use_case: 'Produtos/servicos acima de R$2000'
expert: 'Jeremy Haynes'
trigger: 'ticket > R$2000'

categories:
  1_business_owners:
    targeting:
      - 'In-market: Business Services'
      - 'Custom intent: "scale my business", "business coaching"'
      - 'Income: Top 10%'
    messaging: 'ROI, escala, eficiencia'

  2_investors:
    targeting:
      - 'In-market: Financial Services, Real Estate'
      - 'Custom intent: "investment opportunities", "passive income"'
      - 'Income: Top 10%'
    messaging: 'Retorno, patrimonio, diversificacao'

  3_professionals:
    targeting:
      - 'In-market: Professional Services'
      - 'Custom intent: "executive coaching", "career advancement"'
      - 'Income: Top 20%'
    messaging: 'Status, expertise, diferenciacao'

  4_tech_executives:
    targeting:
      - 'In-market: Technology, SaaS'
      - 'Custom intent: "CTO training", "tech leadership"'
      - 'Income: Top 10%'
    messaging: 'Inovacao, lideranca, vantagem competitiva'

  5_luxury_consumers:
    targeting:
      - 'In-market: Luxury Goods, Travel'
      - 'Custom intent: "premium experience", "exclusive"'
      - 'Income: Top 5%'
    messaging: 'Exclusividade, experiencia, prestigio'

rules:
  - 'Cada categoria = campanha separada'
  - 'Nao misturar categorias no mesmo ad group'
  - 'Messaging adaptado por categoria'
  - 'Budget minimo R$150/dia por categoria'
```

---

## Naming Convention

### Standard Format

```
{platform}_{objective}_{audience}_{YYYYMMDD}

Platform Prefix: GADS
Objectives: PMAX, SEARCH, DISPLAY, VIDEO, SHOPPING
Audience: BRAND, NONBRAND, COMP, RMK, PROSP, LAL

Examples:
GADS_PMAX_ECOMM-ROUPAS_20260316
GADS_SEARCH_BRAND_MENTORIA_20260316
GADS_SEARCH_NONBRAND_COACHING_20260316
GADS_SEARCH_COMP_CONCORRENTE1_20260316
GADS_DISPLAY_RMK_CART-ABANDON_20260316
GADS_DISPLAY_PROSP_INMARKET_20260316
```

### Ad Group Naming

```
{Match Type} - {Theme}

Examples:
EXACT - mentoria online
PHRASE - coaching empresarial
BROAD - consultoria negocios
RMK - visitors 30d
```

### Ad Naming

```
{Format} - {Hook/Angle} - {Version}

Examples:
RSA - Resultado - V1
RSA - Problema - V2
DISP - Banner Depoimento - V1
```

---

## Process

### Step 1: Objective Definition

```yaml
inputs:
  business_type: 'ecommerce | lead_gen | saas | local'
  product_ticket: 0  # valor medio do produto/servico
  monthly_budget: 0
  conversion_goal: 'purchase | lead | signup | call'
  current_channels: []  # canais ja ativos
```

### Step 2: Platform Selection

```
Google Ads Campaign Type Selection
    |
    +-- Has product feed? -----> YES --> PMax
    |                            NO ---> Search + Display
    |
    +-- Budget > R$3000/mes? --> YES --> Multi-campaign
    |                            NO ---> Search only
    |
    +-- Ticket > R$2000? -----> YES --> 5 Categories targeting
    |                            NO ---> Standard targeting
    |
    +-- Has video assets? ----> YES --> Add YouTube campaigns
                                NO ---> Display for visual
```

### Step 3: Campaign Type Definition

```yaml
campaign_mix:
  pmax:
    when: 'ecommerce com feed'
    budget_share: '40-60%'
  search_brand:
    when: 'sempre (se marca conhecida)'
    budget_share: '10-15%'
  search_nonbrand:
    when: 'sempre'
    budget_share: '30-50%'
  search_competitor:
    when: 'competidores ativos no Google'
    budget_share: '10-15%'
  display_remarketing:
    when: 'website com trafego (>1000 visits/mes)'
    budget_share: '15-20%'
  display_prospecting:
    when: 'budget permite (>R$5000/mes)'
    budget_share: '10-15%'
```

### Step 4: Audience Architecture

```yaml
audience_layers:
  layer_1_remarketing:
    source: 'Website visitors, customer lists, video viewers'
    priority: 'HIGHEST'
    expected_cpa: 'Lowest'

  layer_2_intent:
    source: 'Search keywords, custom intent segments'
    priority: 'HIGH'
    expected_cpa: 'Medium'

  layer_3_inmarket:
    source: 'Google in-market audiences'
    priority: 'MEDIUM'
    expected_cpa: 'Medium-High'

  layer_4_broad:
    source: 'Demographics, broad match'
    priority: 'LOW (scale phase only)'
    expected_cpa: 'Highest'
```

### Step 5: Budget Distribution

```
BUDGET DISTRIBUTION FLOW

Total Budget: R$X/mes
    |
    +-- Search Brand: 10-15%
    |   (proteger marca, CPC baixo)
    |
    +-- Search Non-Brand: 30-50%
    |   (captura de demanda, core da estrategia)
    |
    +-- PMax (se ecommerce): 40-60%
    |   (multi-channel, alimentado pelo feed)
    |
    +-- Display RMK: 15-20%
    |   (reconversao, alto ROAS)
    |
    +-- Competitor: 10-15%
    |   (opcional, CPC alto)
    |
    +-- Testing Reserve: 10%
        (novos keywords, audiences, formatos)
```

### Step 6: Naming + Setup

```yaml
final_setup:
  naming: '{platform}_{objective}_{audience}_{YYYYMMDD}'
  tracking:
    - 'Google Ads conversion tracking configurado'
    - 'Google Analytics 4 linked'
    - 'Enhanced conversions ativo'
  quality_checks:
    - 'Negative keyword lists aplicadas'
    - 'Placement exclusions (apps, games)'
    - 'Location targeting correto'
    - 'Language targeting correto'
    - 'Ad schedule definido (se aplicavel)'
```

---

## Output Format

```yaml
google_campaign_architecture:
  business: 'Mentoria de Negocios'
  business_type: 'lead_gen'
  ticket: 5000
  monthly_budget: 10000
  analysis_date: '2026-03-16'

  strategy_applied:
    primary: 'Kasim Aslam - Search/Display Segmentation'
    secondary: 'Jeremy Haynes - 5 Categories for Rich People'
    trigger: 'ticket > R$2000 -> 5 Categories activated'

  campaigns:
    - name: 'GADS_SEARCH_BRAND_MENTORIA_20260316'
      type: 'search'
      objective: 'brand_protection'
      daily_budget: 30
      monthly_budget: 900
      bidding: 'Maximize Clicks'
      keywords:
        match_type: 'exact + phrase'
        count: 10
        examples: ['[mentoria nome]', '"mentoria nome"']

    - name: 'GADS_SEARCH_NONBRAND_COACHING_20260316'
      type: 'search'
      objective: 'lead_generation'
      daily_budget: 150
      monthly_budget: 4500
      bidding: 'Target CPA R$150'
      ad_groups:
        - name: 'EXACT - mentoria empresarial'
          keywords: 8
        - name: 'EXACT - coaching negocios'
          keywords: 6
        - name: 'PHRASE - consultoria empresas'
          keywords: 10

    - name: 'GADS_SEARCH_COMP_CONCORRENTE1_20260316'
      type: 'search'
      objective: 'competitor_conquest'
      daily_budget: 40
      monthly_budget: 1200
      bidding: 'Manual CPC'
      keywords:
        match_type: 'exact only'
        count: 5

    - name: 'GADS_DISPLAY_RMK_VISITORS_20260316'
      type: 'display'
      objective: 'remarketing'
      daily_budget: 50
      monthly_budget: 1500
      bidding: 'Target CPA R$100'
      audiences:
        - 'Website visitors 30d'
        - 'Lead form abandoners'
        - 'Video viewers 50%+'

    - name: 'GADS_SEARCH_5CAT_BIZOWNERS_20260316'
      type: 'search'
      objective: '5_categories_high_ticket'
      daily_budget: 60
      monthly_budget: 1800
      bidding: 'Target CPA R$200'
      category: 'Business Owners'
      messaging: 'ROI, escala, eficiencia'

  budget_summary:
    total_daily: 330
    total_monthly: 9900
    reserve: 100
    distribution:
      search_brand: '9%'
      search_nonbrand: '45%'
      search_competitor: '12%'
      display_remarketing: '15%'
      high_ticket_5cat: '18%'
      testing_reserve: '1%'

  naming_convention:
    campaign: '{platform}_{objective}_{audience}_{YYYYMMDD}'
    ad_group: '{match_type} - {theme}'
    ad: '{format} - {hook} - {version}'

  next_steps:
    - 'Configurar conversion tracking (Google Ads + GA4)'
    - 'Criar negative keyword lists'
    - 'Produzir RSAs: 15 headlines + 4 descriptions por ad group'
    - 'Setup Enhanced Conversions'
    - 'Lancar Search Brand + Non-Brand primeiro'
    - 'Adicionar Display RMK apos 7 dias de dados'

  expert_attribution:
    architecture: 'Kasim Aslam - PMax Architecture + Search Segmentation'
    high_ticket: 'Jeremy Haynes - 5 Categories for Rich People'
```

---

## Integration

### Triggered By

- User command - `*google-campaign`
- `campaign-structure` - quando platform=google
- `funnel-selection` - apos escolher funil Google

### Dispatches To

- `unit-economics` - pre-validacao de economia
- `ad-compliance-gate` - pre-publish compliance
- `tracking-audit` - para setup de tracking Google
- `google-search-optimizer` - apos lancamento para otimizacao

### Agent Assignment

- **Primary:** @kasim-aslam
- **Support:** @performance-analyst (metricas)
- **Escalation:** @ad-midas (decisoes estrategicas)

---

## Usage Examples

```
*google-campaign "Mentoria de Negocios" --type lead_gen --budget 10000 --ticket 5000

*google-campaign --type ecommerce --budget 15000 --has-feed

*google-campaign --type search-only --budget 2500
```

### Sample Output

```
GOOGLE CAMPAIGN ARCHITECT

+======================================================+
| BUSINESS: Mentoria de Negocios                        |
| TIPO: Lead Gen | TICKET: R$5.000 | BUDGET: R$10K/mes |
+======================================================+
|                                                       |
| ESTRATEGIA: Search Segmentation + 5 Categories       |
| EXPERT: Kasim Aslam + Jeremy Haynes                   |
|                                                       |
+---------- CAMPANHAS ARQUITETADAS ----------+          |
|                                            |          |
| 1. GADS_SEARCH_BRAND (R$30/dia)            |          |
|    10 keywords exact+phrase                |          |
|    Bidding: Maximize Clicks               |          |
|                                            |          |
| 2. GADS_SEARCH_NONBRAND (R$150/dia)        |          |
|    3 ad groups, 24 keywords               |          |
|    Bidding: Target CPA R$150              |          |
|                                            |          |
| 3. GADS_SEARCH_COMP (R$40/dia)             |          |
|    5 keywords exact only                  |          |
|    Bidding: Manual CPC                    |          |
|                                            |          |
| 4. GADS_DISPLAY_RMK (R$50/dia)             |          |
|    3 audiences remarketing                |          |
|    Bidding: Target CPA R$100              |          |
|                                            |          |
| 5. GADS_5CAT_BIZOWNERS (R$60/dia)          |          |
|    High-ticket: Business Owners           |          |
|    Bidding: Target CPA R$200              |          |
|                                            |          |
+--------------------------------------------+          |
|                                                       |
| BUDGET: R$330/dia = R$9.900/mes + R$100 reserva       |
| NAMING: GADS_{objective}_{audience}_{YYYYMMDD}        |
|                                                       |
| PROXIMO PASSO: Configurar conversion tracking         |
+======================================================+
```

---

_Google Campaign Architect Skill v1.0.0_
_AIOX Ads Squad - AIOS Synkra_
