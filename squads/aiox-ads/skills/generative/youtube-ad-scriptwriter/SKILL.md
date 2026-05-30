# YouTube Ad Scriptwriter Skill

**ID:** `youtube-ad-scriptwriter`
**Category:** generative
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Gera scripts completos para YouTube Ads com timing por secao (7 partes), aplica a 5-Second Hook Formula especifica para YouTube e valida o Relevance Triangle entre ad group, conteudo do ad e landing page.

**Activation Command:** `*youtube-script`
**Announce:** "Ativando YouTube Ad Scriptwriter com 7-Part Script Structure e 5-Second Hook Formula."

---

## Expert Sources

| Expert        | Framework                   | Weight | Focus                         |
| ------------- | --------------------------- | ------ | ----------------------------- |
| Brian Moncada | 7-Part YouTube Ad Script    | 0.95   | Script completo com timing    |
| Brian Moncada | 5-Second Hook Formula       | 0.92   | Hook especifico YouTube       |
| Brian Moncada | YouTube Relevance Triangle  | 0.88   | Alinhamento ad-audience       |

---

## 7-Part Script Structure

### Script Architecture

```
YOUTUBE AD SCRIPT TIMELINE

0s          5s         15s         30s         45s         60s         90s        120s
|-----------|----------|-----------|-----------|-----------|-----------|----------|
|   HOOK    | PROBLEM  | SOLUTION  |CREDIBILITY|   PROOF   |   OFFER   |   CTA    |
| (0-5s)    | (5-15s)  | (15-30s)  | (30-45s)  | (45-60s)  | (60-90s)  | (90-120s)|
|           |          |           |           |           |           |          |
| Captura   | Amplifica| Apresenta | Estabelece| Mostra    | Detalha   | Acao     |
| atencao   | a dor    | saida     | autoridade| resultados| a oferta  | clara    |
|-----------|----------|-----------|-----------|-----------|-----------|----------|

NOTA: Timing ajusta conforme objetivo (ver SE/ENTAO rules)
```

### Part-by-Part Breakdown

```yaml
script_parts:
  1_hook:
    timing: '0-5 segundos'
    purpose: 'Capturar atencao antes do SKIP'
    format: 'Verbal + Visual (YouTube hooks sao multimodais)'
    critical: true
    note: 'O viewer decide em 5s se vai assistir ou pular'
    elements:
      verbal: 'Frase de impacto ou pergunta'
      visual: 'Corte rapido, texto na tela, movimento'
      audio: 'Tom energetico, musica de impacto'

  2_problem:
    timing: '5-15 segundos'
    purpose: 'Amplificar a dor que o viewer sente'
    format: 'Descrever situacao dolorosa com especificidade'
    elements:
      verbal: 'Voce provavelmente esta [situacao]...'
      visual: 'B-roll de frustacao, graficos negativos'
      connection: 'O viewer precisa pensar "isso sou eu"'

  3_solution:
    timing: '15-30 segundos'
    purpose: 'Apresentar a saida (mecanismo unico)'
    format: 'Introduzir metodo/framework/sistema'
    elements:
      verbal: 'Existe um metodo que [resolve]...'
      visual: 'Diagrama, framework visual, transicao positiva'
      note: 'Nao vender ainda, apenas apresentar que existe uma saida'

  4_credibility:
    timing: '30-45 segundos'
    purpose: 'Estabelecer autoridade e confianca'
    format: 'Quem voce e, porque devem ouvir voce'
    elements:
      verbal: 'Meu nome e [X], nos ultimos [Y] anos...'
      visual: 'Logos de clientes, screenshots, certificacoes'
      variants:
        - 'Resultados pessoais'
        - 'Resultados de clientes'
        - 'Credenciais e experiencia'
        - 'Media mentions'

  5_proof:
    timing: '45-60 segundos'
    purpose: 'Mostrar resultados concretos (prova social)'
    format: 'Numeros, depoimentos, cases'
    elements:
      verbal: '[Numero] de [pessoas] conseguiram [resultado]...'
      visual: 'Screenshots, graficos, video depoimentos'
      types:
        - 'Numeros agregados (500+ alunos, R$10M gerenciados)'
        - 'Case study especifico (de X para Y em Z tempo)'
        - 'Depoimento (video ou texto com foto)'

  6_offer:
    timing: '60-90 segundos'
    purpose: 'Detalhar o que estao recebendo'
    format: 'Stack de valor com preco'
    elements:
      verbal: 'Quando voce entra, voce recebe...'
      visual: 'Lista de beneficios, mockups, valor vs preco'
      structure:
        - 'Beneficio 1 (valor R$X)'
        - 'Beneficio 2 (valor R$X)'
        - 'Beneficio 3 (valor R$X)'
        - 'Bonus (valor R$X)'
        - 'Total: R$XX.XXX por apenas R$X.XXX'

  7_cta:
    timing: '90-120 segundos'
    purpose: 'Acao clara e urgencia'
    format: 'O que fazer agora + porque agora'
    elements:
      verbal: 'Clica no link abaixo/no botao agora...'
      visual: 'Seta para link, botao destacado, countdown'
      urgency:
        - 'Vagas limitadas'
        - 'Preco sobe em [data]'
        - 'Bonus exclusivo para quem entra hoje'
      note: 'Repetir CTA 2x (inicio e fim da secao)'
```

