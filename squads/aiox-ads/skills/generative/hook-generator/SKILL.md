# Hook Generator Skill

**ID:** `hook-generator`
**Category:** generative
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Gera variações de hooks para anúncios usando o DSL Revolution Framework de Jeremy Haynes e o método Constants vs Variables de Brandon Carter. Foco nos primeiros 3 segundos que determinam o sucesso do criativo.

**Activation Command:** `*generate-hooks {product}`
**Announce:** "Ativando Hook Generator com DSL Revolution e Constants vs Variables."

---

## Expert Sources

| Expert         | Framework                | Weight | Focus               |
| -------------- | ------------------------ | ------ | ------------------- |
| Jeremy Haynes  | DSL Revolution Framework | 0.95   | Estrutura de hooks  |
| Brandon Carter | Constants vs Variables   | 0.88   | Teste científico    |
| Jeremy Haynes  | Thumb Stop Metrics       | 0.90   | Métricas de atenção |
| Jordan Stupar  | Creative Concepts        | 0.85   | Ângulos criativos   |

---

## Hook Categories

### 1. Problema (Pain Point)

```yaml
description: 'Começa com a dor do público'
effectiveness: 'Alta para público consciente do problema'
examples:
  - 'Cansado de gastar com ads que não convertem?'
  - 'Frustrado com resultados inconsistentes?'
  - 'Não aguenta mais jogar dinheiro fora?'
structure: '[Emoção negativa] + [Problema específico] + ?'
```

### 2. Resultado (Outcome)

```yaml
description: 'Mostra transformação ou resultado'
effectiveness: 'Alta para prova social'
examples:
  - 'Faturei R$100k em 30 dias usando isso...'
  - 'De R$0 a R$50k/mês em 90 dias'
  - 'Saí de 0 vendas para 15 por dia'
structure: '[Resultado específico] + [Timeframe] + [Método implícito]'
```

### 3. Curiosidade (Open Loop)

```yaml
description: 'Gera curiosidade com loop aberto'
effectiveness: 'Alta para scroll-stopping'
examples:
  - 'O segredo que ninguém te conta sobre Meta Ads...'
  - 'Descobri isso depois de perder R$50k...'
  - 'A única coisa que mudou tudo foi...'
structure: '[Promessa de segredo/descoberta] + [Tema] + ...'
```

### 4. Controverso (Pattern Interrupt)

```yaml
description: 'Vai contra crença comum'
effectiveness: 'Muito alta para pattern interrupt'
examples:
  - 'Esqueça tudo que te ensinaram sobre tráfego...'
  - 'Lookalike é furada. Aqui está o porquê...'
  - 'CPM alto é BOM. Eu explico...'
structure: '[Negação de crença comum] + [Promessa de alternativa]'
```

### 5. Prova Social

```yaml
description: 'Usa prova social como gancho'
effectiveness: 'Alta para credibilidade'
examples:
  - '3.247 alunos já aplicaram esse método...'
  - 'Depois de ajudar +500 empresas, descobri...'
  - 'Nossos clientes faturam +R$10M/mês usando...'
structure: '[Número impressionante] + [Resultado/Ação]'
```

### 6. Tutorial (How-To)

```yaml
description: 'Promete ensinar algo específico'
effectiveness: 'Alta para conteúdo educativo'
examples:
  - 'Como criar anúncios que vendem em 3 passos...'
  - 'O passo a passo para escalar para R$10k/dia...'
  - 'Vou te mostrar exatamente como...'
structure: 'Como + [Resultado desejado] + [Simplicidade implícita]'
```

---

## Generation Process

### Step 1: Context Collection

```yaml
inputs:
  product:
    name: ''
    type: 'curso|serviço|físico|software'
    price_range: 'low|medium|high'
    main_benefit: ''
    target_audience: ''

  campaign:
    objective: 'awareness|consideration|conversion'
    current_hooks: [] # Para não repetir
    best_performer: '' # Para criar variações

  constraints:
    max_length: 15 # Palavras
    format: 'video|static|carousel'
    platform: 'feed|stories|reels'
```

### Step 2: Generation Matrix

```yaml
generation_rules:
  per_category: 2 # Hooks por categoria
  total_hooks: 12 # Mínimo
  variation_per_winner: 5 # Se tiver winner

  priority_by_stage:
    cold:
      - problema
      - curiosidade
      - controverso
    warm:
      - resultado
      - prova_social
      - tutorial
    hot:
      - resultado
      - prova_social
```

### Step 3: Scientific Testing Setup (Brandon Carter)

