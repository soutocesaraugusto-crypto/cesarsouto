# Task: Setup Workspace

```yaml
task:
  id: setup-workspace
  name: Setup Completo do Workspace
  agent: workspace-chief
  elicit: true
```

## Descricao

O COO orquestra o setup completo do workspace para um negocio especifico, garantindo que todos os outputs vao para YAMLs canonicos com template previo.

## Pre-requisitos

- Bootstrap executado (`workspace/user.yaml` existe)
- Negocio criado (`workspace/businesses/{slug}/` existe)
- Preflight workspace-first aprovado:
  - `bash squads/aiox-workspace/scripts/bootstrap-aiox-workspace.sh`
  - `bash squads/aiox-workspace/scripts/validate-workspace-essentials.sh`

## Usage

```bash
*setup-workspace {slug}
```

## Workflow

### Fase 1: Contexto e Preflight

1. Executar scripts de preflight.
2. Executar `*workspace-context {slug}` (`load-workspace-context.md`).
3. Garantir scaffold template-first (`*scaffold-templates {slug}`) antes de qualquer escrita.

### Fase 2: Orquestracao por AIOX Workspace

```yaml
execution_order:
  - agent: workspace-chief
    task: elicit-company-profile
    output: workspace/businesses/{slug}/company/company-profile.yaml

  - agent: cmo-architect
    task: elicit-icp-yaml
    output: workspace/businesses/{slug}/company/icp.yaml

  - agent: cmo-architect
    task: elicit-brand-yaml
    output: workspace/businesses/{slug}/company/brand.yaml

  - agent: cto-architect
    task: elicit-tech-strategy
    output: workspace/businesses/{slug}/tech/strategy.yaml

  - agent: cio-engineer
    task: elicit-tech-stack
    output: workspace/businesses/{slug}/tech/stack.yaml

  - agent: caio-architect
    task: elicit-ai-strategy
    output: workspace/businesses/{slug}/ai/strategy.yaml

  - agent: workspace-chief
    task: elicit-operations
    output: workspace/config.yaml
```

### Fase 3: Consolidacao

1. Verificar completude dos YAMLs gerados.
2. Consolidar pendencias e bloqueios no resumo final da execucao.
3. Nao criar artefatos `.md` em `workspace/businesses/{slug}/` fora do contrato de templates.

## Outputs esperados

- `workspace/businesses/{slug}/company/company-profile.yaml`
- `workspace/businesses/{slug}/company/icp.yaml`
- `workspace/businesses/{slug}/company/brand.yaml`
- `workspace/businesses/{slug}/tech/strategy.yaml`
- `workspace/businesses/{slug}/tech/stack.yaml`
- `workspace/businesses/{slug}/ai/strategy.yaml`
- `workspace/businesses/{slug}/evidence/workspace-context-summary.yaml`

## Validacao

- [ ] Preflight workspace-first passou.
- [ ] `*workspace-context {slug}` executado antes dos handoffs.
- [ ] Todos os outputs do setup foram gravados em YAML canonico com template correspondente.
- [ ] Nenhum output novo foi salvo em `workspace/` sem template.
