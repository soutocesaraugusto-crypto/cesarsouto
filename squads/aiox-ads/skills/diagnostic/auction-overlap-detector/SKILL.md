# Auction Overlap Detector Skill

**ID:** `auction-overlap-detector`
**Category:** diagnostic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Detecta sobreposicao de audiencia entre ad sets dentro da mesma campanha e entre campanhas diferentes. Quando o overlap excede 30%, a skill sinaliza auto-competicao e recomenda acoes corretivas: consolidacao, exclusoes mutuas ou diferenciacao de audiencia.

**Activation Command:** `*detect-overlap`
**Announce:** "Ativando Auction Overlap Detector. Analisando sobreposicao de audiencias entre ad sets."

---

## Expert Sources

| Expert | Framework | Weight | Focus |
|--------|-----------|--------|-------|
| Meta Official Docs | Audience Overlap Tool | 1.00 | Deteccao via API e Ads Manager |
| Meta Official Docs | Auction Deduplication | 1.00 | Mecanismo de supressao em leiloes |

---

## Knowledge Reference

- **Primary:** `data/knowledge/meta/auction_overlap.md`
- **Related:** `data/knowledge/meta/ad_auctions.md`, `data/knowledge/meta/learning_phase.md`

---

## Detection Framework

### Overlap Sources

```yaml
overlap_check_scope:
  intra_campaign:
    description: "Ad sets dentro da mesma campanha competindo entre si"
    priority: HIGH
    check: "Comparar definicoes de audiencia entre todos os ad sets ativos"

  cross_campaign:
    description: "Ad sets de campanhas diferentes competindo entre si"
    priority: MEDIUM
    check: "Comparar audiencias entre campanhas com mesmo objetivo ou audiencias similares"

  retargeting_vs_prospecting:
    description: "Audiencia de retargeting capturada tambem na prospecting"
    priority: HIGH
    check: "Verificar se Custom Audiences de retargeting estao excluidas de prospecting"
```

### Overlap Detection Methods

```yaml
detection_methods:
  api_based:
    tool: "Meta Audience Overlap Tool via MCP"
    accuracy: HIGH
    method: "Selecionar audiencias salvas e verificar % de sobreposicao"
    limitation: "Requer audiencias salvas (Saved Audiences)"

  definition_analysis:
    tool: "Comparacao programatica de definicoes de audiencia"
    accuracy: MEDIUM
    method: "Comparar targeting specs entre ad sets"
    indicators:
      - "Mesmos interesses com faixas demograficas sobrepostas"
      - "Lookalike audiences com percentuais diferentes (1% vs 3%)"
      - "Broad targeting + narrow targeting no mesmo universo"

  delivery_heuristic:
    tool: "Analise de metricas de entrega"
    accuracy: LOW-MEDIUM
    method: "Padroes de entrega que sugerem overlap"
    indicators:
      - "Frequencia similar entre ad sets com audiencias 'diferentes'"
      - "CPMs inflados sem mudanca de mercado"
      - "Um ad set com delivery inconsistente enquanto outro performa bem"
```

### Overlap Severity Scale

| Overlap % | Severidade | Flag | Acao |
|-----------|------------|------|------|
| 0-15% | Baixa | INFO | Monitorar, sem acao necessaria |
| 15-30% | Moderada | WARN | Acompanhar impacto em Learning Phase, considerar consolidacao futura |
| 30-50% | Alta | FLAG | Recomendar consolidacao ou exclusoes mutuas de audiencia |
| 50%+ | Critica | ALERT | Consolidacao imediata obrigatoria. Merge de ad sets ou exclusoes rigidas |

**Threshold de auto-competicao:** > 30% = FLAG de self-competition ativo.

---

## Analysis Process

### Step 1: Mapeamento de Audiencias

```yaml
data_collection:
  per_ad_set:
    - ad_set_id
    - ad_set_name
    - campaign_id
    - targeting_spec:
        - age_range
        - gender
        - locations
        - interests
        - behaviors
        - custom_audiences
        - lookalike_audiences
        - exclusions
    - audience_size_estimate
    - delivery_status
    - spend_7d
    - conversions_7d
```

### Step 2: Comparacao Par-a-Par

```
FOR EACH pair (ad_set_A, ad_set_B) in active_ad_sets:

    overlap_score = calculate_overlap(ad_set_A.targeting, ad_set_B.targeting)

    IF overlap_score > 30%:
        FLAG self_competition
        CALCULATE budget_waste_estimate
        GENERATE remediation_options

    IF overlap_score > 50%:
        ALERT immediate_action_required
```

### Step 3: Calculo de Impacto

```yaml
impact_analysis:
  budget_fragmentation:
    description: "Orcamento dividido entre ad sets que competem pela mesma audiencia"
    metric: "total_spend_on_overlapping_ad_sets / total_campaign_spend"

  learning_phase_impact:
    description: "Overlap fragmentando conversoes e mantendo ad sets em Learning"
    metric: "ad_sets_in_learning_limited_with_overlap > 30%"

  cpm_inflation:
    description: "CPM inflado por auto-competicao no leilao"
    metric: "compare CPM of overlapping ad sets vs non-overlapping benchmarks"
```

---

## Remediation Strategies

### Strategy 1: Consolidacao

