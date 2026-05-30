# Task: Classify Squad Workspace Fit

```yaml
task:
  id: classify-squad-workspace-fit
  name: Classificar Encaixe de um Squad com Workspace
  agent: workspace-chief
  elicit: false
```

## Descrição

Task canônica do `COO` para decidir se um squad:

1. deve ter contrato próprio com `workspace/`
2. deve apenas consumir contexto sob gate do `COO`
3. deve permanecer fora de `workspace/`

Esta task acontece **antes** de qualquer wiring de runtime, bootstrap, validator ou handoff operacional.

## Objetivo

1. Classificar o papel estrutural do squad no ecossistema.
2. Evitar integrações oportunistas ou acidentais com `workspace/`.
3. Definir o nível alvo correto: `workspace_first`, `controlled_runtime_consumer`, `read_only` ou `none`.
4. Registrar se a integração é `consulting-only`, isto é, só válida quando `squads/aiox-workspace/` está presente.
5. Decidir se os artefatos do squad são específicos do domínio ou compartilhados com outros squads.

## Quando usar

- criação de novo squad
- revisão de squad legado
- fusão de squads
- qualquer pedido para “ligar um squad ao workspace”
- auditoria global de governança

## Inputs

- `squad_slug`
- `squad_config_path`
- `evidence_paths[]`
- `current_workspace_integration` (se existir)

## Perguntas de decisão

### 1. O squad depende de artefato canônico de negócio/produto?

Exemplos:

- `workspace/businesses/{slug}/company/*`
- `workspace/businesses/{slug}/products/*`
- `workspace/businesses/{slug}/design-system/*`
- `workspace/businesses/{slug}/analytics/*`

Se **não**, o default é `none`.

### 2. O output primário do squad precisa viver canonicamente em `workspace/`?

Se **sim**, o alvo tende a ser `workspace_first`.

Exemplos:

- brand system da BU
- analytics da BU
- movement canonizado por business
- franchise package por business

### 3. O squad só precisa de contexto canônico para operar, mas seu output principal vive fora do `workspace/`?

Se **sim**, o alvo tende a ser `controlled_runtime_consumer`.

Exemplos:

- squads que precisam de ICP/oferta/produto/DS para operar com qualidade
- mas publicam runtime, docs operacionais, assets ou configurações externas

### 4. O squad só lê `workspace/` para seeding, scaffolding ou descoberta?

Se **sim**, o alvo tende a ser `read_only`.

### 5. O squad é ferramental, genérico, self-contained ou orientado a infraestrutura externa?

Se **sim**, o alvo tende a ser `none`.

Exemplos:

- research
- tooling
- security
- database ops
- theme/core system
- creative production

### 6. O artefato é compartilhado por vários squads?

Se **sim**, o artefato não deve nascer em `squads/{slug}/templates/` nem em namespace exclusivo do squad.

Use namespace compartilhado em `workspace/_templates/` quando:

- o mesmo artefato serve para `copy` + `storytelling` + `traffic-masters`
- ou quando `franchise` reutiliza artefatos narrativos comuns de produto/oferta

Exemplo recomendado:

- `workspace/_templates/product-narrative/`

Regra de instanciacao:

- company-wide -> `workspace/businesses/{business}/company/`
- product-specific -> `workspace/businesses/{business}/products/{product}/narrative/`
- franchise-specific -> `workspace/businesses/{business}/franchise/narrative/`

## Matriz de classificação

| Caso | Target |
|------|--------|
| Produz artefato canônico de business | `workspace_first` |
| Consome contexto canônico sob gate do COO, sem ser owner do namespace | `controlled_runtime_consumer` |
| Lê contexto para scaffolding/integração, sem gate final próprio | `read_only` |
| Não depende estruturalmente de `workspace/` | `none` |

## Regras

1. `workspace_first` e `controlled_runtime_consumer` são **consulting-only**.
2. Se `squads/aiox-workspace/` não existe, nenhum squad novo pode ser promovido para esses dois níveis.
3. `read_write` é proibido como categoria geral.
4. Manifesto sem `workspace_integration.level` explícito é estado inválido.
5. Se um squad legado duplica outro que já governa o mesmo namespace, a decisão correta pode ser:
   - consolidar
   - descontinuar
   - ou manter sem contrato próprio
6. Se um artefato for compartilhado entre vários squads, o owner é o `COO` e o template deve morar em namespace comum.

## Procedimento

### Fase 1: Ler contrato atual

- abrir `config.yaml` e/ou `squad.yaml`
- identificar `workspace_integration` atual
- mapear scripts, tasks e docs que citam `workspace/`

### Fase 2: Mapear dependência estrutural

Responder:

- o squad precisa de business context?
- precisa de product context?
- precisa de design system context?
- escreve artefato canônico ou apenas output operacional?
- o output poderia existir sem `workspace/`?
- existe artefato compartilhado que já resolve o caso sem criar template novo?

### Fase 3: Classificar

Emitir:

```yaml
squad_slug: "{slug}"
recommended_target: workspace_first|controlled_runtime_consumer|read_only|none
consulting_only: true|false
owner: workspace-chief
rationale: "{why}"
canonical_inputs:
  - path
canonical_outputs:
  - path
should_integrate: true|false
decision:
  status: approved|defer|reject|consolidate
  next_step: "{what happens now}"
shared_artifacts:
  - artifact: "{name}"
    template_path: "workspace/_templates/{namespace}/{file}.yaml"
    save_scope: company|product|franchise
    output_path: "{canonical path}"
```

### Fase 4: Planejar rollout

Se `approved`:

- definir bootstrap/validator/runtime necessários
- definir se precisa resolver readiness do COO
- abrir story/epic wave para implementação
- separar artefatos compartilhados em namespace comum antes de criar templates do squad

Se `consolidate`:

- apontar squad owner canônico
- bloquear criação de contrato paralelo

## Backlog Atual Priorizado

### Próximos candidatos que fazem sentido integrar

1. `storytelling`
   - target aprovado: `controlled_runtime_consumer`
   - motivo: depende de brand/produto/mensagem canônicos, mas o output principal é narrativo

### Caso de consolidação

1. `ds`
   - decisão recomendada: `consolidate`
   - owner canônico: `design`

### Já formalizado

1. `franchise`
   - target aprovado: `workspace_first`
   - referência: `WSIG.10`

2. `traffic-masters`
   - target aprovado: `controlled_runtime_consumer`
   - referência: `WSIG.11`

## Checklist relacionado

- `squads/aiox-workspace/checklists/squad-workspace-fit-checklist.md`

## Validação

- [ ] O squad foi classificado com um target explícito.
- [ ] A justificativa cita dependência real de business/produto/DS.
- [ ] A decisão respeita a regra consulting-only para níveis avançados.
- [ ] Não há duplicação de ownership com outro squad já canônico.

---

*Task do Squad AIOX Workspace - COO Orchestrator*
