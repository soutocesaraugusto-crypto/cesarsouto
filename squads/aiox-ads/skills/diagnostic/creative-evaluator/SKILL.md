# Creative Evaluator Skill

**ID:** `creative-evaluator`
**Category:** diagnostic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Avalia criativos com base em dados historicos de performance e benchmarks da industria. Compara metricas numericas contra a memoria de campaign-state.yaml (winning_patterns, failed_patterns) e recomenda: manter, substituir ou testar.

**Activation Command:** `*evaluate-creatives`
**Announce:** "Ativando Creative Evaluator. Analisando performance numerica dos criativos."

---

## Scope (NON-NEGOTIABLE)

**Performance metrics only. Creative CONTENT evaluation belongs to @creative-analyst.**

Esta skill avalia EXCLUSIVAMENTE numeros:

| In Scope (Esta Skill) | Out of Scope (@creative-analyst) |
|------------------------|----------------------------------|
| CTR (Click-Through Rate) | Qualidade visual do criativo |
| Conversion Rate | Messaging e copy |
| CPA projetado | Brand alignment |
| Hook Rate (primeiros 3 seg) | Tom e voz |
| Thumb-Stop Rate | Storytelling e narrativa |
| ROAS por criativo | Estetica e design |
| Frequencia e fadiga numerica | Tendencias criativas |
| Custo por resultado por criativo | Ideacao de novos conceitos |

**Regra:** Se a analise requer julgamento SUBJETIVO sobre o CONTEUDO do criativo (imagem, video, texto, conceito), a skill DEVE encaminhar para @creative-analyst. Esta skill opera 100% em dados quantitativos.

---

## Expert Sources

| Expert | Framework | Weight | Focus |
|--------|-----------|--------|-------|
| Jeremy Haynes | Kill Rules | 0.95 | Thresholds de decisao por metrica |
| Jeremy Haynes | Constants vs Variables | 0.95 | Isolamento de variaveis em testes |
| Brian Moncada | Andromeda Method | 0.90 | Analise sistematica de performance |
| Meta Official Docs | Ad Relevance Diagnostics | 1.00 | Quality/Engagement/Conversion rankings |

---

## Knowledge Reference

- **Primary:** `data/knowledge/meta/ad_relevance_diagnostics.md`
- **Related:** `data/knowledge/meta/performance_fluctuations.md`, `data/knowledge/meta/learning_phase.md`
- **Memory:** `campaign-state.yaml` (winning_patterns, failed_patterns)

---

## Evaluation Framework

### Metrics Evaluated Per Creative

```yaml
creative_metrics:
  primary:
    - ctr: "Click-Through Rate"
    - conversion_rate: "Taxa de conversao pos-clique"
    - cpa: "Custo por acao/conversao"
    - hook_rate: "% de viewers que assistem primeiros 3 seg (video)"
    - thumb_stop_rate: "% de impressoes que geram pausa no scroll"

  secondary:
    - roas_per_creative: "ROAS atribuido ao criativo"
    - frequency: "Frequencia media de exposicao"
    - cpm: "Custo por mil impressoes"
    - spend_share: "% do orcamento consumido por este criativo"
    - impressions: "Volume total de impressoes"

  relevance_diagnostics:
    - quality_ranking: "Above | Average | Below Average"
    - engagement_rate_ranking: "Above | Average | Below Average"
    - conversion_rate_ranking: "Above | Average | Below Average"
```

### Benchmark Comparison

```yaml
benchmarks_brasil:
  ctr:
    poor: '< 0.5%'
    average: '0.5% - 1.0%'
    good: '1.0% - 2.0%'
    excellent: '> 2.0%'

  hook_rate:
    poor: '< 15%'
    average: '15% - 25%'
    good: '25% - 40%'
    excellent: '> 40%'

  thumb_stop_rate:
    poor: '< 10%'
    average: '10% - 20%'
    good: '20% - 35%'
    excellent: '> 35%'

  conversion_rate:
    poor: '< 1.0%'
    average: '1.0% - 2.5%'
    good: '2.5% - 5.0%'
    excellent: '> 5.0%'
```

**NOTA:** Benchmarks sao referencia generica. A comparacao prioritaria e contra campaign-state.yaml (historico proprio da conta).

### Campaign State Memory Comparison

```yaml
memory_comparison:
  source: campaign-state.yaml
  sections_used:
    winning_patterns:
      description: "Padroes de criativos que performaram acima do benchmark"
      max_entries: 5
      fields: [creative_type, hook_style, ctr_range, cpa_range]

    failed_patterns:
      description: "Padroes de criativos que falharam consistentemente"
      max_entries: 5
      fields: [creative_type, failure_reason, metrics_at_failure]

  comparison_logic: |
    1. Extrair metricas do criativo avaliado
    2. Comparar contra winning_patterns: criativo esta dentro dos ranges vencedores?
    3. Comparar contra failed_patterns: criativo apresenta sinais dos padroes falhos?
    4. Comparar contra industry benchmarks: criativo esta acima ou abaixo da media?
    5. Gerar veredicto combinado
```

---

## Analysis Process

### Step 1: Coleta de Dados

```yaml
data_sources:
  api_metrics:
    - Per-ad performance (CTR, CVR, CPA, impressions, spend)
    - Relevance diagnostics (3 rankings)
    - Video metrics (hook rate, completion rates)
  campaign_state:
    - campaign-state.yaml: winning_patterns section
    - campaign-state.yaml: failed_patterns section
  benchmarks:
    - Industry template benchmarks (from industry-templates/*.yaml)
    - Generic benchmarks (fallback)

minimum_data:
  impressions: 500
  days_running: 3
  note: "Criativos com < 500 impressoes ou < 3 dias recebem status INSUFFICIENT_DATA"
```

