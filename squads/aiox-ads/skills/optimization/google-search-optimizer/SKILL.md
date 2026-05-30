# Google Search Optimizer Skill

**ID:** `google-search-optimizer`
**Category:** optimization
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Analisa Search Terms Report para encontrar winners e desperdicio, implementa estrategia de negative keywords, otimiza Quality Score e monitora metricas competitivas. Aplica Golden Ratio de budget para Search campaigns.

**Activation Command:** `*google-optimize`
**Announce:** "Ativando Google Search Optimizer com Quality Score Optimization e Negative Keyword Strategy."

---

## Expert Sources

| Expert      | Framework                  | Weight | Focus                     |
| ----------- | -------------------------- | ------ | ------------------------- |
| Kasim Aslam | Quality Score Optimization | 0.92   | Otimizacao de QS          |
| Kasim Aslam | Negative Keyword Strategy  | 0.90   | Filtragem de desperdicio  |
| Kasim Aslam | Search Term Analysis       | 0.88   | Mineracao de termos       |

---

## Optimization Framework

### SE/ENTAO Rules

```
SE search term gera conversao a CPA < target
  ENTAO adicionar como exact match keyword
  RAZAO: Isolar winner para controle de bid e budget

SE search term gera cliques sem conversao (>20 cliques)
  ENTAO adicionar como negative keyword
  RAZAO: Eliminar desperdicio de budget em termos sem intent

SE Quality Score < 5
  ENTAO diagnosticar componentes (ad relevance vs LP vs expected CTR)
  RAZAO: QS baixo = CPC inflado, menos impressoes, pior posicao

SE impression share < 50% e CPA esta ok
  ENTAO aumentar bid ou budget
  RAZAO: Ha demanda nao capturada com CPA saudavel

SE competitor impression share > nosso
  ENTAO criar campanha separada de competitor
  RAZAO: Isolar competicao do Search principal
```

---

## Search Terms Analysis

### Classification Matrix

```
SEARCH TERM CLASSIFICATION

                  +-- Conversao?
                  |
          SIM ----+---- NAO
          |               |
     CPA < Target?   Cliques > 20?
     |         |      |         |
    SIM       NAO    SIM       NAO
     |         |      |         |
  WINNER    WATCH  NEGATIVE   MONITOR
  (Exact)  (Otim)  (Add neg)  (Esperar dados)
```

### Winner Actions

```yaml
winners:
  criteria:
    - 'Gerou conversao'
    - 'CPA <= target CPA'
    - 'Volume suficiente (3+ conversoes)'

  actions:
    immediate:
      - 'Adicionar como Exact Match keyword'
      - 'Criar ad group dedicado'
      - 'Escrever RSA especifico para o termo'

    scale:
      - 'Aumentar bid 10-20%'
      - 'Testar Phrase Match para variantes'
      - 'Monitorar impression share'

  naming: 'EXACT - {search_term_winner}'
```

### Waste Actions

```yaml
waste:
  criteria:
    - 'Zero conversoes'
    - 'Mais de 20 cliques'
    - 'OU CPA > 3x target'

  actions:
    - level: 'campaign'
      when: 'Termo irrelevante para todo o negocio'
      example: '"gratis", "free", "como fazer sozinho"'

    - level: 'ad_group'
      when: 'Termo irrelevante para aquele tema especifico'
      example: '"mentoria gratuita" no ad group de mentoria paga'

    - level: 'account'
      when: 'Termo universalmente irrelevante'
      example: '"emprego", "vaga", "salario"'

  negative_keyword_lists:
    universal:
      - 'gratis'
      - 'free'
      - 'como fazer'
      - 'tutorial'
      - 'emprego'
      - 'vaga'
      - 'salario'
      - 'pdf'
      - 'download'
    industry_specific: '(definir por nicho)'
```

---

## Quality Score Optimization

### QS Component Breakdown