---

## SE/ENTAO Rules

```
SE objetivo = awareness
  ENTAO script 30-60s (TrueView InStream)
  ESTRUTURA: Hook (5s) + Problem (10s) + Solution (15s) + CTA (10s)
  PULAR: Credibility e Proof (nao ha tempo)

SE objetivo = conversao
  ENTAO script 90-120s (formato completo, 7 partes)
  ESTRUTURA: Todas as 7 partes com timing padrao

SE produto high-ticket (>R$2000)
  ENTAO incluir secao Proof estendida (+30s)
  RAZAO: High-ticket exige mais prova social para converter
  TIMING: Proof vira 45-90s (ao inves de 45-60s)

SE remarketing (viewer ja conhece)
  ENTAO skip Problem, direto para Offer
  ESTRUTURA: Hook (5s) + Offer (15s) + CTA (10s) = 30s total
  RAZAO: Viewer ja conhece o problema e a solucao

SE Relevance Triangle quebrado (ad != LP)
  ENTAO reescrever script antes de publicar
  RAZAO: Mismatch ad-LP destroi Quality Score e conversao
```

---

## 5-Second Hook Formula

### Hook Types

```yaml
hook_types:
  1_question:
    format: 'Pergunta direta sobre a dor'
    example: 'Voce ainda luta para conseguir clientes online?'
    best_for: 'Audiencia consciente do problema'
    visual: 'Close-up no rosto, expressao de curiosidade'

  2_statistic:
    format: 'Numero impactante + implicacao'
    example: '97% dos anuncios no YouTube sao ignorados. Aqui esta o porque...'
    best_for: 'Audiencia analitica, B2B'
    visual: 'Numero grande na tela, animacao'

  3_contrarian:
    format: 'Desafiar crenca comum'
    example: 'Pare de gastar com Google Ads agora mesmo. Serio.'
    best_for: 'Audiencia experiente, pattern interrupt'
    visual: 'Gesto de "pare", expressao seria'

  4_story:
    format: 'Inicio de narrativa pessoal'
    example: 'Eu estava quebrado, com R$47 na conta, quando descobri...'
    best_for: 'Personal branding, high-ticket'
    visual: 'Ambiente informal, olhar na camera'

  5_curiosity:
    format: 'Revelar algo inesperado'
    example: 'O truque estranho que triplicou minhas vendas em 30 dias...'
    best_for: 'Broad audience, cold traffic'
    visual: 'Expressao de surpresa, tela com resultado'

  6_direct:
    format: 'Ir direto ao ponto'
    example: 'Se voce quer escalar seu negocio para 7 digitos, assista isto.'
    best_for: 'Audiencia com alta intent, remarketing'
    visual: 'Olhar direto na camera, tom confiante'
```

