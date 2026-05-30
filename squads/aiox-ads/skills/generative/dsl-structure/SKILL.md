# DSL Structure Skill

**ID:** `dsl-structure`
**Category:** generative
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Cria estruturas de DSL (Deck Sales Letter) seguindo o framework revolucionário de Jeremy Haynes. DSL supera VSL em engajamento: 77% chegam ao slide 5 vs 5-9% que apertam play em VSL.

**Activation Command:** `*create-dsl {product}`
**Announce:** "Ativando DSL Structure com DSL Revolution Framework de Jeremy Haynes."

---

## Expert Sources

| Expert        | Framework                | Weight | Focus             |
| ------------- | ------------------------ | ------ | ----------------- |
| Jeremy Haynes | DSL Revolution Framework | 0.95   | Estrutura DSL     |
| Jeremy Haynes | Mini Webinar 2.0         | 0.90   | Funil high-ticket |
| Jeremy Haynes | Slide 5 Optimization     | 0.93   | Retenção crítica  |

---

## DSL vs VSL Comparison

```yaml
comparison:
  vsl:
    press_play_rate: '5-9%'
    cost_per_call: '$90-120'
    engagement_barrier: 'Alto (play button)'
    user_control: 'Baixo (linear)'
    optimization: 'Difícil (vídeo fixo)'

  dsl:
    slide_5_reach: '77%'
    cost_per_call: '$30-80'
    engagement_barrier: 'Baixo (scroll)'
    user_control: 'Alto (próprio ritmo)'
    optimization: 'Fácil (slides editáveis)'

key_insight: |
  "Consumer behavior has shifted - people are fed up with shitty VSLs.
   Deck Sales Letter is the revolution." - Jeremy Haynes
```

---

## DSL Structure (Jeremy Haynes)

### Core Principle: 77% Drop After Slide 5

```yaml
critical_insight:
  fact: '77% das pessoas chegam ao slide 5'
  implication: 'Conteúdo essencial DEVE estar nos primeiros 5 slides'
  strategy: 'Front-load value, introduzir oferta cedo'
```

### Optimal Structure

```yaml
slides:
  slide_1:
    purpose: 'Hook + Introdução'
    content:
      - 'Headline impactante'
      - 'Promessa principal'
      - 'Quem você é (1 linha)'
    word_limit: 50
    time_to_read: '10-15 segundos'
    example: |
      Como faturar R$100k/mês com Meta Ads
      (mesmo começando do zero)

      Por [Nome], R$50M gerenciados em ads

  slide_2:
    purpose: 'Problema + Identificação'
    content:
      - 'Dor principal do avatar'
      - 'Por que isso acontece'
      - 'Consequências de não resolver'
    word_limit: 75
    example: |
      Você investe em ads todo mês...
      Mas os resultados são inconsistentes.

      Um mês vende, outro não.
      E você não sabe o porquê.

  slide_3:
    purpose: 'Solução + Mecanismo'
    content:
      - 'O que você descobriu'
      - 'Por que funciona diferente'
      - 'Resultado possível'
    word_limit: 75
    example: |
      Depois de R$50M em ads, descobri um padrão:

      Um método de 3 etapas que elimina
      a adivinhação e torna tudo previsível.

  slide_4:
    purpose: 'Prova + Resultados'
    content:
      - 'Casos de sucesso'
      - 'Números específicos'
      - 'Screenshots/depoimentos'
    word_limit: 50
    example: |
      +347 alunos aplicando o método

      Média de R$23k/mês em 90 dias
      (começando do zero ou não)

  slide_5:
    purpose: 'A Oferta'
    content:
      - 'O que está sendo oferecido'
      - 'O que inclui'
      - 'Diferencial'
    word_limit: 75
    critical: true
    note: '77% chegam aqui - OFERTA deve estar clara'
    example: |
      O Método Meta Ads Mastery

      ✅ 12 módulos passo-a-passo
      ✅ Templates de campanha
      ✅ Suporte por 12 meses
      ✅ Comunidade exclusiva

  arrow_prompt:
    text: 'Press to continue →'
    position: 'Entre slide 5 e 6'
    impact: '+20% → 77% slide 5 reach'
    purpose: 'Manter engajamento pós-oferta'

  slides_6_plus:
    purpose: 'Aprofundamento + FAQ'
    content:
      - 'Detalhes do que está incluso'
      - 'Bônus'
      - 'Objeções/FAQ'
      - 'Garantia'
      - 'CTA final'
    note: 'Só 23% chegam aqui - conteúdo de suporte'
```

