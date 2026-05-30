# Creative Brief Skill

**ID:** `creative-brief`
**Category:** generative
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Gera briefs completos para produção de criativos de anúncios, incluindo direção visual, copy, especificações técnicas e referências. Alinha expectativas entre estrategista e designer/editor.

**Activation Command:** `*create-brief {product}`
**Announce:** "Ativando Creative Brief com frameworks Jordan Stupar e Jeremy Haynes."

---

## Expert Sources

| Expert         | Framework         | Weight | Focus                 |
| -------------- | ----------------- | ------ | --------------------- |
| Jordan Stupar  | Creative Strategy | 0.85   | Conceito criativo     |
| Jeremy Haynes  | DSL Revolution    | 0.95   | Estrutura de conteúdo |
| Jeremy Haynes  | Ad Science        | 0.93   | Teste de variáveis    |
| Brandon Carter | Hook Methodology  | 0.88   | Primeiros segundos    |

---

## Brief Structure

### 1. Overview Section

```yaml
overview:
  project_name: ''
  client: ''
  product_service: ''
  campaign_objective: 'awareness|traffic|conversions|leads'
  target_cpa: ''
  deadline: ''
  deliverables_count: ''
```

### 2. Audience Definition

```yaml
audience:
  primary:
    demographics:
      age_range: ''
      gender: ''
      location: ''
      income_level: ''

    psychographics:
      interests: []
      pain_points: []
      desires: []
      beliefs: []
      objections: []

  awareness_level:
    type: 'unaware|problem_aware|solution_aware|product_aware|most_aware'
    implications: ''

  current_state: 'O que estão fazendo agora?'
  desired_state: 'Onde querem chegar?'
```

### 3. Creative Direction

```yaml
creative_direction:
  tone:
    primary: 'educativo|inspirador|urgente|provocativo|empático'
    secondary: ''

  visual_style:
    aesthetic: 'clean|bold|minimal|luxo|casual|profissional'
    colors:
      primary: ''
      secondary: ''
      accent: ''
    typography: 'serif|sans-serif|script|bold'

  mood: 'aspiracional|urgente|confiável|exclusivo|acessível'

  references:
    - url: ''
      what_to_use: ''
    - url: ''
      what_to_use: ''
```

### 4. Content Structure (DSL Revolution)

```yaml
content_structure:
  format: 'video|static|carousel|dsl'

  video_structure:
    hook:
      duration: '0-3 seconds'
      goal: 'Parar o scroll'
      type: 'problema|resultado|curiosidade|controverso'
      script: ''

    problem:
      duration: '3-10 seconds'
      goal: 'Identificar a dor'
      script: ''

    solution:
      duration: '10-25 seconds'
      goal: 'Apresentar produto'
      script: ''

    proof:
      duration: '25-40 seconds'
      goal: 'Mostrar resultados'
      elements: ['depoimentos', 'números', 'demonstração']

    cta:
      duration: '40-60 seconds'
      goal: 'Chamar para ação'
      script: ''
      urgency: ''

  dsl_structure: # Jeremy Haynes
    slide_1:
      content: 'Introdução + oferta'
      text_limit: '50 palavras'

    slide_2_3:
      content: 'Por que é uma boa oferta'
      text_limit: '100 palavras'

    slide_4_5:
      content: 'FAQ / Objeções'
      text_limit: '100 palavras'
      note: '77% chega aqui - conteúdo essencial'

    arrow_prompt:
      text: 'Press to continue'
      note: '+20% → 77% slide 5 reach'
```

### 5. Copy Elements

```yaml
copy:
  primary_text:
    max_length: '125 caracteres visíveis + expandido'
    hook: ''
    body: ''
    cta: ''

  headline:
    max_length: '40 caracteres'
    options:
      - ''
      - ''
      - ''

  description:
    max_length: '30 caracteres'
    text: ''

  cta_button: 'Saiba Mais|Comprar|Inscreva-se|Baixar'
```

### 6. Technical Specs

