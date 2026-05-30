# Angle Generator Skill

**ID:** `angle-generator`
**Category:** generative
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Gera ângulos criativos diferentes para abordar o mesmo produto/oferta, permitindo testar múltiplas perspectivas e encontrar o posicionamento mais eficaz para cada audiência.

**Activation Command:** `*generate-angles {product}`
**Announce:** "Ativando Angle Generator com Creative Strategy Framework."

---

## Expert Sources

| Expert         | Framework           | Weight | Focus                |
| -------------- | ------------------- | ------ | -------------------- |
| Jordan Stupar  | Creative Concepts   | 0.85   | Ângulos criativos    |
| Jeremy Haynes  | Multi-Angle Testing | 0.90   | Teste de ângulos     |
| Brandon Carter | Creative Variables  | 0.88   | Variação sistemática |

---

## Angle Categories

### 1. Pain-Based Angles

```yaml
description: 'Focam no problema/dor'
examples:
  - angle: 'O Custo da Inação'
    focus: 'O que perdem por não agir'
    example: 'Cada dia sem o método certo = R$500 perdidos'

  - angle: 'O Inimigo Comum'
    focus: 'Problema externo culpável'
    example: 'O algoritmo mudou. Quem não se adapta fica para trás'

  - angle: 'A Armadilha'
    focus: 'Erro que estão cometendo'
    example: 'O erro que 90% dos anunciantes cometem'

best_for: 'Audiência consciente do problema'
```

### 2. Aspiration-Based Angles

```yaml
description: 'Focam no resultado desejado'
examples:
  - angle: 'A Nova Identidade'
    focus: 'Quem eles se tornam'
    example: 'De iniciante a media buyer profissional em 90 dias'

  - angle: 'O Estilo de Vida'
    focus: 'Vida após a transformação'
    example: 'Trabalhe 4h/dia de qualquer lugar'

  - angle: 'O Resultado Específico'
    focus: 'Número ou marco claro'
    example: 'R$50k/mês no automático'

best_for: 'Audiência consciente da solução'
```

### 3. Logic-Based Angles

```yaml
description: 'Focam em razão e fatos'
examples:
  - angle: 'O Mecanismo Único'
    focus: 'Como funciona diferente'
    example: 'O método de 3 etapas que elimina adivinhação'

  - angle: 'A Prova Irrefutável'
    focus: 'Dados e evidências'
    example: '347 alunos, média de R$23k/mês'

  - angle: 'A Lógica Simples'
    focus: 'Raciocínio claro'
    example: 'Se você gasta R$1 e faz R$3, gasta quanto puder'

best_for: 'Audiência analítica, B2B, high ticket'
```

### 4. Emotion-Based Angles

```yaml
description: 'Focam em sentimentos'
examples:
  - angle: 'O Medo de Perder'
    focus: 'FOMO, urgência'
    example: 'Última turma do ano. 17 vagas.'

  - angle: 'A Vingança/Prova'
    focus: 'Provar para outros'
    example: 'Faça quem duvidou engolir as palavras'

  - angle: 'O Pertencimento'
    focus: 'Fazer parte de algo'
    example: 'Junte-se aos +500 que já dominam isso'

best_for: 'Produtos de transformação, comunidades'
```

### 5. Story-Based Angles

```yaml
description: 'Focam em narrativa'
examples:
  - angle: 'A Jornada do Herói'
    focus: 'Sua história de transformação'
    example: 'De falido a R$100k/mês: minha jornada'

  - angle: 'O Descobridor'
    focus: 'Como encontrou o segredo'
    example: 'Depois de R$1M em ads, descobri isso...'

  - angle: 'O Relutante'
    focus: 'Não queria revelar'
    example: 'Não ia compartilhar isso, mas...'

best_for: 'Personal branding, expertise'
```

### 6. Authority-Based Angles

