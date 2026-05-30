# Page Analyzer Skill

**ID:** `page-analyzer`
**Category:** diagnostic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Analisa landing pages via WebFetch para gerar um Experience Media Quality (EMQ) score de 1 a 10. Avalia: velocidade de carregamento, responsividade mobile, clareza do CTA, sinais de confianca, tamanho de formularios e status de disparo do Pixel. Score < 6.0 e um hard gate que BLOQUEIA lancamento de campanha conforme `launch-dod.md`.

**Activation Command:** `*analyze-page`
**Announce:** "Ativando Page Analyzer. Avaliando qualidade da landing page via WebFetch."

---

## EMQ Threshold (NON-NEGOTIABLE)

```yaml
emq_minimum: 6.0
action_if_below: BLOCK
```

**Regra:** Landing page com EMQ < 6.0 BLOQUEIA lancamento de campanha. Este threshold e um hard gate integrado em `checklists/launch-dod.md` (Gate 3). Nenhum agente pode bypassar este gate. Budget gasto com landing page de baixa qualidade e desperdicio -- Meta penaliza ads com LP ruins (CPC mais alto, menor delivery).

---

## Analysis Framework

### Dimensions Avaliadas

| # | Dimensao | Peso | Metodo de Avaliacao |
|---|----------|------|---------------------|
| 1 | Velocidade de carregamento | 20% | WebFetch: tempo de resposta, tamanho da pagina, recursos bloqueantes |
| 2 | Responsividade mobile | 20% | WebFetch: viewport meta tag, media queries, elementos overflow |
| 3 | Clareza do CTA | 15% | WebFetch: presenca e posicionamento de CTAs, contraste visual, acima do fold |
| 4 | Sinais de confianca | 15% | WebFetch: SSL, depoimentos, logos parceiros, politica de privacidade, CNPJ |
| 5 | Tamanho de formularios | 10% | WebFetch: quantidade de campos, campos obrigatorios, multi-step detection |
| 6 | Status do Pixel | 20% | WebFetch: Meta Pixel presente no codigo, eventos configurados, CAPI script |

### Scoring por Dimensao

Cada dimensao recebe uma nota de 0.0 a 10.0. O EMQ final e a media ponderada.

```
EMQ = (velocidade * 0.20) + (mobile * 0.20) + (cta * 0.15)
    + (confianca * 0.15) + (formulario * 0.10) + (pixel * 0.20)
```

---

## Dimension Details

### 1. Velocidade de Carregamento (peso 20%)

```yaml
speed_analysis:
  method: WebFetch
  checks:
    - response_time:
        excellent: '< 1.5s'
        good: '1.5s - 3.0s'
        average: '3.0s - 5.0s'
        poor: '> 5.0s'
    - page_size:
        excellent: '< 1MB'
        good: '1MB - 3MB'
        poor: '> 3MB'
    - render_blocking:
        check: 'Scripts/CSS bloqueando render no head'
        fix: 'Async/defer scripts, critical CSS inline'
    - image_optimization:
        check: 'Imagens > 500KB, sem lazy loading'
        fix: 'Comprimir imagens, WebP, lazy loading'

  scoring:
    10: 'Response < 1s, page < 500KB'
    8: 'Response < 2s, page < 1MB'
    6: 'Response < 3s, page < 2MB'
    4: 'Response < 5s, page < 5MB'
    2: 'Response > 5s'
    0: 'Pagina nao carrega ou timeout'
```

### 2. Responsividade Mobile (peso 20%)

```yaml
mobile_analysis:
  method: WebFetch
  checks:
    - viewport_meta:
        required: true
        tag: '<meta name="viewport" content="width=device-width, initial-scale=1">'
    - horizontal_scroll:
        check: 'Elementos vazando alem do viewport em mobile'
        fail_condition: 'Qualquer overflow horizontal'
    - touch_targets:
        check: 'Botoes e links com area clicavel >= 44x44px'
    - font_readability:
        check: 'Fonte legivel sem zoom (>= 16px body)'
    - media_queries:
        check: 'CSS com breakpoints para mobile/tablet/desktop'

  scoring:
    10: 'Viewport + sem overflow + touch targets ok + fonte legivel'
    7: 'Viewport presente mas minor overflow ou font pequena'
    4: 'Sem viewport meta tag OU overflow significativo'
    0: 'Pagina completamente nao-responsiva'
```

### 3. Clareza do CTA (peso 15%)