```yaml
consolidation:
  when: "Overlap > 50% OU 2+ ad sets em Learning Limited por causa de overlap"
  action: "Merge ad sets sobrepostos em um unico ad set com targeting mais amplo"
  benefit: "Concentra dados para Learning Phase, reduz fragmentacao"
  risk: "Perda de granularidade de teste A/B"
  implementation:
    - "Pausar ad sets menores (menor volume)"
    - "Expandir targeting do ad set principal para cobrir ambos"
    - "Mover orcamento combinado para o ad set consolidado"
```

### Strategy 2: Exclusoes Mutuas

```yaml
mutual_exclusions:
  when: "Overlap 30-50% E ha razao estrategica para manter ad sets separados"
  action: "Aplicar Custom Audience exclusions para criar pools nao-sobrepostos"
  benefit: "Mantem segmentacao estrategica sem auto-competicao"
  examples:
    - "Excluir audiencia de retargeting dos ad sets de prospecting"
    - "Excluir Lookalike 1% do Lookalike 3% para criar faixa 1-3% limpa"
    - "Excluir compradores de audiencias de awareness"
  implementation:
    - "Criar Custom Audiences de exclusao"
    - "Aplicar exclusoes em cada ad set"
    - "Verificar que audience size nao caiu abaixo do minimo viavel"
```

### Strategy 3: Diferenciacao de Audiencia

```yaml
audience_differentiation:
  when: "Overlap 30-50% E as audiencias podem ser genuinamente diferenciadas"
  action: "Refinar targeting para criar segmentos distintos"
  benefit: "Mantem testes validos sem auto-competicao"
  examples:
    - "Separar por faixa etaria nao-sobreposta"
    - "Usar interest layering para criar nichos distintos"
    - "Dividir por geografia quando faz sentido"
  implementation:
    - "Redefinir targeting de cada ad set com criterios mutuamente exclusivos"
    - "Verificar novo overlap apos ajustes"
    - "Monitorar impacto em audience size e CPM"
```

### Strategy 4: Campaign Budget Optimization (CBO)

```yaml
cbo_migration:
  when: "Overlap moderado (15-30%) E ad sets estao em campanhas separadas"
  action: "Mover ad sets sobrepostos para uma unica campanha CBO"
  benefit: "Meta aloca orcamento dinamicamente, reduzindo impacto do overlap"
  limitation: "Nao elimina o overlap, apenas mitiga o impacto"
```

---

## Output Format

```yaml
overlap_report:
  account: '{account_name}'
  check_date: '{date}'
  total_active_ad_sets: {N}
  pairs_analyzed: {N}

  overlaps_detected:
    - pair:
        ad_set_a: '{name_a}'
        ad_set_b: '{name_b}'
        campaign_scope: 'intra | cross'
      overlap_percentage: {N}%
      severity: 'LOW | MODERATE | HIGH | CRITICAL'
      overlap_source: '{interests | lookalike | broad_vs_narrow | retargeting}'
      budget_at_risk: 'R${N}'
      learning_impact: 'YES | NO'
      recommendation:
        strategy: '{consolidation | mutual_exclusions | differentiation | cbo}'
        priority: {1-4}
        detail: '{specific action}'

  summary:
    total_overlaps: {N}
    critical: {N}
    high: {N}
    moderate: {N}
    low: {N}
    estimated_budget_waste: 'R${N}/month'
    overall_recommendation: '{specific top-priority action}'
```

---

## Integration

### Dispatches To

- `learning-phase-detector` -- verificar se overlap esta impactando saida da Learning Phase
- `metric-diagnosis` -- quando overlap pode ser causa raiz de CPA alto ou CPM inflado

### Receives From

- `campaign-monitor` -- trigger automatico semanal (minimo)
- `metric-diagnosis` -- quando CPM inflado sugere auto-competicao
- User command -- `*detect-overlap`

### Agent Assignment

- **Primary:** @performance-analyst
- **Tier:** Auto
- **Reports to:** @media-strategist

### Periodic Check

@performance-analyst deve incluir verificacao de overlap no digest semanal sempre que a conta tiver 3+ ad sets ativos. Isso previne degradacao silenciosa de performance por auto-competicao.

---

## Usage Examples

### Command Line

```
*detect-overlap campaign_123

*detect-overlap --all-campaigns

*detect-overlap --threshold 25 --include-low
```

### Sample Output

```
AUCTION OVERLAP DETECTOR - Account_XYZ

Pares analisados: 6 (4 ad sets ativos)

OVERLAP #1 - ALTA (38%)
  Ad Set A: Prospecting_Interest_Yoga
  Ad Set B: Prospecting_Broad_Women_25-34
  Scope: Intra-campanha (Campaign_123)
  Fonte: Broad vs narrow targeting
  Orcamento em risco: R$1,200/mes
  Impacto Learning: SIM (ambos em Learning Limited)
  Recomendacao: CONSOLIDAR - Merge em unico ad set com targeting amplo

OVERLAP #2 - MODERADA (22%)
  Ad Set A: Retargeting_Visitors_30d
  Ad Set B: Prospecting_Lookalike_1%
  Scope: Cross-campanha
  Fonte: Retargeting nao excluido de prospecting
  Recomendacao: EXCLUSAO MUTUA - Excluir visitantes 30d do Lookalike

Resumo: 1 overlap ALTA, 1 MODERADA
Budget waste estimado: R$1,200/mes
Acao prioritaria: Consolidar ad sets de Prospecting na Campaign_123
```

---

_Auction Overlap Detector Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