```yaml
testing_methodology:
  principle: 'Hook é VARIÁVEL, Body/CTA são CONSTANTES'

  test_structure:
    variable: 'Hook (primeiros 3 seg)'
    constants:
      - 'Body (explicação)'
      - 'CTA (chamada)'
      - 'Oferta'
      - 'Landing Page'

  test_execution:
    - 'Criar 5 ads com hooks diferentes'
    - 'Mesmo body, CTA, audiência'
    - 'Budget igual por ad'
    - 'Rodar 3-5 dias'
    - 'Winner = melhor CTR + Hook Rate'

  winner_iteration:
    - 'Criar 5 variações SIMILARES ao winner'
    - 'Mesmo ângulo, palavras diferentes'
    - 'Testar novamente'
    - 'Repetir até ótimo'
```

---

## Output Format

```yaml
hook_generation:
  product: 'Curso de Meta Ads'
  audience: 'Empreendedores digitais'
  generated_at: '2026-02-01'

  hooks:
    problema:
      - hook: 'Cansado de gastar com ads que não convertem?'
        length: 8
        emotion: 'frustração'
        cta_implicit: false

      - hook: 'Já perdeu dinheiro com tráfego pago?'
        length: 6
        emotion: 'medo'
        cta_implicit: false

    resultado:
      - hook: 'De R$0 a R$50k/mês em 90 dias com Meta Ads'
        length: 10
        specificity: 'alta'
        credibility: 'média'

      - hook: 'Meus alunos faturam +R$1M/mês juntos'
        length: 6
        social_proof: true

    curiosidade:
      - hook: 'O que ninguém te conta sobre escalar campanhas...'
        length: 8
        open_loop: true

      - hook: 'Descobri isso depois de gastar R$1M em ads...'
        length: 9
        story_hook: true

    controverso:
      - hook: 'Esqueça CBO. Aqui está o que realmente funciona...'
        length: 8
        pattern_interrupt: true

      - hook: 'Lookalike é armadilha. Provo em 60 segundos...'
        length: 7
        challenge: true

    prova_social:
      - hook: '+500 alunos já dominam Meta Ads com esse método'
        length: 8
        number: 500

      - hook: 'Depois de R$10M gerenciados, descobri o padrão...'
        length: 8
        authority: true

    tutorial:
      - hook: 'Como criar ads lucrativos em 3 passos simples'
        length: 8
        simplicity: '3 passos'

      - hook: 'O passo a passo que uso para escalar todo dia'
        length: 9
        practical: true

  testing_setup:
    recommended_winners: 5
    test_budget_per_hook: 'R$50-100'
    test_duration: '3-5 dias'
    success_metric: 'CTR + Hook Rate'

  expert_attribution:
    primary: 'Jeremy Haynes - DSL Revolution'
    testing: 'Brandon Carter - Constants vs Variables'
```

---

## Integration

### Triggered By

- `creative-fatigue-detector` - quando detecta fadiga
- `metric-diagnosis` - quando CTR baixo
- `campaign-monitor` - quando hook_rate < 15%
- User command - `*generate-hooks`

### Dispatches To

- `creative-brief` - para brief completo ao designer
- `copy-generator` - para body text

### Agent Assignment

- **Primary:** @creative-analyst
- **Reports to:** @media-strategist

---

## Usage Examples

```
*generate-hooks "Curso de Meta Ads"

*generate-hooks "Mentoria High Ticket" --categories resultado,prova_social

*generate-hooks --from-winner "Hook atual que funciona" --variations 10
```

### Sample Output

```
🎣 HOOK GENERATOR - Curso de Meta Ads

╔══════════════════════════════════════════════════════╗
║ 12 HOOKS GERADOS | 6 CATEGORIAS                      ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ 🔴 PROBLEMA                                          ║
║ 1. "Cansado de gastar com ads que não convertem?"   ║
║ 2. "Já perdeu dinheiro com tráfego pago?"           ║
║                                                      ║
║ 🟢 RESULTADO                                         ║
║ 3. "De R$0 a R$50k/mês em 90 dias"                  ║
║ 4. "Meus alunos faturam +R$1M/mês juntos"           ║
║                                                      ║
║ 🟡 CURIOSIDADE                                       ║
║ 5. "O que ninguém te conta sobre escalar..."        ║
║ 6. "Descobri isso depois de gastar R$1M..."         ║
║                                                      ║
║ 🟣 CONTROVERSO                                       ║
║ 7. "Esqueça CBO. Aqui está o que funciona..."       ║
║ 8. "Lookalike é armadilha. Provo em 60 seg..."      ║
║                                                      ║
║ 🔵 PROVA SOCIAL                                      ║
║ 9. "+500 alunos dominam Meta Ads com isso"          ║
║ 10. "Depois de R$10M gerenciados, descobri..."      ║
║                                                      ║
║ ⚪ TUTORIAL                                          ║
║ 11. "Como criar ads lucrativos em 3 passos"         ║
║ 12. "O passo a passo que uso para escalar"          ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ TESTE: R$50/hook × 5 hooks = R$250 por 3-5 dias     ║
║ MÉTODO: Brandon Carter - Constants vs Variables     ║
╚══════════════════════════════════════════════════════╝
```

---

_Hook Generator Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