```yaml
cta_analysis:
  method: WebFetch
  checks:
    - cta_presence:
        required: true
        check: 'Pelo menos 1 CTA visivel (button, link proeminente)'
    - cta_above_fold:
        check: 'CTA principal visivel sem scroll'
        weight: HIGH
    - cta_contrast:
        check: 'CTA com cor contrastante ao fundo'
    - cta_text_clarity:
        check: 'Texto do CTA e acao clara (nao "Clique aqui")'
        good_examples: ['Comecar agora', 'Agendar demonstracao', 'Comprar com desconto']
        bad_examples: ['Clique aqui', 'Saiba mais', 'Enviar']
    - cta_count:
        check: 'Nao exceder 2 CTAs distintos por viewport (evitar decisao paralysis)'

  scoring:
    10: 'CTA acima fold + contraste + texto claro + unico foco'
    7: 'CTA presente mas abaixo fold OU texto generico'
    4: 'CTA presente mas confuso ou multiplos conflitantes'
    0: 'Sem CTA identificavel'
```

### 4. Sinais de Confianca (peso 15%)

```yaml
trust_analysis:
  method: WebFetch
  checks:
    - ssl_active:
        required: true
        check: 'URL usa HTTPS'
        fail_impact: 'Critico -- navegadores mostram "Nao seguro"'
    - social_proof:
        check: 'Depoimentos, reviews, quantidade de clientes'
        types: ['depoimentos', 'reviews', 'case studies', 'logos de clientes']
    - authority_signals:
        check: 'Logos de parceiros, certificacoes, mencoes na midia'
    - privacy_policy:
        check: 'Link para politica de privacidade acessivel'
    - company_info:
        check: 'CNPJ, endereco, ou informacoes de contato visiveis'
    - guarantees:
        check: 'Garantia de satisfacao, devolucao, etc.'

  scoring:
    10: 'SSL + social proof + authority + privacy + company info'
    7: 'SSL + pelo menos 2 sinais de confianca adicionais'
    4: 'SSL mas poucos sinais de confianca'
    2: 'Sem SSL OU pagina parece nao-profissional'
    0: 'Sem SSL E sem nenhum sinal de confianca'
```

### 5. Tamanho de Formularios (peso 10%)

```yaml
form_analysis:
  method: WebFetch
  checks:
    - field_count:
        excellent: '<= 3 campos'
        good: '4-5 campos'
        average: '6-8 campos'
        poor: '> 8 campos'
    - required_fields:
        check: 'Quantidade de campos obrigatorios vs opcionais'
    - multi_step:
        check: 'Formulario divide em etapas (reduz abandono)'
        bonus: '+1 ponto se multi-step com < 4 campos por etapa'
    - auto_fill:
        check: 'Campos suportam autocomplete do navegador'
    - error_handling:
        check: 'Validacao inline (nao apenas no submit)'

  scoring:
    10: '<= 3 campos, multi-step, auto-fill'
    8: '4-5 campos com boa UX'
    6: '6-8 campos OU formulario longo sem multi-step'
    4: '> 8 campos em tela unica'
    2: 'Formulario confuso ou quebrado'
    0: 'Sem formulario quando esperado (LP de conversao sem form)'
    na: 'LP sem formulario intencional (e-commerce direto, etc.) -- score 8.0 por padrao'

  note: "Para LPs de e-commerce sem formulario (checkout no carrinho), usar score padrao 8.0 nesta dimensao"
```

### 6. Status do Pixel (peso 20%)

```yaml
pixel_analysis:
  method: WebFetch
  checks:
    - pixel_installed:
        required: true
        check: 'Meta Pixel base code presente no HTML'
        search: 'fbq | facebook.com/tr | connect.facebook.net'
    - pixel_id_correct:
        check: 'Pixel ID match com configuracao da conta'
    - standard_events:
        check: 'Eventos padrao configurados na pagina'
        expected: ['PageView']
        bonus: ['ViewContent', 'AddToCart', 'InitiateCheckout', 'Purchase', 'Lead']
    - capi_signals:
        check: 'Server-side tracking configurado'
        search: 'Conversions API, server events, advanced matching'
    - event_firing:
        check: 'Eventos disparando corretamente (nao apenas instalado)'
        method: 'Verificar presenca de fbq("track") calls no codigo'

  scoring:
    10: 'Pixel + eventos padrao + CAPI + advanced matching'
    8: 'Pixel + PageView + pelo menos 1 evento de conversao'
    6: 'Pixel instalado com PageView apenas'
    4: 'Pixel instalado mas possivelmente nao disparando (sem fbq track calls)'
    2: 'Pixel ID encontrado mas codigo possivelmente incorreto'
    0: 'Nenhum sinal de Meta Pixel na pagina'
```

---

## Analysis Process

### Step 1: Fetch da Pagina

```yaml
fetch_config:
  tool: WebFetch
  url: '{landing_page_url}'
  timeout: 30s
  user_agent: 'Mobile (primary) + Desktop (secondary)'
  captures:
    - full_html
    - response_time
    - response_headers
    - ssl_status
```

### Step 2: Analise por Dimensao

```
FOR EACH dimension in [speed, mobile, cta, trust, form, pixel]:
    score = evaluate(dimension, page_data)
    issues = detect_issues(dimension, page_data)
    recommendations = generate_fixes(issues)
```

### Step 3: Calculo EMQ