---

## FAQ Slides Structure

```yaml
faq_best_practices:
  placement: 'Slides 6-10 (após oferta)'
  format: 'Uma objeção por slide'

  common_objections:
    - objection: 'Funciona para meu nicho?'
      answer: 'Template + 2-3 exemplos de nichos'

    - objection: 'Preciso de muito dinheiro?'
      answer: 'Valor mínimo + exemplos low-budget'

    - objection: 'E se não funcionar?'
      answer: 'Garantia + suporte'

    - objection: 'Quanto tempo demora?'
      answer: 'Timeline realista + primeiros resultados'

    - objection: 'Por que devo confiar em você?'
      answer: 'Credenciais + prova social'
```

---

## Generation Process

### Input Collection

```yaml
inputs:
  product:
    name: ''
    type: 'curso|mentoria|serviço|software'
    price: ''
    main_benefit: ''
    unique_mechanism: ''
    includes: []
    guarantee: ''

  creator:
    name: ''
    credentials: ''
    results: ''
    story_hook: ''

  audience:
    main_pain: ''
    main_desire: ''
    objections: []

  proof:
    testimonials: []
    case_studies: []
    numbers: []
```

### Output Structure

```yaml
dsl_output:
  product: 'Curso Meta Ads'
  total_slides: 15

  slides:
    - number: 1
      type: 'hook'
      headline: ''
      body: ''
      word_count: 0
      visual_suggestion: ''

    - number: 2
      type: 'problem'
      headline: ''
      body: ''
      word_count: 0

    # ... continues for all slides

  arrow_prompts:
    - after_slide: 5
      text: 'Press to continue →'
    - after_slide: 10
      text: 'Almost there →'

  metrics_targets:
    slide_5_reach: '> 70%'
    completion_rate: '> 20%'
    cta_clicks: '> 15%'

  expert_attribution:
    framework: 'Jeremy Haynes - DSL Revolution'
    optimization: 'Slide 5 Optimization'
```

---

## Integration

### Triggered By

- `creative-brief` - para formato DSL
- `funnel-selection` - quando funil é high-ticket
- User command - `*create-dsl`

### Dispatches To

- Designer (para criação visual)
- `copy-generator` - para copy de slides

### Agent Assignment

- **Primary:** @creative-analyst
- **Approval:** @media-strategist

---

## Usage Examples

```
*create-dsl "Mentoria High Ticket"

*create-dsl "Curso Meta Ads" --slides 12 --include-faq

*create-dsl --from-vsl "url_do_vsl" --convert
```

### Sample Output

```
📑 DSL STRUCTURE - Curso Meta Ads

╔══════════════════════════════════════════════════════╗
║ SLIDE 1: HOOK                                        ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ "Como Faturar R$100k/mês com Meta Ads"              ║
║ (mesmo começando do zero)                           ║
║                                                      ║
║ Por [Nome] - R$50M gerenciados em ads               ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ SLIDE 2: PROBLEMA                                    ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ Você investe em ads todo mês...                     ║
║ Mas os resultados são inconsistentes.               ║
║                                                      ║
║ Um mês vende, outro não.                            ║
║ E você não sabe o porquê.                           ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ [... slides 3-4 ...]                                ║
╠══════════════════════════════════════════════════════╣
║ 🔴 SLIDE 5: A OFERTA (77% chegam aqui)              ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ O Método Meta Ads Mastery                           ║
║                                                      ║
║ ✅ 12 módulos passo-a-passo                         ║
║ ✅ Templates de campanha                            ║
║ ✅ Suporte por 12 meses                             ║
║ ✅ Comunidade exclusiva                             ║
║                                                      ║
║ [ Press to continue → ]                             ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ EXPERT: Jeremy Haynes - DSL Revolution Framework    ║
║ MÉTRICA: Target 77% Slide 5 Reach                   ║
╚══════════════════════════════════════════════════════╝
```

---

_DSL Structure Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
