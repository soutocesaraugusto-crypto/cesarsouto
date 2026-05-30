# Task: Load Workspace Context

```yaml
task:
  id: load-workspace-context
  name: Carregar Contexto do Workspace
  agent: workspace-chief
  elicit: false
```

## Descrição

Task de preflight para consolidar contexto do workspace antes de qualquer elicitação AIOX Workspace. Evita sobrescrita, reduz drift e garante handoffs informados entre COO, CEO e CMO.

## Objetivo

1. Validar estrutura mínima com scripts do squad.
2. Ler dados já existentes do workspace.
3. Montar snapshot de contexto para os próximos handoffs.

## Workflow

### Fase 1: Preflight obrigatório

Executar, nesta ordem:

```bash
bash squads/aiox-workspace/scripts/bootstrap-aiox-workspace.sh
bash squads/aiox-workspace/scripts/validate-workspace-essentials.sh
```

Se a validação falhar, interromper e reportar caminhos faltantes.

### Fase 2: Carregar contexto global

Ler, se existirem:

- `workspace/config.yaml`
- `workspace/user.yaml`
- `workspace/config.yaml`

Extrair:

- Domínios ativos e providers declarados.
- Negócios já cadastrados.
- Preferências de comunicação e idioma.

### Fase 3: Carregar contexto de negócio (quando houver `{slug}`)

Ler, se existirem:

- `workspace/businesses/{slug}/company/company-profile.yaml`
- `workspace/businesses/{slug}/company/founder-dna.yaml`
- `workspace/businesses/{slug}/company/icp.yaml`
- `workspace/businesses/{slug}/company/brand.yaml`
- `workspace/businesses/{slug}/operations/team-structure.yaml`
- `workspace/businesses/{slug}/operations/pricing-strategy.yaml`
- `workspace/businesses/{slug}/operations/diagnostic-backlog.yaml`

Mapear:

- Campos críticos já preenchidos.
- Lacunas de dados que devem virar perguntas.
- Dependências para os próximos handoffs.

### Fase 4: Snapshot operacional

Registrar resumo em:

- `workspace/businesses/{slug}/evidence/workspace-context-summary.yaml` (quando `{slug}` existir)
- fallback sem slug: resumo inline na resposta do COO.

Contrato mínimo do snapshot:

```yaml
workspace_context:
  generated_at: "YYYY-MM-DDTHH:mm:ssZ"
  workspace_health: "pass|fail"
  business_slug: "{slug|null}"
  existing_assets:
    company: []
    operations: []
  missing_inputs: []
  diagnostic_backlog:
    total_items: 0
    pending_items: 0
    top_priority: null  # item de maior prioridade pendente
  handoff_readiness:
    vision-strategist: "ready|blocked"
    cmo-architect: "ready|blocked"
    workspace-chief: "ready|blocked"
```

## Validação

- [ ] Scripts de preflight executados com sucesso.
- [ ] Contexto global carregado (`workspace.yaml`, `user.md`, `config.md`).
- [ ] Contexto do negócio mapeado (quando `{slug}` foi informado).
- [ ] Snapshot de contexto produzido sem inventar campos.

## Fallback

Se algum arquivo obrigatório estiver ausente:

1. Reportar caminho exato.
2. Não inventar schema ou dados.
3. Sugerir rodar `*workspace-preflight` e depois retomar com `*workspace-context {slug}`.

---

*Task do Squad AIOX Workspace - COO Orchestrator*
