# Task: Resolve Squad Workspace Readiness

```yaml
task:
  id: resolve-squad-workspace-readiness
  name: Resolver Readiness de Workspace por Squad
  agent: workspace-chief
  elicit: false
```

## Descrição

Task canônica do `COO` para decidir se um squad consumidor pode operar com contexto suficiente de `workspace/`.

## Objetivo

1. Resolver readiness por `squad`.
2. Normalizar o resultado para um contrato único.
3. Bloquear, permitir draft ou liberar output final conforme as fontes canônicas disponíveis.

## Inputs

- `squad_slug`
- `business_slug`
- `product_slug`
- `app_id`
- `context_type`

## Contrato

Executar:

```bash
node squads/aiox-workspace/scripts/resolve-squad-workspace-readiness.cjs --squad={slug} [--business={slug}] [--product={slug}] [--app={id}] [--context-type={type}]
```

Regra adicional:

- quando `--product` for informado, `--business` também é obrigatório
- o resolver não deve assumir um business default implícito

Status válidos:

- `ready`
- `draft`
- `blocked`
- `read_only`
- `not_applicable`

Saída mínima:

```yaml
owner: workspace-chief
squad_slug: string
context_type: string
status: ready|draft|blocked|read_only|not_applicable
reason: string
required_sources_loaded: []
missing_required_sources: []
allowed_write_paths: []
canonical_config_paths: []
```

## Regras

1. `design` usa contexto `design_system`.
2. `brand` usa contexto `brand`.
3. `copy` e `hormozi` usam contexto `product`.
4. `aiox-sop` e `squad-creator-pro` usam contexto `operations`.
5. O registry canônico de squads, contexts e product consumers vive em `squads/aiox-workspace/config.yaml`.
6. O resolver do COO delega aos resolvers canônicos já existentes; não duplica regras locais.
7. `draft` permite exploração, mas não output final/canônico.
8. `blocked` interrompe a execução até corrigir as fontes faltantes.
9. `not_applicable` proíbe tratar ausência de setup como erro.

## Validação

- [ ] Resolver executa sem inventar pré-requisitos.
- [ ] Saída inclui `status`, `reason` e fontes faltantes.
- [ ] O squad consumidor consegue bloquear ou degradar para draft com base na saída.

---

*Task do Squad AIOX Workspace - COO Orchestrator*