```
QUALITY SCORE (1-10)
    |
    +-- Expected CTR (33% do peso)
    |   |
    |   +-- Historico de CTR do keyword
    |   +-- CTR relativo aos concorrentes
    |   +-- ACAO: Headlines com keyword + beneficio
    |
    +-- Ad Relevance (33% do peso)
    |   |
    |   +-- Keyword presente no ad copy?
    |   +-- Ad group tematico (poucos keywords)?
    |   +-- ACAO: RSA com keyword nas headlines (pin H1)
    |
    +-- Landing Page Experience (33% do peso)
        |
        +-- Keyword na LP (H1, body)?
        +-- Mobile-friendly?
        +-- Page speed (Core Web Vitals)?
        +-- Conteudo relevante e original?
        +-- ACAO: LP dedicada por ad group
```

### QS Diagnostic Flow

```
Quality Score < 5?
    |
    +-- Checar Expected CTR
    |   |
    |   Below Average --> Reescrever headlines com keyword + beneficio
    |   Average -------> OK, nao priorizar
    |   Above Average -> Excelente
    |
    +-- Checar Ad Relevance
    |   |
    |   Below Average --> Reestruturar ad groups (max 10-15 keywords)
    |   Average -------> Incluir keyword no headline 1 (pinned)
    |   Above Average -> Excelente
    |
    +-- Checar LP Experience
        |
        Below Average --> Audit: speed, mobile, conteudo, keyword match
        Average -------> Otimizar above-the-fold
        Above Average -> Excelente
```

### RSA Optimization

```yaml
rsa_strategy:
  headlines:
    total: 15  # maximo
    structure:
      pinned_h1: 'Keyword principal + beneficio'
      pinned_h2: 'Proposta unica de valor'
      dynamic: 13  # variantes para Google testar
    examples:
      h1_pin: 'Mentoria Empresarial | Resultados em 90 Dias'
      h2_pin: 'Metodo Validado por +500 Empresarios'
      dynamic:
        - 'Aumente Seu Faturamento 3x'
        - 'Consultoria 1:1 Personalizada'
        - 'Sem Risco - Garantia de 30 Dias'

  descriptions:
    total: 4  # maximo
    structure:
      d1_pin: 'Oferta principal + CTA'
      dynamic: 3
    examples:
      d1_pin: 'Agende sua sessao estrategica gratuita. Vagas limitadas esta semana.'
      dynamic:
        - 'Metodo usado por +500 empresarios para escalar de 6 para 7 digitos.'
        - 'Acesso direto ao mentor. Sem intermediarios. Resultados comprovados.'

  ad_strength:
    target: 'Good ou Excellent'
    minimum: 'Average (nao publicar Poor)'
```

---

## Golden Ratio Budget

```
GOLDEN RATIO BUDGET DISTRIBUTION (Kasim Aslam)

+--------------------------------------------------+
| TOTAL SEARCH BUDGET: R$X/dia                      |
+--------------------------------------------------+
|                                                    |
| 70% PROVEN KEYWORDS                               |
| +----------------------------------------------+  |
| | Keywords com historico de conversao           |  |
| | CPA dentro do target                         |  |
| | Exact match, ad groups otimizados            |  |
| +----------------------------------------------+  |
|                                                    |
| 20% TESTING KEYWORDS                              |
| +----------------------------------------------+  |
| | Novos keywords de Search Terms Report        |  |
| | Phrase match para descoberta                 |  |
| | Budget fixo por 5-7 dias antes de decisao    |  |
| +----------------------------------------------+  |
|                                                    |
| 10% EXPERIMENTAL                                  |
| +----------------------------------------------+  |
| | Broad match com Smart Bidding                |  |
| | Novos temas/nichos                           |  |
| | Aceita CPA mais alto (aprendizado)           |  |
| +----------------------------------------------+  |
|                                                    |
+--------------------------------------------------+
```

---

## Competitive Analysis

### Metrics to Monitor

```yaml
competitive_metrics:
  search_impression_share:
    metric: 'Impression Share'
    benchmark: '> 60% para brand, > 30% para non-brand'
    action_if_low: 'Aumentar bid ou budget'

  search_lost_is_budget:
    metric: 'Search Lost IS (Budget)'
    benchmark: '< 20%'
    action_if_high: 'Aumentar budget (ha demanda nao capturada)'

  search_lost_is_rank:
    metric: 'Search Lost IS (Rank)'
    benchmark: '< 30%'
    action_if_high: 'Melhorar QS ou aumentar bid'

  auction_insights:
    monitor:
      - 'Top competitors por impression share'
      - 'Overlap rate'
      - 'Position above rate'
    frequency: 'Semanal'
```

