# Add Business

> Task ID: add-business
> Agent: workspace-chief
> Version: 1.0.0

## Description

Adiciona um novo negócio ao workspace com estrutura template-first.

## Prerequisites

- Bootstrap executado (`workspace/user.yaml` existe)

## Usage

```
*add-business {slug}
```

**Exemplo:**
```
*add-business lendario
*add-business synkra
```

## Workflow

### 1. Validar Slug

- Deve ser snake_case: `meu_negocio`
- Sem caracteres especiais
- Único (não pode existir já)

### 2. Criar Estrutura do Negócio

```bash
# Base structure
mkdir -p workspace/businesses/{slug}/company
mkdir -p workspace/businesses/{slug}/operations
mkdir -p workspace/businesses/{slug}/products
mkdir -p workspace/businesses/{slug}/tech
mkdir -p workspace/businesses/{slug}/ai
mkdir -p workspace/businesses/{slug}/movement
mkdir -p workspace/businesses/{slug}/evidence
```

### 3. Scaffold de Templates (obrigatorio)

Executar imediatamente:

```bash
*scaffold-templates {slug}
```

Requisito minimo apos scaffold:
- Baseline `company/*.yaml` e `operations/*.yaml` copiado de `workspace/_templates/`
- Baseline `tech/*.yaml`, `ai/*.yaml` e `evidence/workspace-context-summary.yaml` copiado de `workspace/_templates/`
- Nenhum README placeholder em `workspace/businesses/{slug}/`

### 4. Atualizar config.md

Adicionar o novo negócio à lista de negócios no `workspace/config.yaml`.

## Outputs

| Arquivo | Descrição |
|---------|-----------|
| `workspace/businesses/{slug}/` | Raiz do negócio |
| `workspace/businesses/{slug}/company/` | Docs da empresa |
| `workspace/businesses/{slug}/products/` | Produtos |
| `workspace/businesses/{slug}/operations/` | Operações (team, pricing, KPIs) |
| `workspace/businesses/{slug}/tech/` | Docs técnicos |
| `workspace/businesses/{slug}/ai/` | Estratégia de IA |
| `workspace/businesses/{slug}/movement/` | Artefatos de movimento |
| `workspace/businesses/{slug}/evidence/` | Evidências e source maps |

## Validation

- [ ] Slug é válido (snake_case)
- [ ] Negócio não existia
- [ ] Todos os diretórios criados
- [ ] Scaffold templates executado (baseline company/operations/tech/ai/evidence)
- [ ] config.md atualizado

## Next Steps

Após criar o negócio:
1. `*setup-business-profile {slug}` - Pipeline completo de perfil (7 YAMLs)
2. Ou individualmente: `*elicit-vision`, `*elicit-icp`, etc.
3. `*setup-workspace` para setup técnico (Sistema A)

---

*Task do Squad AIOX Workspace - COO Orchestrator*
