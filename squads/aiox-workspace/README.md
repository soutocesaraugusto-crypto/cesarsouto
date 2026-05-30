# Squad AIOX Workspace

Executivos estratégicos que estruturam o workspace da empresa.

## Conceito

O Squad AIOX Workspace nasceu da necessidade de ter um "dono" responsável por estruturar toda a informação da empresa dentro do AIOX. Não é um único profissional — é um squad composto por executivos AIOX Workspace, porque o trabalho cruza visão estratégica, operação, tecnologia e inteligência artificial simultaneamente.

**Suporta múltiplos negócios (businesses) dentro de um único workspace.**

## Composição

| Agent | Role | Tier | Responsabilidades |
|-------|------|------|-------------------|
| **COO** (workspace-chief) | Operations Orchestrator | Orchestrator | Líder do squad, coordena todos os Workspace executives, estrutura geral |
| **CEO** (vision-strategist) | Vision Strategist | 0 | Missão, visão, direção estratégica, DNA do fundador |
| **CMO** (cmo-architect) | Market Architect | 0 | ICP, brand, pricing, posicionamento |
| **CTO** (cto-architect) | Tech Architect | 1 | Estratégia tecnológica, arquitetura, roadmap |
| **CIO** (cio-engineer) | Infra Engineer | 1 | Tech stack, code standards, infraestrutura |
| **CAIO** (caio-architect) | Intelligence Architect | 1 | Estratégia de IA, modelos, orquestração |

## Dois Sistemas de Elicitação

O squad opera em **duas camadas coexistentes**:

```
Layer 1 (tech/dev):    *setup-workspace       → arquivos .md  (config técnica)
Layer 2 (business):    *setup-business-profile → arquivos .yaml (perfil completo)
```

| Aspecto | Layer 1 (.md) | Layer 2 (.yaml) |
|---------|---------------|-----------------|
| **Comando** | `*setup-workspace` | `*setup-business-profile {slug}` |
| **Output** | ~7 arquivos .md | 7 arquivos .yaml + sintetizados |
| **Campos** | ~91 campos narrativos | ~320+ campos estruturados |
| **Foco** | Config tech/dev | Perfil completo de negócio |
| **Tracking** | Nenhum | Completude por seção, gates de 85% |
| **Quando usar** | Setup de workspace técnico | Onboarding de negócio completo |

Ambas compartilham o mesmo `workspace/businesses/{slug}/`.

---

## Estrutura do Workspace

```
workspace/
├── user.md                              # Bootstrap
├── config.md                            # COO
│
├── businesses/
│   └── {slug}/
│       ├── company/                     # CMO + CEO
│       │   ├── mission-vision.md        # Layer 1 (CEO)
│       │   ├── icp.md                   # Layer 1 (CMO)
│       │   ├── brand.md                 # Layer 1 (CMO)
│       │   ├── value-proposition.md     # Layer 1 (CMO)
│       │   ├── elevator-pitch.md        # Layer 1 (CMO)
│       │   ├── founder-dna.yaml         # Layer 2 (CEO)
│       │   ├── credentials.yaml         # Layer 2 (CEO)
│       │   ├── company-profile.yaml     # Layer 2 (COO)
│       │   ├── brand.yaml               # Layer 2 (CMO)
│       │   ├── icp.yaml                 # Layer 2 (CMO)
│       │   ├── diagnosis.yaml           # Layer 2 (CMO)
│       │   ├── analytics.yaml           # Placeholder (dados internos)
│       │   └── authority-story.yaml     # Sintetizado (Fase 6)
│       │
│       ├── operations/                  # COO + CMO
│       │   ├── team-structure.yaml      # Layer 2 (COO)
│       │   ├── pricing-strategy.yaml    # Layer 2 (CMO)
│       │   ├── kpi-scorecards.yaml      # Placeholder (futuro)
│       │   └── commission-design.yaml   # Placeholder (futuro)
│       │
│       ├── products/                    # CMO + COO
│       │   └── {product-slug}/
│       │
│       ├── tech/                        # CTO + CIO
│       │   ├── strategy.md
│       │   ├── stack.md
│       │   ├── code_stand.md
│       │   └── infra.md
│       │
│       └── ai/                          # CAIO
│           ├── strategy.md
│           ├── models.md
│           └── agents.md
│
└── ui/                                  # Design system (transversal)
```

---

## Processos de Uso

### Processo 1: Novo Negócio Completo (recomendado)

O caminho completo para onboarding de um novo negócio, do zero ao perfil preenchido.

```bash
# 1. Ativar o COO
/aiox-workspace

# 2. Bootstrap (se ainda não fez)
*bootstrap

# 3. Preflight workspace-first (sempre recomendado)
*workspace-preflight
*workspace-context meu_negocio

# 4. Criar o negócio
*add-business meu_negocio

# 5. Pipeline completo de perfil (~210 perguntas, 6 fases)
*setup-business-profile meu_negocio
```

