# Copy Generator Skill

**ID:** `copy-generator`
**Category:** generative
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Gera copy para anúncios usando frameworks clássicos de copywriting (PAS, AIDA, BAB) adaptados para plataformas de mídia paga.

**Activation Command:** `*generate-copy {product}`
**Announce:** "Ativando Copy Generator com frameworks PAS, AIDA e Story."

---

## Expert Sources

| Expert              | Framework         | Weight | Focus               |
| ------------------- | ----------------- | ------ | ------------------- |
| Jeremy Haynes       | Ad Copy Structure | 0.92   | Copy para ads       |
| Jordan Stupar       | Creative Copy     | 0.85   | Ângulos criativos   |
| Classic Copywriting | PAS/AIDA/BAB      | 0.90   | Frameworks testados |

---

## Copy Frameworks

### 1. PAS (Problem-Agitation-Solution)

```yaml
structure:
  problem:
    goal: 'Identificar a dor'
    format: 'Você [situação dolorosa]?'
    example: 'Você gasta com ads e não vê resultado?'

  agitation:
    goal: 'Amplificar a dor'
    format: 'Isso significa que [consequências]'
    example: 'Cada dia você perde dinheiro enquanto seus concorrentes escalam...'

  solution:
    goal: 'Apresentar solução'
    format: '[Produto] resolve [problema] através de [mecanismo]'
    example: 'O Método X te ensina exatamente como criar campanhas lucrativas em 7 dias'

best_for:
  - 'Produtos que resolvem problemas claros'
  - 'Audiência consciente do problema'
  - 'Urgência natural'
```

### 2. AIDA (Attention-Interest-Desire-Action)

```yaml
structure:
  attention:
    goal: 'Capturar atenção'
    format: '[Declaração impactante ou pergunta]'
    example: 'R$100k/mês com Meta Ads é real?'

  interest:
    goal: 'Gerar interesse'
    format: '[Fato interessante ou história]'
    example: 'Nos últimos 6 meses, 347 alunos aplicaram o método...'

  desire:
    goal: 'Criar desejo'
    format: '[Benefícios + prova]'
    example: 'Imagine abrir o Ads Manager e ver ROAS 5x todos os dias...'

  action:
    goal: 'Chamar para ação'
    format: '[CTA claro + urgência]'
    example: 'Clica no link agora. Vagas limitadas.'

best_for:
  - 'Lançamentos'
  - 'Produtos aspiracionais'
  - 'Audiência fria'
```

### 3. BAB (Before-After-Bridge)

```yaml
structure:
  before:
    goal: 'Estado atual'
    format: 'Você está [situação atual]'
    example: 'Você investe em ads todo mês mas não consegue escalar...'

  after:
    goal: 'Estado desejado'
    format: 'Imagina [resultado ideal]'
    example: 'Imagine ter campanhas que rodam no automático gerando vendas todo dia...'

  bridge:
    goal: 'Conectar os dois'
    format: '[Produto] é o caminho'
    example: 'O Método X é exatamente o que você precisa para sair de A e chegar em B'

best_for:
  - 'Transformações claras'
  - 'Serviços e mentorias'
  - 'Público consciente da solução'
```

### 4. Story Framework

```yaml
structure:
  hook:
    goal: 'Prender atenção'
    format: '[Momento dramático ou resultado]'
    example: 'Eu estava prestes a desistir...'

  struggle:
    goal: 'Criar identificação'
    format: '[Desafios enfrentados]'
    example: 'Já tinha perdido R$30k em ads, minha esposa não acreditava mais...'

  discovery:
    goal: 'Introduzir solução'
    format: '[Como encontrou a resposta]'
    example: 'Até que descobri um padrão que mudou tudo...'

  transformation:
    goal: 'Mostrar resultado'
    format: '[Resultado específico]'
    example: 'Hoje faturo R$80k/mês com margem de 60%...'

  invitation:
    goal: 'Convidar para mesma jornada'
    format: '[CTA empático]'
    example: 'Quer que eu te mostre exatamente como fiz?'

best_for:
  - 'Personal branding'
  - 'High ticket'
  - 'Conexão emocional'
```

---

## Copy Elements

### Primary Text (125 chars visible + expanded)

```yaml
structure:
  visible_portion:
    max_chars: 125
    must_include:
      - 'Hook forte'
      - 'Promessa principal'
    note: "O que aparece antes do 'Ver mais'"

  expanded_portion:
    max_chars: 1000
    includes:
      - 'Desenvolvimento'
      - 'Prova'
      - 'CTA'
    note: "Só quem clica 'Ver mais' lê"

example:
  visible: |
    Faturar R$100k/mês com Meta Ads é mais simples do que parece.

    Nos últimos 6 meses, 347 alunos provaram isso...

  expanded: |
    E não, você não precisa:
    ❌ De milhares para começar
    ❌ De conhecimento técnico avançado
    ❌ De uma equipe grande

    O que você precisa é do MÉTODO certo.

    O mesmo método que usei para sair de R$0 para R$80k/mês em 8 meses.

    👇 Clica no link e descobre como
```

### Headline (40 chars max)

```yaml
purpose: 'Reforçar proposta de valor'
max_chars: 40
tips:
  - 'Benefício principal'
  - 'Números quando possível'
  - 'Curiosidade'

examples:
  - 'Meta Ads de R$0 a R$100k/mês'
  - 'O Método dos 7 Dias'
  - 'Seu negócio no próximo nível'
```

### Description (30 chars max)

```yaml
purpose: 'Suporte ao headline'
max_chars: 30
tips:
  - 'Urgência'
  - 'Prova social curta'
  - 'Benefício secundário'

examples:
  - 'Vagas limitadas'
  - '+500 alunos satisfeitos'
  - 'Acesso imediato'
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
    price: ''
    guarantee: ''

  audience:
    main_pain: ''
    main_desire: ''
    objections: []
    awareness_level: ''

  campaign:
    objective: ''
    temperature: 'cold|warm|hot'

  constraints:
    platform: 'meta|google|tiktok'
    format: 'primary_text|headline|description'
    variations: 3
```

### Output Structure

```yaml
copy_generation:
  product: 'Curso Meta Ads'
  framework: 'PAS'

  primary_text:
    variation_1:
      visible: ''
      expanded: ''
      word_count: 0
      char_count: 0

    variation_2:
      visible: ''
      expanded: ''

    variation_3:
      visible: ''
      expanded: ''

  headlines:
    - text: ''
      char_count: 0
    - text: ''
      char_count: 0
    - text: ''
      char_count: 0

  descriptions:
    - text: ''
      char_count: 0
    - text: ''
      char_count: 0
    - text: ''
      char_count: 0

  testing_recommendation:
    test_element: 'primary_text'
    keep_constant: ['headline', 'description', 'creative']
    methodology: 'Brandon Carter - Constants vs Variables'
```

---

## Integration

### Triggered By

- `creative-brief` - para copy do brief
- `hook-generator` - para body após hooks
- User command - `*generate-copy`

### Dispatches To

- `creative-brief` - se precisar brief visual

### Agent Assignment

- **Primary:** @creative-analyst
- **Reports to:** @media-strategist

---

## Usage Examples

```
*generate-copy "Curso Meta Ads" --framework pas

*generate-copy "Mentoria" --framework story --variations 5

*generate-copy --all-elements --product "Software X"
```

---

_Copy Generator Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