### Step 2: Scoring por Criativo

```
FOR EACH creative in ad_set:
    IF impressions < 500:
        verdict = INSUFFICIENT_DATA
        CONTINUE

    score = 0
    max_score = 100

    # Metricas primarias (peso 70%)
    score += score_ctr(creative.ctr, benchmarks.ctr, memory.winning_patterns)         # 20 pts
    score += score_cvr(creative.conversion_rate, benchmarks.cvr, memory)              # 20 pts
    score += score_cpa(creative.cpa, target_cpa, memory)                              # 15 pts
    score += score_hook(creative.hook_rate, benchmarks.hook_rate)                      # 15 pts (video only)

    # Metricas secundarias (peso 20%)
    score += score_relevance(creative.quality, creative.engagement, creative.conversion) # 10 pts
    score += score_frequency(creative.frequency)                                        # 5 pts
    score += score_thumb_stop(creative.thumb_stop_rate)                                 # 5 pts

    # Memory match (peso 10%)
    score += score_pattern_match(creative, memory.winning_patterns)                     # 5 pts
    score -= penalty_pattern_match(creative, memory.failed_patterns)                    # -5 pts

    CLASSIFY(score)
```

### Step 3: Classificacao e Veredicto

| Score | Classificacao | Veredicto | Acao |
|-------|--------------|-----------|------|
| 80-100 | Top Performer | KEEP | Manter ativo, considerar scale de orcamento |
| 60-79 | Solid Performer | KEEP | Manter, monitorar para fadiga |
| 40-59 | Average | TEST | Testar variacoes (hooks, CTAs) mantendo body constante |
| 20-39 | Underperformer | REPLACE | Substituir por novo criativo baseado em winning_patterns |
| 0-19 | Failed | REPLACE | Substituir imediatamente, documentar em failed_patterns |

---

## Output Format

```yaml
creative_evaluation:
  campaign: '{campaign_name}'
  ad_set: '{ad_set_name}'
  evaluation_date: '{date}'
  data_period: '{start_date} to {end_date}'

  creatives:
    - creative_id: '{id}'
      creative_name: '{name}'
      type: '{image | video | carousel}'
      status: ACTIVE | PAUSED

      metrics:
        ctr: {N}%
        conversion_rate: {N}%
        cpa: 'R${N}'
        hook_rate: {N}%
        thumb_stop_rate: {N}%
        roas: {N}
        frequency: {N}
        impressions: {N}
        spend: 'R${N}'

      relevance_diagnostics:
        quality_ranking: '{Above | Average | Below} Average'
        engagement_rate_ranking: '{Above | Average | Below} Average'
        conversion_rate_ranking: '{Above | Average | Below} Average'
        interpretation: '{from diagnostic matrix}'

      memory_comparison:
        matches_winning_pattern: true | false
        matches_failed_pattern: true | false
        pattern_detail: '{description}'

      score: {N}/100
      classification: '{Top | Solid | Average | Underperformer | Failed}'
      verdict: 'KEEP | TEST | REPLACE'
      recommendation: '{specific action}'

  summary:
    total_creatives: {N}
    keep: {N}
    test: {N}
    replace: {N}
    top_performer: '{creative_name}'
    worst_performer: '{creative_name}'
    overall_creative_health: '{HEALTHY | NEEDS_ATTENTION | CRITICAL}'
```

---

## Integration

### Dispatches To

- `creative-fatigue-detector` -- quando frequencia alta sugere fadiga
- `metric-diagnosis` -- quando CPA do criativo indica problema mais amplo
- @creative-analyst -- quando veredicto REPLACE requer novo conceito criativo (CONTEUDO, nao numeros)

### Receives From

- `campaign-monitor` -- trigger automatico semanal
- `metric-diagnosis` -- quando root cause aponta para criativo
- User command -- `*evaluate-creatives`

### Agent Assignment

- **Primary:** @performance-analyst
- **Tier:** Auto
- **Reports to:** @media-strategist

---

## Usage Examples

### Command Line

```
*evaluate-creatives campaign_123

*evaluate-creatives --ad-set ad_set_456

*evaluate-creatives --verdict-only --threshold replace
```

### Sample Output

```
CREATIVE EVALUATOR - Campaign_123 / Ad Set: Prospecting_Lookalike

Criativo #1: Video_Hook_Depoimento_v3
  CTR: 1.8% (good) | CVR: 3.1% (good) | CPA: R$42 (ok)
  Hook Rate: 32% (good) | Thumb Stop: 28% (good)
  Relevance: Above | Above | Above
  Memory: Matches winning_pattern "depoimento + hook direto"
  Score: 82/100 | TOP PERFORMER | KEEP
  Acao: Manter ativo. Considerar aumento de orcamento.

Criativo #2: Image_Carrossel_Beneficios_v1
  CTR: 0.4% (poor) | CVR: 1.2% (average) | CPA: R$89 (high)
  Relevance: Below | Below | Average
  Memory: Matches failed_pattern "carrossel generico sem hook"
  Score: 28/100 | UNDERPERFORMER | REPLACE
  Acao: Substituir. Usar winning_pattern "depoimento + hook direto".
  Encaminhar para @creative-analyst para novo conceito.

Resumo: 1 KEEP, 0 TEST, 1 REPLACE
Saude criativa: NEEDS_ATTENTION
```

---

_Creative Evaluator Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