O pipeline roda em 6 fases com pause/resume:

```
FASE 0: Pre-Flight
  → Bootstrap + validate-workspace-essentials + workspace-context + scaffold templates

FASE 1: Formulário Básico (~15 min)
  → Dados básicos da empresa
  → Output: company-profile.yaml (parcial)
  → Gate: seção company_essence COMPLETE

FASE 2: Deep Dive Fundador (~40 min)
  → Entrevista profunda com Vision Chief
  → Output: founder-dna.yaml + credentials.yaml
  → Gate: founder-dna >= 85%

FASE 3: Empresa + Time (~30 min)
  → Completa company profile + estrutura de time
  → Output: company-profile.yaml (completo) + team-structure.yaml
  → Gate: company-profile >= 85%

FASE 4: ICP Completo (~30 min)
  → Deep dive ICP com CMO (inclui diagnosis gate)
  → Output: icp.yaml + diagnosis.yaml
  → Gate: icp >= 85%

FASE 5: Brand + Pricing (~25 min)
  → Brand guidelines + estratégia de preço
  → Output: brand.yaml + pricing-strategy.yaml
  → Gate: brand >= 85%

FASE 6: Enriquecimento (~10 min, automático)
  → Cross-references, authority-story, relatório
  → Output: authority-story.yaml + completeness-report
  → Gate: todos >= 85%
```

**Pause/Resume:** Responda "pausar" em qualquer gate. Ao rodar `*setup-business-profile` novamente, ele detecta YAMLs parciais e retoma de onde parou.

---

### Processo 2: Tasks Individuais

Para preencher ou atualizar um YAML específico sem rodar o pipeline completo.

```bash
# Ativar o COO
/aiox-workspace

# Preflight primeiro
*workspace-preflight
*workspace-context meu_negocio

# Scaffold em seguida (se ainda não fez)
*scaffold-templates meu_negocio

# Rodar task individual
*elicit-company-profile meu_negocio    # → company-profile.yaml
*elicit-founder-dna meu_negocio        # → founder-dna.yaml
*elicit-credentials meu_negocio        # → credentials.yaml
*elicit-team-structure meu_negocio     # → team-structure.yaml
*elicit-icp-yaml meu_negocio           # → icp.yaml
*elicit-brand-yaml meu_negocio         # → brand.yaml
*elicit-pricing-strategy meu_negocio   # → pricing-strategy.yaml
```

**Ordem recomendada** (dependências de contexto):

```
1. elicit-company-profile   (base — todo mundo lê este)
2. elicit-founder-dna       (usa company-profile como contexto)
3. elicit-credentials       (usa founder-dna como contexto)
4. elicit-icp-yaml          (usa company-profile, inclui diagnosis)
5. elicit-brand-yaml        (usa founder-dna + company-profile)
6. elicit-team-structure    (usa company-profile para headcount)
7. elicit-pricing-strategy  (usa icp + company-profile)
```

Cada task é idempotente — se o YAML já tem dados, ela pergunta se quer atualizar ou completar campos vazios.

---

### Processo 3: Setup Técnico (Layer 1)

Para workspace técnico de desenvolvimento — stack, standards, infra.

```bash
/aiox-workspace
*bootstrap
*add-business meu_negocio
*setup-workspace
```

Gera arquivos `.md` narrativos em `tech/`, `ai/`, `company/`. Coexiste com Layer 2.

---

### Processo 4: Atualizar Dados Existentes

Para atualizar um YAML já preenchido (ex: mudou o preço, contratou gente nova).

```bash
/aiox-workspace
*elicit-pricing-strategy meu_negocio
# O agente detecta dados existentes e pergunta: atualizar ou completar?
```

A task lê o YAML atual, apresenta um resumo, e pergunta o que fazer.

---

### Processo 5: Scaffold Apenas (sem elicitação)

Para preparar a estrutura sem responder perguntas ainda.

```bash
/aiox-workspace
*add-business meu_negocio
*scaffold-templates meu_negocio
```

Copia 12 templates YAML vazios para o diretório do negócio. Útil para revisar a estrutura antes de começar a preencher.

---

## Workspace Integration Governance

O squad `aiox-workspace` opera em `workspace_first`.

Antes de executar pipelines/tasks de elicitação:

```bash
bash squads/aiox-workspace/scripts/bootstrap-aiox-workspace.sh
bash squads/aiox-workspace/scripts/validate-workspace-essentials.sh
```

Ordem de leitura recomendada (context-first):

