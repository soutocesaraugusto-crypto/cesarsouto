# Workspace Health Checklist

> **Owner:** COO (workspace-chief)
> **Squad:** AIOX Workspace
> **Frequency:** Weekly or On-Demand
> **Reference:** STRUCTURE.md

---

## 1. Estrutura Básica

### 1.1 Diretórios Obrigatórios
- [ ] `workspace/` existe
- [ ] `workspace/company/` existe
- [ ] `workspace/tech/` existe
- [ ] `workspace/ai/` existe
- [ ] `workspace/businesses/` existe
- [ ] `workspace/providers/` existe
- [ ] `workspace/config/` existe

### 1.2 Arquivos Obrigatórios (Root)
- [ ] `workspace/config.yaml` existe e é válido
- [ ] `workspace/config.yaml` existe
- [ ] `workspace/user.yaml` ou `workspace/MEMORY.md` existe
- [ ] `workspace/README.md` existe
- [ ] `workspace/STRUCTURE.md` existe

### 1.3 Arquivos Obrigatórios (Company)
- [ ] `company/mission-vision.md` existe
- [ ] `company/icp.md` existe
- [ ] `company/brand.md` existe
- [ ] `company/value-proposition.md` existe (opcional)
- [ ] `company/elevator-pitch.md` existe (opcional)

### 1.4 Arquivos Obrigatórios (Tech)
- [ ] `tech/stack.md` existe
- [ ] `tech/code-standards.md` existe
- [ ] `tech/infrastructure.md` existe (opcional)
- [ ] `tech/integrations.md` existe (opcional)

### 1.5 Arquivos Obrigatórios (AI)
- [ ] `ai/models.md` existe
- [ ] `ai/agents.md` existe (opcional)
- [ ] `ai/orchestration.md` existe (opcional)

---

## 2. Validação de Domínios

### 2.1 Consistência workspace.yaml ↔ Pastas

Para CADA domínio listado em `workspace.yaml.domains`:
- [ ] Pasta `domains/{domain}/` existe
- [ ] `domains/{domain}/entities.yaml` existe
- [ ] `domains/{domain}/workflows.yaml` existe
- [ ] Pelo menos 1 arquivo em `config/mappings/{domain}.*`

### 2.2 Schema de Entities

Para CADA `entities.yaml`:
- [ ] Tem `domain:` no header
- [ ] Tem `version:` no header
- [ ] Tem seção `entities:` com pelo menos 1 entidade
- [ ] Cada entidade tem `description`
- [ ] Cada entidade tem `fields`
- [ ] Campos têm `type` definido

### 2.3 Schema de Workflows

Para CADA `workflows.yaml`:
- [ ] Tem `domain:` no header
- [ ] Tem `version:` no header
- [ ] Tem seção `workflows:` com pelo menos 1 workflow
- [ ] Cada workflow tem `trigger`
- [ ] Cada workflow tem `steps`
- [ ] Workflows com mutations têm `on_failure`
- [ ] Steps com side-effects têm `compensation`

---

## 3. Validação de Providers

### 3.1 Consistência workspace.yaml ↔ Interfaces

Para CADA provider listado em `workspace.yaml.providers`:
- [ ] Pasta `providers/{provider}/` existe
- [ ] `providers/{provider}/interface.yaml` existe
- [ ] Interface tem seção `operations`
- [ ] Cada operação tem `input` e `output` definidos

### 3.2 Segurança de Configuração

- [ ] Nenhuma credencial hardcoded em workspace.yaml
- [ ] Todas as credenciais usam `${ENV_VAR}` syntax
- [ ] Nenhum arquivo `.env` commitado

---

## 4. Validação de Mappings

### 4.1 Existência
- [ ] `config/mappings/` existe
- [ ] Pelo menos 1 mapping por domínio ativo

### 4.2 Consistência
Para CADA arquivo de mapping:
- [ ] `domain:` referencia domínio existente
- [ ] `provider:` referencia provider existente
- [ ] `entity_mappings:` mapeia entidades do domínio
- [ ] Campos mapeados existem na entidade de origem

---

## 5. Validação Design System (se aplicável)

### 5.1 Foundations (system/)
- [ ] `system/foundations/` existe
- [ ] `system/foundations/grid.yaml` existe
- [ ] `system/foundations/spacing.yaml` existe
- [ ] `system/foundations/hierarchy.yaml` existe (opcional)
- [ ] `system/foundations/rules.yaml` existe (opcional)

### 5.2 Tokens
- [ ] `system/tokens/` existe
- [ ] `system/tokens/primitive.tokens.json` existe e segue W3C spec
- [ ] `system/tokens/semantic.tokens.json` existe (recomendado)