### Hook Variant Generation

```
HOOK VARIANT GENERATION FLOW

Para cada script body:
    |
    +-- Gerar 3-5 hooks diferentes
    |   |
    |   +-- Hook 1: Question (mais seguro)
    |   +-- Hook 2: Contrarian (pattern interrupt)
    |   +-- Hook 3: Statistic (credibilidade)
    |   +-- Hook 4: Story (conexao emocional)
    |   +-- Hook 5: Direct (high-intent)
    |
    +-- Testar todos com mesmo body
    |
    +-- Medir View Rate por hook (>20% = bom)
    |
    +-- Escalar winner, matar losers em 24-48h
```

---

## Relevance Triangle

```
YOUTUBE RELEVANCE TRIANGLE (Brian Moncada)

              Ad Group Keywords
                   /\
                  /  \
                 /    \
                / MATCH \
               / REQUIRED\
              /    ALL    \
             /    THREE    \
            /________________\
    Ad Content ----MATCH---- Landing Page

REGRA: Os tres vertices DEVEM estar alinhados.

Exemplo CORRETO:
  Keywords: "mentoria para empresarios"
  Ad Script: Fala sobre mentoria para empresarios
  LP: Headline = "Mentoria para Empresarios"

Exemplo INCORRETO:
  Keywords: "mentoria para empresarios"
  Ad Script: Fala sobre curso de marketing digital
  LP: Pagina generica de servicos

SE qualquer par esta desalinhado --> REESCREVER antes de publicar
```

---

## Process

### Step 1: Define Objective

```yaml
inputs:
  objective: 'awareness | consideration | conversion'
  product:
    name: ''
    ticket: 0
    unique_mechanism: ''
    guarantee: ''
  audience:
    temperature: 'cold | warm | hot'
    main_pain: ''
    main_desire: ''
    awareness_level: 'unaware | problem_aware | solution_aware | product_aware'
  campaign:
    format: 'trueview_instream | bumper | discovery'
    targeting: ''
```

### Step 2: Select Hook Type

```yaml
hook_selection:
  cold_traffic:
    recommended: ['question', 'curiosity', 'statistic']
    avoid: ['direct']
    reason: 'Cold precisa de pattern interrupt'

  warm_traffic:
    recommended: ['story', 'contrarian', 'statistic']
    avoid: []
    reason: 'Warm ja tem alguma familiaridade'

  hot_traffic:
    recommended: ['direct', 'story']
    avoid: ['question']
    reason: 'Hot ja sabe o problema, quer solucao'
```

### Step 3: Write 7-Part Script

```yaml
writing_process:
  1: 'Escrever Section 2 (Problem) primeiro -- ancora todo o script'
  2: 'Escrever Section 3 (Solution) -- resposta direta ao problema'
  3: 'Escrever Sections 4-5 (Credibility + Proof) -- build trust'
  4: 'Escrever Section 6 (Offer) -- stack de valor'
  5: 'Escrever Section 7 (CTA) -- acao clara'
  6: 'Escrever Section 1 (Hook) POR ULTIMO -- hook e derivado do script'
  note: 'Escrever hook por ultimo garante que ele conecta com o corpo'
```

### Step 4: Generate Hook Variants

```yaml
variant_generation:
  quantity: '3-5 hooks por script'
  types: 'Usar pelo menos 3 tipos diferentes'
  format:
    per_variant:
      verbal: 'O que o presenter fala'
      visual: 'O que aparece na tela'
      timing: '0-5 segundos'
  testing:
    method: 'Mesmo body, hooks diferentes'
    kill_criteria: 'View Rate < 15% em 48h'
    scale_criteria: 'View Rate > 25%'
```

### Step 5: Validate Relevance Triangle