---

## Process

### Step 1: Pull Search Terms

```yaml
step_1:
  action: 'Exportar Search Terms Report'
  period: 'Ultimos 30 dias'
  data_needed:
    - 'Search term'
    - 'Impressoes'
    - 'Cliques'
    - 'CTR'
    - 'CPC medio'
    - 'Conversoes'
    - 'CPA'
    - 'ROAS (se ecommerce)'
  filter: 'Min 5 impressoes (remover noise)'
```

### Step 2: Classify Winners/Waste

```yaml
step_2:
  classification:
    winner:
      criteria: 'Conversao + CPA <= target'
      action: 'Promover a Exact Match'
      output: 'Lista de keywords para adicionar'

    waste:
      criteria: '>20 cliques + 0 conversoes'
      action: 'Adicionar como Negative'
      output: 'Lista de negatives por nivel'

    watch:
      criteria: 'Conversao mas CPA > target'
      action: 'Otimizar (bid, ad copy, LP)'
      output: 'Lista para otimizacao'

    monitor:
      criteria: '<20 cliques, sem conclusao'
      action: 'Esperar mais dados'
      output: 'Nenhuma acao'
```

### Step 3: Update Keywords

```yaml
step_3:
  actions:
    add_winners:
      - 'Criar exact match keyword'
      - 'Criar ad group dedicado (se volume justifica)'
      - 'Escrever RSA com keyword no H1'

    add_negatives:
      - 'Determinar nivel (campaign/ad_group/account)'
      - 'Adicionar com match type correto'
      - 'Documentar razao'

    adjust_bids:
      - 'Winners: bid +10-20%'
      - 'High CPA: bid -10-20%'
      - 'Low impression share + bom CPA: bid +20%'
```

### Step 4: Optimize Quality Score

```yaml
step_4:
  for_each_keyword_with_qs_below_5:
    diagnose:
      - 'Checar Expected CTR'
      - 'Checar Ad Relevance'
      - 'Checar LP Experience'

    fix_priority:
      1: 'Ad Relevance (mais rapido de corrigir)'
      2: 'Expected CTR (reescrever ads)'
      3: 'LP Experience (requer dev)'

    expected_impact:
      qs_5_to_7: 'CPC reduz ~20%'
      qs_7_to_10: 'CPC reduz ~30-50%'
```

### Step 5: Monitor Competitive

```yaml
step_5:
  weekly_check:
    - 'Auction Insights report'
    - 'Impression share trends'
    - 'New competitor entries'
    - 'Position changes'

  monthly_report:
    - 'Competitive landscape summary'
    - 'Market share evolution'
    - 'Budget recommendation adjustments'
```

---

## Output Format