```yaml
description: 'Focam em credibilidade'
examples:
  - angle: 'O Especialista'
    focus: 'Expertise demonstrada'
    example: '10 anos gerenciando R$50M em ads'

  - angle: 'O Insider'
    focus: 'Acesso a informação exclusiva'
    example: 'O que aprendi trabalhando com [figura conhecida]'

  - angle: 'O Contrarian'
    focus: 'Contra a corrente'
    example: 'Por que discordo de 99% dos gurus de ads'

best_for: 'High ticket, consultoria, B2B'
```

---

## Generation Process

### Input Collection

```yaml
inputs:
  product:
    name: ''
    main_benefit: ''
    unique_mechanism: ''
    target_audience: ''

  existing_angles:
    current: [] # Ângulos já usados
    best_performer: ''

  audience:
    pain_points: []
    aspirations: []
    objections: []
    awareness: ''

  constraints:
    angles_needed: 5
    exclude_categories: []
```

### Angle Generation Matrix

```yaml
generation_rules:
  minimum_angles: 5
  per_category: 1 # Pelo menos um de cada categoria relevante

  priority_by_awareness:
    unaware:
      - emotion
      - story
    problem_aware:
      - pain
      - logic
    solution_aware:
      - aspiration
      - authority
    product_aware:
      - logic
      - authority
    most_aware:
      - aspiration
      - emotion
```

---

## Output Format

```yaml
angle_generation:
  product: 'Curso Meta Ads'
  audience: 'Empreendedores digitais'
  generated_at: '2026-02-01'

  angles:
    - id: 1
      category: 'pain'
      name: 'O Custo da Inação'
      description: 'Foca no dinheiro perdido por não saber anunciar'
      hook_example: 'Cada dia sem um método = R$500 jogados fora'
      best_for: 'Cold audience, problem-aware'
      expected_response: 'Culpa + urgência'
      testing_priority: 1

    - id: 2
      category: 'aspiration'
      name: 'A Liberdade'
      description: 'Foca no estilo de vida do media buyer de sucesso'
      hook_example: 'Trabalhe 4h/dia de qualquer lugar do mundo'
      best_for: 'Warm audience, solution-aware'
      expected_response: 'Desejo + curiosidade'
      testing_priority: 2

    - id: 3
      category: 'logic'
      name: 'O Método Científico'
      description: 'Foca na metodologia comprovada e dados'
      hook_example: 'O método de 3 etapas com 347 casos de sucesso'
      best_for: 'Analytical audience'
      expected_response: 'Confiança + interesse'
      testing_priority: 3

    - id: 4
      category: 'story'
      name: 'A Descoberta Acidental'
      description: 'História de como descobriu o método'
      hook_example: 'Depois de perder R$30k, descobri sem querer...'
      best_for: 'Personal branding'
      expected_response: 'Curiosidade + identificação'
      testing_priority: 4

    - id: 5
      category: 'authority'
      name: 'O Insider'
      description: 'Posiciona como especialista com acesso exclusivo'
      hook_example: 'O que aprendi gerenciando R$10M em ads'
      best_for: 'High ticket, B2B'
      expected_response: 'Respeito + FOMO'
      testing_priority: 5

  testing_plan:
    phase_1:
      angles: [1, 2, 3]
      budget_per_angle: 'R$150'
      duration: '5 dias'
      success_metric: 'CTR + ROAS'

    phase_2:
      action: 'Expandir winner com 3 variações'
      budget: 'R$300'

  expert_attribution:
    primary: 'Jordan Stupar - Creative Concepts'
    testing: 'Jeremy Haynes - Multi-Angle Testing'
```

---

## Integration

### Triggered By

- `creative-fatigue-detector` - para novos ângulos
- `creative-brief` - para direção criativa
- User command - `*generate-angles`

### Dispatches To

- `hook-generator` - para criar hooks por ângulo
- `copy-generator` - para copy por ângulo
- `creative-brief` - para brief por ângulo

### Agent Assignment

- **Primary:** @creative-analyst
- **Reports to:** @media-strategist

---

## Usage Examples

```
*generate-angles "Curso Meta Ads"

*generate-angles "Mentoria" --categories pain,aspiration,story

*generate-angles --exclude emotion --count 7
```

---

_Angle Generator Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