```yaml
technical_specs:
  formats:
    - format: 'Feed 1:1'
      dimensions: '1080x1080'
      duration: '15-60s'
      file_size: 'Max 4GB'

    - format: 'Stories 9:16'
      dimensions: '1080x1920'
      duration: '15s'
      file_size: 'Max 4GB'

    - format: 'Reels 9:16'
      dimensions: '1080x1920'
      duration: '15-30s'
      file_size: 'Max 4GB'

  requirements:
    - 'Texto em vídeo: máx 20% da imagem'
    - 'Legendas obrigatórias'
    - 'Logo nos últimos 3s'
    - 'Safe zones respeitadas'

  file_format: 'MP4 H.264'
  audio: 'AAC stereo'
```

### 7. Variations Required

```yaml
variations:
  hook_variations: 5
  reason: 'Teste científico (Brandon Carter)'

  a_b_tests:
    - element: 'Hook'
      variations: 5
      constant: 'Body + CTA'

    - element: 'CTA'
      variations: 3
      constant: 'Hook + Body'

  deliverables:
    - '5x Video Feed 1:1'
    - '5x Video Stories 9:16'
    - '1x Thumbnail por vídeo'
```

---

## Output Format

```yaml
creative_brief:
  meta:
    version: '1.0'
    created: '2026-02-01'
    created_by: '@creative-analyst'
    approved_by: '@media-strategist'

  project:
    name: 'Campanha Curso Meta Ads - Q1 2026'
    product: 'Curso Meta Ads Mastery'
    deadline: '2026-02-07'

  audience:
    persona: 'Empreendedor digital, 25-45 anos, já investiu em ads sem resultado'
    pain: 'Gasta dinheiro em ads sem retorno'
    desire: 'Escalar negócio com tráfego pago previsível'
    awareness: 'Problem-aware (sabe que precisa de tráfego)'

  creative_direction:
    tone: 'Educativo + Urgente'
    style: 'Profissional mas acessível'
    colors: '#1877F2 (Meta blue), #FFFFFF, #000000'

  hook_options:
    - type: 'problema'
      script: 'Cansado de gastar com ads que não convertem?'

    - type: 'resultado'
      script: 'De R$0 a R$50k/mês em 90 dias'

    - type: 'curiosidade'
      script: 'O segredo que aprendi depois de R$1M em ads...'

    - type: 'controverso'
      script: 'Esqueça tudo sobre CBO...'

    - type: 'prova_social'
      script: '+500 alunos já dominam isso'

  body_constant:
    script: |
      Eu criei um método simples que qualquer pessoa pode aplicar.
      Não importa se você é iniciante ou avançado.
      Em [X] dias você vai saber exatamente como criar campanhas
      que vendem no automático.

  cta_constant:
    script: 'Clica no link e começa agora'
    button: 'Saiba Mais'
    urgency: 'Vagas limitadas para essa turma'

  specs:
    primary_format: 'Video 1:1'
    secondary_format: 'Video 9:16'
    duration: '45-60s'
    variations: 5

  references:
    - url: 'link_para_referencia_1'
      note: 'Usar estilo de edição similar'
    - url: 'link_para_referencia_2'
      note: 'Usar transições similares'

  checklist:
    - '[ ] Hook nos primeiros 3s'
    - '[ ] Legendas em todo vídeo'
    - '[ ] CTA claro no final'
    - '[ ] Logo nos últimos 3s'
    - '[ ] Texto < 20% do vídeo'
    - '[ ] Entregue em 1:1 e 9:16'

  expert_attribution:
    structure: 'Jeremy Haynes - DSL Revolution'
    testing: 'Brandon Carter - Constants vs Variables'
    creative: 'Jordan Stupar - Creative Strategy'
```

---

## Integration

### Triggered By

- `hook-generator` - após gerar hooks
- `creative-fatigue-detector` - para novos criativos
- User command - `*create-brief`

### Dispatches To

- Designer/Editor (externo)
- `copy-generator` - para variações de copy

### Agent Assignment

- **Primary:** @creative-analyst
- **Approval:** @media-strategist

---

## Usage Examples

```
*create-brief "Curso Meta Ads"

*create-brief "Mentoria High Ticket" --format dsl --variations 10

*create-brief --from-winner ad_123 --refresh
```

---

_Creative Brief Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