```yaml
validation_checklist:
  keyword_to_ad:
    check: 'Keywords do ad group aparecem no script?'
    fix: 'Incluir keywords primarios no hook e problem sections'

  ad_to_lp:
    check: 'Promessa do script = headline da LP?'
    fix: 'Alinhar LP headline com offer section do script'

  keyword_to_lp:
    check: 'Keywords do ad group aparecem na LP?'
    fix: 'Incluir keywords no H1, meta title e body da LP'

  verdict:
    pass: 'Todos os tres pares alinhados'
    fail: 'Qualquer par desalinhado -> reescrever antes de publicar'
```

---

## Output Format

```yaml
youtube_ad_script:
  product: 'Mentoria Empresarial'
  objective: 'conversion'
  total_duration: '120 segundos'
  format: 'TrueView InStream'
  generation_date: '2026-03-16'

  script:
    hook:
      timing: '0-5s'
      verbal: 'Voce sabia que 83% dos empresarios nunca passam de R$50k/mes? Vou te mostrar o que os outros 17% fazem diferente.'
      visual: 'Close-up, numero 83% na tela, expressao seria'
      type: 'statistic'

    problem:
      timing: '5-15s'
      verbal: 'Voce trabalha 12h por dia, investe em marketing, contrata equipe... mas o faturamento nao sai do lugar. Cada mes parece uma luta. E o pior: voce nao sabe exatamente o que esta errado.'
      visual: 'B-roll de escritorio, graficos estagnados, expressao de frustracao'

    solution:
      timing: '15-30s'
      verbal: 'Existe um metodo chamado Escala Inteligente que identifica os 3 gargalos do seu negocio e cria um plano de acao especifico para destrava-los. Nao e teoria -- e um framework testado com mais de 500 empresarios.'
      visual: 'Diagrama do framework, animacao dos 3 gargalos, transicao positiva'

    credibility:
      timing: '30-45s'
      verbal: 'Meu nome e [Nome]. Nos ultimos 8 anos, ajudei mais de 500 empresarios a escalar de 5 para 7 digitos. Ja fui mentorado por [referencia] e meu metodo foi validado em [X] nichos diferentes.'
      visual: 'Logos de clientes, screenshots de resultados, certificacoes'

    proof:
      timing: '45-60s'
      verbal: 'O Carlos chegou com faturamento de R$40k/mes. Em 90 dias de mentoria, ele bateu R$127k -- e nao parou. Hoje esta em R$200k/mes com margem de 45%. E o Carlos nao e excecao.'
      visual: 'Foto do Carlos, grafico de crescimento, depoimento em video'

    offer:
      timing: '60-90s'
      verbal: 'Quando voce entra na Mentoria Escala Inteligente, voce recebe: diagnostico completo do seu negocio, plano de acao personalizado, 12 sessoes 1:1 comigo, acesso a comunidade de empresarios e garantia incondicional de 30 dias.'
      visual: 'Stack visual de beneficios, mockup do material, preco com ancora'

    cta:
      timing: '90-120s'
      verbal: 'Clica no link aqui embaixo ou no botao nesta tela. Agenda uma sessao estrategica gratuita de 30 minutos. Sem compromisso. Eu vou pessoalmente analisar seu negocio e te mostrar os gargalos. Vagas limitadas -- clica agora.'
      visual: 'Seta para link, botao destacado, "Vagas Limitadas" na tela'

  hook_variants:
    variant_1:
      type: 'question'
      verbal: 'Voce sabe qual e o maior gargalo do seu negocio agora? A maioria dos empresarios nao sabe -- e por isso nao escala.'
      visual: 'Close-up, expressao de curiosidade, "?" na tela'

    variant_2:
      type: 'contrarian'
      verbal: 'Pare de investir em marketing agora. Serio. Se voce nao resolver ISSO primeiro, mais trafego so vai amplificar seus problemas.'
      visual: 'Gesto de "pare", expressao seria, texto "PARE" na tela'

    variant_3:
      type: 'story'
      verbal: 'Dois anos atras eu estava prestes a fechar minha empresa. Faturamento caindo, equipe desmotivada. Ate que descobri uma coisa...'
      visual: 'Ambiente informal, olhar na camera, tom vulneravel'

    variant_4:
      type: 'direct'
      verbal: 'Se voce fatura entre R$30k e R$100k por mes e quer chegar a R$300k, este video e pra voce. Preste atencao.'
      visual: 'Olhar direto na camera, fundo limpo, tom autoritativo'

  relevance_triangle:
    keywords: ['mentoria empresarial', 'escalar negocio', 'coaching para empresarios']
    ad_alignment: 'Script fala sobre mentoria para escalar negocio'
    lp_alignment: 'LP headline: Mentoria Empresarial para Escalar seu Negocio'
    verdict: 'PASS - Triangulo alinhado'

  testing_plan:
    method: 'Mesmo body, 4 hooks diferentes'
    budget_per_hook: 'R$50/dia'
    test_duration: '48-72h'
    kill_metric: 'View Rate < 15%'
    scale_metric: 'View Rate > 25% + CPA < target'

  expert_attribution:
    script_structure: 'Brian Moncada - 7-Part YouTube Ad Script'
    hooks: 'Brian Moncada - 5-Second Hook Formula'
    alignment: 'Brian Moncada - YouTube Relevance Triangle'
```

