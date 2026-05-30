# Task: Workspace Health Check

```yaml
task:
  id: workspace-health-check
  name: Auditoria de Saúde do Workspace
  agent: workspace-chief
  trigger: manual | weekly
  schedule: "0 9 * * 1"  # Segunda-feira 9h
  elicit: false
```

## Descrição

Task de governança que audita a saúde completa do workspace. O COO executa essa auditoria periodicamente (recomendado: semanal) ou sob demanda para garantir que o workspace está íntegro, consistente e seguindo as regras de governança.

**Guardian:** COO (Chief Operating Officer)

## Workflow

### Fase 0: Pre-flight Check

```bash
# Verificar se workspace existe
ls workspace/ 2>/dev/null || echo "WORKSPACE_NOT_FOUND"
```

Se workspace não existe, abortar com mensagem clara.

### Fase 1: Validação Estrutural (STRUCTURE.md)

Executar o script de validação oficial:

```bash
bash squads/aiox-workspace/scripts/validate-structure.sh
```

**Gate:** Se `exit code != 0`, parar e reportar blockers.

Checklist automático:
- [ ] `workspace/` existe
- [ ] `company/` existe com arquivos obrigatórios
- [ ] `tech/` existe com arquivos obrigatórios
- [ ] `ai/` existe com arquivos obrigatórios
- [ ] `products/` existe (pode estar vazio)
- [ ] `workspace.yaml` existe
- [ ] `STRUCTURE.md` existe
- [ ] Nenhum pattern proibido encontrado
- [ ] Products seguem snake_case

### Fase 2: Validação de Domínios

Para cada domínio declarado em `workspace.yaml`:

```yaml
validation:
  for_each: workspace.yaml.domains
  checks:
    - domain_folder_exists: "domains/{domain}/"
    - entities_file: "domains/{domain}/entities.yaml"
    - workflows_file: "domains/{domain}/workflows.yaml"
    - at_least_one_mapping: "config/mappings/{domain}.*"
```

**Checklist:**
- [ ] Todos os domínios declarados têm pasta
- [ ] Todos os domínios têm entities.yaml
- [ ] Todos os domínios têm workflows.yaml
- [ ] Todos os domínios têm pelo menos 1 mapping

### Fase 3: Validação de Providers

Para cada provider declarado em `workspace.yaml`:

```yaml
validation:
  for_each: workspace.yaml.providers
  checks:
    - interface_file: "providers/{provider}/interface.yaml"
    - interface_has_operations: "operations section exists"
    - config_has_env_vars: "env vars are placeholders, not hardcoded"
```

**Checklist:**
- [ ] Todos os providers têm interface.yaml
- [ ] Todas as interfaces têm seção operations
- [ ] Nenhuma credencial hardcoded

### Fase 4: Validação YAML

Verificar sintaxe de todos os arquivos YAML:

```bash
find workspace -name "*.yaml" -o -name "*.yml" | while read f; do
  yq e '.' "$f" > /dev/null 2>&1 || echo "INVALID: $f"
done
```

**Checklist:**
- [ ] Todos os YAML parseiam corretamente
- [ ] Todos os JSON parseiam corretamente

### Fase 5: Validação de Integridade de Workflows

Executar teste automatizado de integridade:

```bash
npm test -- squads/aiox-workspace/scripts/workflow-integrity.test.js
```

**Gate:** Se `exit code != 0`, marcar `CONCERNS` e bloquear PASS.

**Checklist:**
- [ ] Todos os workflows parseiam via Jest
- [ ] Não há referências órfãs de steps em templates
- [ ] Não há nested template inválido em rules críticas

### Fase 6: Validação de Consistência

Cross-reference checks:

```yaml
consistency_checks:
  - domain_provider_match:
      description: "Domínios usam providers declarados"
      check: "domain.requires ⊆ workspace.providers"

  - mapping_provider_match:
      description: "Mappings referenciam providers válidos"
      check: "mapping.provider ∈ workspace.providers"

  - workflow_provider_match:
      description: "Workflows usam providers declarados"
      check: "workflow.steps[].provider ∈ workspace.providers"
```

### Fase 7: Validação Design System (se existir)

```yaml
design_system_checks:
  condition: "system/ ou libraries/ existem"
  checks:
    - foundations_complete: "system/foundations/ tem grid, spacing, rules"
    - tokens_valid: "system/tokens/*.json segue W3C spec"
    - theme_complete: "libraries/theme-*/brand-tokens.yaml existe"
    - modes_exist: "libraries/theme-*/modes/{light,dark}.yaml"
```

### Fase 8: Validação de Sagas (Compensatory Actions)

```yaml
saga_checks:
  for_each: domains/*/workflows.yaml
  checks:
    - has_on_failure: "workflow.on_failure existe"
    - has_compensation: "steps com mutation têm compensation"
    - compensation_is_inverse: "compensation é operação inversa"
```

### Fase 9: Geração do Relatório

Output em `docs/qa/workspace-health/YYYY-MM-DD-health-report.md`:

```markdown
# Workspace Health Report

**Data:** {date}
**Auditor:** COO (workspace-chief)
**Status:** {PASS | CONCERNS | FAIL}

## Resumo Executivo

| Categoria | Status | Issues |
|-----------|--------|--------|
| Estrutura | ✅/⚠️/❌ | {count} |
| Workflow Integrity | ✅/⚠️/❌ | {count} |
| Domínios | ✅/⚠️/❌ | {count} |
| Providers | ✅/⚠️/❌ | {count} |
| YAML | ✅/⚠️/❌ | {count} |
| Consistência | ✅/⚠️/❌ | {count} |
| Design System | ✅/⚠️/❌ | {count} |
| Sagas | ✅/⚠️/❌ | {count} |

## Issues Encontrados

### 🔴 Blockers
{list}

### 🟡 Warnings
{list}

### 🔵 Info
{list}

## Recomendações
{list}

## Próxima Auditoria
{next_date}
```

## Output

1. **Relatório:** `docs/qa/workspace-health/YYYY-MM-DD-health-report.md`
2. **Gate Decision:** PASS | CONCERNS | FAIL
3. **Issues List:** Array de issues categorizados

## Comandos Relacionados

| Comando | Descrição |
|---------|-----------|
| `*health-check` | Executa esta auditoria |
| `*fix-workspace` | Auto-fix de issues conhecidos |
| `*health-history` | Histórico de auditorias |

## Integração com CI/CD

```yaml
# .github/workflows/workspace-health.yml
on:
  schedule:
    - cron: '0 9 * * 1'  # Segunda 9h
  workflow_dispatch:

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run workspace validation
        run: bash squads/aiox-workspace/scripts/validate-structure.sh
      - name: Run workflow integrity tests
        run: npm test -- squads/aiox-workspace/scripts/workflow-integrity.test.js
```

## Validação da Task

- [ ] Relatório gerado em docs/qa/workspace-health/
- [ ] Gate decision definido (PASS/CONCERNS/FAIL)
- [ ] Issues categorizados por severidade
- [ ] Recomendações acionáveis listadas

---

*Task do Squad AIOX Workspace - COO Orchestrator*
*Governance: STRUCTURE.md*