### 5.3 Libraries (themes)
- [ ] `libraries/` existe
- [ ] Pelo menos 1 tema: `libraries/theme-{name}/`
- [ ] Cada tema tem `brand-tokens.yaml`
- [ ] Cada tema tem `modes/light.yaml`
- [ ] Cada tema tem `modes/dark.yaml` (recomendado)
- [ ] Cada tema tem `component-skins.yaml` (recomendado)

---

## 6. Validação de Sintaxe

### 6.1 YAML Files
- [ ] Todos os arquivos `.yaml` parseiam sem erro
- [ ] Todos os arquivos `.yml` parseiam sem erro

### 6.2 JSON Files
- [ ] Todos os arquivos `.json` parseiam sem erro
- [ ] JSON tokens seguem W3C Design Tokens spec (se aplicável)

### 6.3 Markdown Files
- [ ] Todos os arquivos `.md` têm frontmatter válido (se usado)
- [ ] Nenhum link quebrado interno

---

## 7. Padrões Proibidos

### 7.1 Nomes de Arquivo
- [ ] Nenhum arquivo `*_backup`
- [ ] Nenhum arquivo `*_old`
- [ ] Nenhum arquivo `*_v2`, `*_v3`
- [ ] Nenhum arquivo `test_*` (fora de /tests)
- [ ] Nenhum arquivo `temp_*`
- [ ] Nenhum arquivo `TODO_*`
- [ ] Nenhum arquivo `*~`

### 7.2 Nomes de Produto
- [ ] Todos os produtos em `products/` usam snake_case
- [ ] Nenhum PascalCase
- [ ] Nenhum kebab-case

---

## 8. Consistência Cross-Reference

### 8.1 Domain → Provider
- [ ] `domain.requires[]` só lista providers em `workspace.yaml.providers`

### 8.2 Workflow → Provider
- [ ] `workflow.steps[].provider` só usa providers em `workspace.yaml.providers`

### 8.3 Mapping → Domain + Provider
- [ ] Mapping.domain existe em `domains/`
- [ ] Mapping.provider existe em `providers/`

---

## 9. Sagas e Compensação

### 9.1 On Failure Strategy
Para workflows com mutations:
- [ ] Tem `on_failure.strategy` definido
- [ ] Strategy é válido: `compensate_executed | continue | manual`

### 9.2 Compensation Actions
Para steps com side-effects:
- [ ] Step tem `compensation` definido
- [ ] Compensation tem `operation` (operação inversa)
- [ ] Compensation tem `params` com referências corretas

---

## 10. Services

### 10.1 Sync Engine
- [ ] `infrastructure/services/sync-engine/` existe
- [ ] `infrastructure/services/sync-engine/README.md` documenta o engine
- [ ] `infrastructure/services/sync-engine/state-tracking.yaml` existe (recomendado)

### 10.2 Event Bus
- [ ] `infrastructure/services/event-bus/` existe
- [ ] `infrastructure/services/event-bus/README.md` documenta o bus

---

## 11. Workflow Integrity Gate

### 11.1 Automated Integrity Test
- [ ] `squads/aiox-workspace/scripts/workflow-integrity.test.js` existe
- [ ] `npm test -- squads/aiox-workspace/scripts/workflow-integrity.test.js` executa com PASS

### 11.2 Runtime Safety Assertions
- [ ] Não há referência órfã a steps em templates (`{{step.output...}}`)
- [ ] Regras críticas não usam template aninhado inválido
- [ ] Workflows críticos parseiam sem erro sintático

---

## Scoring

| Seção | Peso | Score |
|-------|------|-------|
| Estrutura Básica | 25% | __/100 |
| Domínios | 20% | __/100 |
| Providers | 15% | __/100 |
| Mappings | 15% | __/100 |
| Design System | 10% | __/100 |
| Sintaxe | 5% | __/100 |
| Padrões Proibidos | 5% | __/100 |
| Cross-Reference | 3% | __/100 |
| Sagas | 2% | __/100 |

**Total Score:** __/100

**Gate Decision:**
- 90-100: ✅ PASS
- 70-89: ⚠️ CONCERNS
- <70: ❌ FAIL

---

## Issue Severity Guide

| Severidade | Critério | Ação |
|------------|----------|------|
| 🔴 BLOCKER | Quebra validação básica | Fix imediato |
| 🟡 HIGH | Inconsistência funcional | Fix em 24h |
| 🟠 MEDIUM | Falta de completude | Fix em 1 semana |
| 🔵 LOW | Best practice missing | Backlog |

---

*Checklist do Squad AIOX Workspace - COO Orchestrator*
*Versão: 1.0.0*
*Última atualização: 2026-02-16*