---

## Integration

### Triggered By

- User command - `*youtube-script`
- `creative-brief` - quando platform=youtube
- `youtube-campaign-launcher` - quando precisa de scripts para campanhas

### Dispatches To

- `creative-brief` - para producao do video
- `youtube-campaign-launcher` - script pronto para campanha
- `ad-compliance-gate` - validacao pre-publish

### Agent Assignment

- **Primary:** @tom-breeze
- **Support:** @creative-analyst (revisao de copy)
- **Escalation:** @ad-midas (decisoes de posicionamento)

---

## Usage Examples

```
*youtube-script "Mentoria Empresarial" --objective conversion --ticket 5000

*youtube-script --objective awareness --duration 30s

*youtube-script "Curso de Ads" --remarketing --short

*youtube-script "SaaS Product" --hooks-only --quantity 5
```

### Sample Output

```
YOUTUBE AD SCRIPTWRITER

+======================================================+
| PRODUTO: Mentoria Empresarial                         |
| OBJETIVO: Conversao | DURACAO: 120s | HOOKS: 4       |
+======================================================+
|                                                       |
| SCRIPT STRUCTURE (7 Parts)                            |
|                                                       |
| [0-5s] HOOK (statistic)                               |
| "83% dos empresarios nunca passam de R$50k/mes..."    |
|                                                       |
| [5-15s] PROBLEM                                       |
| "Voce trabalha 12h/dia mas o faturamento..."          |
|                                                       |
| [15-30s] SOLUTION                                     |
| "Metodo Escala Inteligente identifica 3 gargalos..."  |
|                                                       |
| [30-45s] CREDIBILITY                                  |
| "8 anos, 500+ empresarios, 5 a 7 digitos..."         |
|                                                       |
| [45-60s] PROOF                                        |
| "Carlos: R$40k --> R$127k em 90 dias..."              |
|                                                       |
| [60-90s] OFFER                                        |
| "Diagnostico + Plano + 12 sessoes + Comunidade..."    |
|                                                       |
| [90-120s] CTA                                         |
| "Clica no link, agenda sessao gratuita..."            |
|                                                       |
+-------------------------------------------------------+
| HOOK VARIANTS                                         |
|                                                       |
| V1 (question): "Qual e o maior gargalo...?"          |
| V2 (contrarian): "Pare de investir em marketing..."  |
| V3 (story): "Dois anos atras, prestes a fechar..."   |
| V4 (direct): "Se voce fatura R$30-100k/mes..."       |
|                                                       |
+-------------------------------------------------------+
| RELEVANCE TRIANGLE: PASS                              |
| Keywords <-> Ad <-> LP: Alinhados                     |
+-------------------------------------------------------+
| EXPERT: Brian Moncada - 7-Part YouTube Ad Script     |
+======================================================+
```

---

_YouTube Ad Scriptwriter Skill v1.0.0_
_AIOX Ads Squad - AIOS Synkra_
