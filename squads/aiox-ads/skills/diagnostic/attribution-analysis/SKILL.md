# Attribution Analysis Skill

**ID:** `attribution-analysis`
**Category:** diagnostic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Análise de atribuição para entender o verdadeiro impacto das campanhas, comparar janelas de atribuição, e reconciliar dados entre plataformas.

**Activation Command:** `*analyze-attribution`
**Announce:** "Ativando Attribution Analysis com Post-iOS14 Optimization."

---

## Expert Sources

| Expert        | Framework                  | Weight | Focus                 |
| ------------- | -------------------------- | ------ | --------------------- |
| Jeremy Haynes | Post-iOS14 Optimization    | 0.95   | Atribuição moderna    |
| Jeremy Haynes | Attribution Settings       | 0.92   | Janelas de atribuição |
| Brian Moncada | Cross-Platform Attribution | 0.88   | Multi-touch           |

---

## Attribution Windows

### Meta Ads Options

```yaml
attribution_windows:
  - window: '1-day click'
    use_for:
      - 'Produtos impulso'
      - 'Low ticket'
      - 'Decisão rápida'
    pros: 'Dados mais precisos'
    cons: 'Menos conversões atribuídas'

  - window: '7-day click, 1-day view'
    use_for:
      - 'Produtos consideração média'
      - 'Ticket médio'
      - 'Default recomendado'
    recommended: true

  - window: '7-day click, 7-day view'
    use_for:
      - 'Produtos high ticket'
      - 'Decisão demorada'
      - 'B2B'
    pros: 'Captura mais conversões'
    cons: 'Pode superestimar impacto'

  - window: '28-day click'
    use_for:
      - 'High ticket'
      - 'Lançamentos'
      - 'Produtos complexos'
    pros: 'Máxima captura'
    cons: 'Atribuição pode ser imprecisa'
```

---

## Attribution Models

### Last-Click (Default Meta)

```
Jornada: Ad A → Ad B → Ad C → Conversão
Atribuição: 100% → Ad C

Quando usar:
- Campanhas de resposta direta
- Funis curtos
- Decisão única
```

### First-Click

```
Jornada: Ad A → Ad B → Ad C → Conversão
Atribuição: 100% → Ad A

Quando usar:
- Awareness
- Descoberta de marca
- Conteúdo topo de funil
```

### Linear

```
Jornada: Ad A → Ad B → Ad C → Conversão
Atribuição: 33% → cada

Quando usar:
- Funis longos
- Múltiplos touchpoints
- Análise holística
```

### Data-Driven (Meta)

```
Usa ML para determinar contribuição real de cada touchpoint

Requisitos:
- Mínimo 300 conversões/mês
- Dados históricos suficientes
```

---

## iOS14+ Impact Analysis

### Attribution Loss Estimation

```yaml
ios_impact:
  browser_only_tracking:
    estimated_loss: '30-50%'
    affected_events:
      - ViewContent
      - AddToCart
      - Purchase

  with_capi:
    estimated_loss: '10-20%'
    improvement: '2-3x melhor atribuição'

  with_capi_optimized:
    estimated_loss: '5-15%'
    requirements:
      - Event Match Quality > 8
      - Deduplicação ativa
      - Parâmetros completos

ios_traffic_percentage:
  threshold: 50%
  action: 'Se >50% iOS, CAPI é obrigatório'
```

### Recovery Strategies

```yaml
strategies:
  - strategy: 'CAPI Implementation'
    priority: 1
    impact: '+25-40% attribution recovery'
    expert: 'Jeremy Haynes'

  - strategy: 'Aggregated Event Measurement'
    priority: 2
    impact: 'Mantém otimização ML'
    note: '8 eventos priorizados'

  - strategy: 'Modeled Conversions'
    priority: 3
    impact: 'Estatísticas estimadas'
    note: 'Meta estima conversões não reportadas'
```

---

## Cross-Platform Reconciliation

### Data Sources to Compare