```
emq = weighted_average(dimension_scores, dimension_weights)

IF emq < 6.0:
    action = BLOCK
    message = "EMQ {emq}/10.0 -- ABAIXO DO MINIMO. Lancamento BLOQUEADO."
    detail = list top 3 dimensions com menor score + recomendacoes especificas

ELIF emq >= 6.0 AND emq < 8.0:
    action = WARN
    message = "EMQ {emq}/10.0 -- ACEITAVEL com ressalvas. Recomendacoes de melhoria listadas."

ELIF emq >= 8.0:
    action = PASS
    message = "EMQ {emq}/10.0 -- BOM. Landing page aprovada."
```

---

## Output Format

```yaml
page_analysis:
  url: '{landing_page_url}'
  analysis_date: '{date}'
  fetch_method: 'WebFetch'

  emq_score: {N.N}
  emq_minimum: 6.0
  gate_result: 'PASS | WARN | BLOCK'

  dimensions:
    - name: 'Velocidade de carregamento'
      score: {N.N}
      weight: 0.20
      weighted_score: {N.N}
      issues:
        - '{issue description}'
      recommendations:
        - '{specific fix}'

    - name: 'Responsividade mobile'
      score: {N.N}
      weight: 0.20
      weighted_score: {N.N}
      issues: []
      recommendations: []

    - name: 'Clareza do CTA'
      score: {N.N}
      weight: 0.15
      weighted_score: {N.N}
      issues: []
      recommendations: []

    - name: 'Sinais de confianca'
      score: {N.N}
      weight: 0.15
      weighted_score: {N.N}
      issues: []
      recommendations: []

    - name: 'Tamanho de formularios'
      score: {N.N}
      weight: 0.10
      weighted_score: {N.N}
      issues: []
      recommendations: []

    - name: 'Status do Pixel'
      score: {N.N}
      weight: 0.20
      weighted_score: {N.N}
      issues: []
      recommendations: []

  top_improvements:
    - priority: 1
      dimension: '{lowest scoring dimension}'
      current_score: {N.N}
      potential_score: {N.N}
      fix: '{specific action}'
      emq_impact: '+{N.N} EMQ'

    - priority: 2
      dimension: '{second lowest}'
      current_score: {N.N}
      potential_score: {N.N}
      fix: '{specific action}'
      emq_impact: '+{N.N} EMQ'

    - priority: 3
      dimension: '{third lowest}'
      current_score: {N.N}
      potential_score: {N.N}
      fix: '{specific action}'
      emq_impact: '+{N.N} EMQ'

  summary: '{1-2 sentence overall assessment}'
```

---

## Integration

### Hard Gate in launch-dod.md

Esta skill e referenciada diretamente no `checklists/launch-dod.md` (Gate 3):

```
Gate 3 -- Landing Page EMQ Score >= 6.0
Verificacao: Executar skill page-analyzer para gerar EMQ score.
Severidade: BLOCK
```

O resultado desta skill e consumido por @fiscal durante o checklist de lancamento. EMQ < 6.0 = campanha NAO sera ativada.

### Dispatches To

- `tracking-audit` -- quando Pixel score < 6.0, aprofundar investigacao de tracking
- `metric-diagnosis` -- quando EMQ historico correlaciona com queda de CVR

### Receives From

- `launch-dod.md` (Gate 3) -- trigger obrigatorio pre-lancamento
- `campaign-monitor` -- trigger opcional em revisoes periodicas
- User command -- `*analyze-page`

### Agent Assignment

- **Primary:** @pixel-specialist
- **Tier:** Auto
- **Reports to:** @media-strategist

---

## Usage Examples

### Command Line

```
*analyze-page https://exemplo.com/oferta

*analyze-page --url https://exemplo.com/oferta --mobile-only

*analyze-page --batch urls.txt
```

### Sample Output

```
PAGE ANALYZER - https://exemplo.com/oferta

EMQ SCORE: 7.2 / 10.0 -- WARN (aceitavel com ressalvas)
Gate: PASS (>= 6.0)

Dimensoes:
  Velocidade:     8.0/10 (1.8s, 1.2MB)
  Mobile:         9.0/10 (viewport ok, sem overflow)
  CTA:            7.0/10 (presente mas abaixo do fold)
  Confianca:      5.0/10 (SSL ok, sem depoimentos, sem CNPJ)
  Formulario:     8.0/10 (4 campos, multi-step)
  Pixel:          6.0/10 (Pixel ok, PageView ok, sem CAPI)

Top 3 Melhorias:
  1. Sinais de confianca (5.0 -> 8.0): Adicionar depoimentos e CNPJ. EMQ +0.45
  2. Pixel/CAPI (6.0 -> 9.0): Configurar server-side CAPI. EMQ +0.60
  3. CTA (7.0 -> 9.0): Mover CTA principal acima do fold. EMQ +0.30

Pos-melhorias estimadas: EMQ 7.2 -> 8.6
```

---

_Page Analyzer Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