1. `workspace/config.yaml`
2. `workspace/user.yaml`
3. `workspace/config.yaml`
6. `workspace/_templates/company/*`
7. `workspace/_templates/operations/*`
8. `workspace/businesses/{slug}/company/*` e `operations/*` (quando existir)

Comandos COO para isso:

- `*workspace-preflight`
- `*workspace-context {slug}`

---

## Tabela de Comandos Completa

### Core

| Comando | Agent | Descrição |
|---------|-------|-----------|
| `*bootstrap` | COO | Inicializa workspace (OBRIGATÓRIO PRIMEIRO) |
| `*workspace-preflight` | COO | Executa bootstrap + validação de essenciais |
| `*workspace-context {slug}` | COO | Carrega snapshot do contexto do negócio |
| `*add-business {slug}` | COO | Adiciona novo negócio |
| `*scaffold-templates {slug}` | COO | Copia templates YAML para o negócio |
| `*status` | COO | Status do workspace |
| `*health-check` | COO | Auditoria completa de saúde |

### Pipeline Completo

| Comando | Agent | Output |
|---------|-------|--------|
| `*setup-workspace` | COO | Layer 1: arquivos .md (tech/dev) |
| `*setup-business-profile {slug}` | COO | Layer 2: 7 YAMLs (business profile) |

### Elicitações Layer 1 (.md)

| Comando | Agent | Output |
|---------|-------|--------|
| `*elicit-vision` | CEO | mission-vision.md |
| `*elicit-icp` | CMO | icp.md |
| `*elicit-brand` | CMO | brand.md |
| `*elicit-tech-strategy` | CTO | tech/strategy.md |
| `*elicit-tech-stack` | CIO | tech/stack.md |
| `*elicit-ai-strategy` | CAIO | ai/strategy.md |

### Elicitações Layer 2 (.yaml)

| Comando | Agent | Output | Perguntas |
|---------|-------|--------|-----------|
| `*elicit-company-profile {slug}` | COO | company-profile.yaml | ~30 |
| `*elicit-founder-dna {slug}` | CEO | founder-dna.yaml | ~35 |
| `*elicit-credentials {slug}` | CEO | credentials.yaml | ~40 |
| `*elicit-team-structure {slug}` | COO | team-structure.yaml | ~20 |
| `*elicit-icp-yaml {slug}` | CMO | icp.yaml | ~35 |
| `*elicit-brand-yaml {slug}` | CMO | brand.yaml | ~25 |
| `*elicit-pricing-strategy {slug}` | CMO | pricing-strategy.yaml | ~25 |

### Produto

| Comando | Descrição |
|---------|-----------|
| `*add-product {business} {slug}` | Adiciona produto a um negócio |

---

## Convenções dos YAMLs

### Status por Seção

Cada seção do YAML tem um campo `status`:
- `COMPLETE` — todos os campos preenchidos
- `INCOMPLETE` — ainda tem campos vazios

### Completude

```yaml
metadata:
  completed_fields: 89
  completeness_percentage: 87
  status: "INCOMPLETE"
```

### Gates

- **< 85%**: Bloqueado no pipeline (pode continuar individual)
- **>= 85%**: Aprovado para prosseguir
- **100%**: Todos os claims podem ser validados contra analytics

### Campos Não Respondidos

- Campos sem resposta ficam como `null`
- Placeholders originais (`FILL_THIS`, `YOUR_VERSION`) são substituídos

---

## Tier System

```
ORCHESTRATOR: workspace-chief
├── Coordena todos os executivos
├── Executa: company-profile, team-structure, scaffold, pipeline
└── Dono do workspace

TIER 0 (Foundation):
├── vision-strategist (CEO) - founder-dna, credentials, mission/vision
└── cmo-architect (CMO) - icp, brand, pricing, posicionamento

TIER 1 (Technical):
├── cto-architect (CTO) - Tech strategy
├── cio-engineer (CIO) - Tech operations
└── caio-architect (CAIO) - AI strategy
```

---

## Fluxo de Dados entre YAMLs

```
company-profile.yaml ─────────────────────────────┐
   ↓ (contexto para todos)                        │
founder-dna.yaml ──────────┐                       │
   ↓                       │                       │
credentials.yaml ──────────┼── authority-story.yaml │
                           │   (sintetizado)       │
icp.yaml ←── diagnosis.yaml                       │
   ↓                                               │
brand.yaml ←── founder-dna (personalidade)         │
   ↓                                               │
pricing-strategy.yaml ←── icp + company-profile    │
   ↓                                               │
team-structure.yaml ←── company-profile (headcount)│
                                                   │
completeness-report ←── todos os 7 YAMLs ─────────┘
```

---

*Squad AIOX Workspace v2.0.0*
*Updated: 2026-02-24*
*Layers: 2 (tech/dev .md + business profile .yaml)*