```yaml
google_search_optimization:
  analysis_date: '2026-03-16'
  period: 'Ultimos 30 dias'
  account_id: 'XXX-XXX-XXXX'

  search_terms_analysis:
    total_terms_analyzed: 347
    winners_found: 23
    waste_identified: 89
    watch_list: 45
    monitoring: 190

  winners:
    - term: 'mentoria para empresarios'
      conversions: 7
      cpa: 120
      target_cpa: 150
      action: 'Add as Exact Match'
      new_ad_group: 'EXACT - mentoria empresarios'

    - term: 'coaching executivo online'
      conversions: 4
      cpa: 95
      target_cpa: 150
      action: 'Add as Exact Match'

  waste:
    - term: 'mentoria gratuita'
      clicks: 45
      conversions: 0
      spend: 180
      negative_level: 'account'
      reason: 'Intent incompativel (busca gratuito)'

    - term: 'como fazer coaching sozinho'
      clicks: 32
      conversions: 0
      spend: 128
      negative_level: 'campaign'
      reason: 'DIY intent, nao comprador'

  quality_score_audit:
    keywords_below_5: 12
    avg_quality_score: 6.2
    issues:
      - keyword: 'mentoria empresarial'
        qs: 4
        component_below: 'ad_relevance'
        fix: 'Incluir keyword no headline 1 do RSA'

      - keyword: 'coaching de negocios'
        qs: 3
        component_below: 'landing_page'
        fix: 'LP nao menciona "coaching de negocios" no H1'

  competitive_landscape:
    our_impression_share: 42
    top_competitor: 'Competitor A'
    competitor_impression_share: 58
    lost_is_budget: '18%'
    lost_is_rank: '25%'
    recommendation: 'Aumentar budget em 20% para capturar demanda perdida'

  budget_reallocation:
    current:
      proven: '55%'
      testing: '30%'
      experimental: '15%'
    recommended:
      proven: '70%'
      testing: '20%'
      experimental: '10%'
    rationale: 'Realocar de experimental para proven (winners validados)'

  impact_projection:
    current_cpa: 145
    projected_cpa: 118
    improvement: '-19%'
    current_conversions: 34
    projected_conversions: 41
    improvement_conv: '+21%'

  expert_attribution:
    search_terms: 'Kasim Aslam - Search Term Analysis'
    quality_score: 'Kasim Aslam - Quality Score Optimization'
    negatives: 'Kasim Aslam - Negative Keyword Strategy'
```

---

## Integration

### Triggered By

- `campaign-monitor` - quando platform=google
- User command - `*google-optimize`
- Scheduled - semanal (otimizacao de rotina)

### Dispatches To

- `metric-diagnosis` - analise cross-platform
- `budget-allocation` - realocacao baseada em performance
- `google-campaign-architect` - quando nova campanha necessaria

### Agent Assignment

- **Primary:** @kasim-aslam
- **Support:** @performance-analyst (dados e metricas)
- **Escalation:** @ad-midas (decisoes de budget >30%)

---

## Usage Examples

```
*google-optimize --account XXX-XXX-XXXX --period 30d

*google-optimize --focus quality-score

*google-optimize --focus search-terms --export csv

*google-optimize --competitive-analysis
```

### Sample Output

```
GOOGLE SEARCH OPTIMIZER

+======================================================+
| CONTA: XXX-XXX-XXXX | PERIODO: 30 dias               |
+======================================================+
|                                                       |
| SEARCH TERMS ANALYSIS                                 |
| 347 termos analisados                                 |
|                                                       |
| WINNERS: 23 termos                                    |
|   "mentoria para empresarios" (7 conv, CPA R$120)    |
|   "coaching executivo online" (4 conv, CPA R$95)     |
|   Acao: Adicionar como Exact Match                    |
|                                                       |
| DESPERDICIO: 89 termos                                |
|   "mentoria gratuita" (45 cliques, 0 conv, R$180)    |
|   "como fazer coaching sozinho" (32 cliques, R$128)  |
|   Acao: Negative Keywords adicionadas                 |
|                                                       |
+-------------------------------------------------------+
| QUALITY SCORE AUDIT                                   |
|                                                       |
| Media QS: 6.2 | Keywords QS<5: 12                     |
|                                                       |
| "mentoria empresarial" QS:4                           |
|   Problema: Ad Relevance                              |
|   Fix: Keyword no headline 1 do RSA                   |
|                                                       |
+-------------------------------------------------------+
| GOLDEN RATIO BUDGET                                   |
|                                                       |
| ATUAL        -->  RECOMENDADO                         |
| 55% proven        70% proven                          |
| 30% testing       20% testing                         |
| 15% experimental  10% experimental                    |
|                                                       |
+-------------------------------------------------------+
| IMPACTO PROJETADO                                     |
| CPA: R$145 --> R$118 (-19%)                           |
| Conversoes: 34 --> 41 (+21%)                          |
+-------------------------------------------------------+
| EXPERT: Kasim Aslam - Search Optimization Framework  |
+======================================================+
```

---

_Google Search Optimizer Skill v1.0.0_
_AIOX Ads Squad - AIOS Synkra_