```yaml
sources:
  meta_ads_manager:
    data: 'Conversões atribuídas'
    timing: 'Real-time + 72h adjustment'
    reliability: 'Medium (iOS14 impact)'

  google_analytics:
    data: 'Sessões, conversões'
    model: 'Last non-direct click'
    reliability: 'Medium (cookie dependent)'

  backend_database:
    data: 'Vendas reais'
    timing: 'Real-time'
    reliability: 'High (source of truth)'

  payment_processor:
    data: 'Transações confirmadas'
    timing: 'Real-time'
    reliability: 'Very High'

reconciliation_tolerance:
  acceptable: '< 15% variance'
  warning: '15-30% variance'
  critical: '> 30% variance'
```

### Reconciliation Process

```javascript
function reconcileAttribution(metaData, backendData) {
  const variance = Math.abs(((metaData.conversions - backendData.sales) / backendData.sales) * 100);

  if (variance < 15) {
    return { status: 'healthy', action: 'none' };
  } else if (variance < 30) {
    return {
      status: 'warning',
      action: 'review_tracking',
      skill: 'tracking-audit',
    };
  } else {
    return {
      status: 'critical',
      action: 'immediate_audit',
      skill: 'tracking-audit',
      escalate: true,
    };
  }
}
```

---

## Output Format

```yaml
attribution_analysis:
  analysis_date: '2026-02-01'
  period: 'last_30_days'

  current_settings:
    attribution_window: '7-day click, 1-day view'
    optimization_goal: 'conversions'
    conversion_event: 'Purchase'

  traffic_breakdown:
    ios: 55%
    android: 35%
    desktop: 10%
    ios_impact_risk: 'high'

  attribution_health:
    meta_reported_conversions: 150
    backend_conversions: 180
    variance: 16.7%
    status: 'warning'

  capi_status:
    enabled: true
    event_match_quality: 6.8
    deduplication: true
    match_rate: 72%

  window_comparison:
    1d_click:
      conversions: 120
      roas: 2.1
    7d_click_1d_view:
      conversions: 150
      roas: 2.6
    7d_click_7d_view:
      conversions: 165
      roas: 2.9

  recommendations:
    - priority: 1
      action: 'Melhorar Event Match Quality de 6.8 para 8+'
      expected_impact: '+15% attribution recovery'
      expert: 'Jeremy Haynes'

    - priority: 2
      action: 'Considerar 7d click 7d view para high ticket'
      rationale: '55% iOS, decisão demorada'
      expected_impact: '+10% reported conversions'

    - priority: 3
      action: 'Reconciliar backend semanalmente'
      rationale: '16.7% variance needs monitoring'
```

---

## Integration

### Triggers

```yaml
triggers:
  - condition: 'meta_conversions vs backend_sales > 30%'
    action: 'run_attribution_analysis'
    urgency: 'critical'

  - condition: 'ios_percentage > 60%'
    action: 'check_capi_status'
    urgency: 'high'

  - condition: 'event_match_quality < 5'
    action: 'run_attribution_analysis'
    urgency: 'high'
```

### Dispatches To

- `tracking-audit` - quando há discrepância
- `metric-diagnosis` - para interpretar dados

### Agent Assignment

- **Primary:** @pixel-specialist
- **Secondary:** @performance-analyst
- **Reports to:** @media-strategist

---

## Usage Examples

```
*analyze-attribution

*analyze-attribution --compare-windows

*analyze-attribution --reconcile-backend
```

### Sample Output

```
🎯 ANÁLISE DE ATRIBUIÇÃO

╔══════════════════════════════════════════════════════╗
║ PERÍODO: Últimos 30 dias                             ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ JANELA ATUAL: 7-day click, 1-day view               ║
║                                                      ║
║ TRÁFEGO iOS: 55% ⚠️ (alto risco atribuição)         ║
║                                                      ║
║ COMPARAÇÃO DE DADOS:                                 ║
║ • Meta Ads: 150 conversões                          ║
║ • Backend: 180 vendas                               ║
║ • Variância: 16.7% ⚠️                               ║
║                                                      ║
║ CAPI STATUS:                                         ║
║ • EMQ: 6.8 (meta: 8+)                               ║
║ • Match Rate: 72%                                   ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ AÇÃO: Otimizar CAPI para +15% atribuição            ║
║ EXPERT: Jeremy Haynes - Post-iOS14 Optimization     ║
╚══════════════════════════════════════════════════════╝
```

---

_Attribution Analysis Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
