#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQUAD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SQUAD_DIR}/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-${REPO_ROOT}/workspace}"

created_dirs=0
created_files=0
warnings=0

declare -a REQUIRED_DIRS=(
  "${WORKSPACE_ROOT}"
  "${WORKSPACE_ROOT}/businesses"
  "${WORKSPACE_ROOT}/ui/tokens"
  "${WORKSPACE_ROOT}/ui/components"
  "${WORKSPACE_ROOT}/ui/styles"
  "${WORKSPACE_ROOT}/domains/aiox-workspace"
  "${WORKSPACE_ROOT}/_templates"
  "${WORKSPACE_ROOT}/_templates/company"
  "${WORKSPACE_ROOT}/_templates/operations"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [[ ! -d "${dir}" ]]; then
    mkdir -p "${dir}"
    created_dirs=$((created_dirs + 1))
    echo "created_dir: ${dir}"
  fi
done

write_if_missing() {
  local path="$1"
  local content="$2"
  if [[ ! -f "${path}" ]]; then
    printf '%s\n' "${content}" > "${path}"
    created_files=$((created_files + 1))
    echo "created_file: ${path}"
  fi
}

write_if_missing "${WORKSPACE_ROOT}/user.md" "# User Profile

## Identidade
- Nome:
- Como chamar:

## Contexto Profissional
- Área:
- Papel:

## Preferências
- Tom de comunicação:
- Idioma:

---
*Bootstrap placeholder. Preencher via task *bootstrap.*"

write_if_missing "${WORKSPACE_ROOT}/config.md" "# Workspace Configuration

## Negócios
_Nenhum negócio configurado ainda. Use *add-business {slug} para adicionar._

## Preferências Globais
- Idioma: pt-BR
- Fuso horário: America/Sao_Paulo

---
*Configuração inicial criada por bootstrap-workspace.sh*"

write_if_missing "${WORKSPACE_ROOT}/config.yaml" "version: \"1.0\"
domains:
  - aiox-workspace
providers: []
metadata:
  managed_by: aiox-workspace
  bootstrap_source: squads/aiox-workspace/scripts/bootstrap-workspace.sh"

write_if_missing "${WORKSPACE_ROOT}/domains/aiox-workspace/entities.yaml" "domain: aiox-workspace
version: \"1.0\"
entities: []"

write_if_missing "${WORKSPACE_ROOT}/domains/aiox-workspace/workflows.yaml" "domain: aiox-workspace
version: \"1.0\"
workflows: {}"

# Check canonical templates required by scaffold-templates and business-profile pipeline.
declare -a REQUIRED_TEMPLATE_FILES=(
  "${WORKSPACE_ROOT}/_templates/company/founder-dna.yaml"
  "${WORKSPACE_ROOT}/_templates/company/credentials.yaml"
  "${WORKSPACE_ROOT}/_templates/company/company-profile.yaml"
  "${WORKSPACE_ROOT}/_templates/brand/brandbook.yaml"
  "${WORKSPACE_ROOT}/_templates/company/icp.yaml"
  "${WORKSPACE_ROOT}/_templates/company/diagnosis.yaml"
  "${WORKSPACE_ROOT}/_templates/company/analytics.yaml"
  "${WORKSPACE_ROOT}/_templates/company/authority-story.yaml"
  "${WORKSPACE_ROOT}/_templates/operations/team-structure.yaml"
  "${WORKSPACE_ROOT}/_templates/operations/pricing-strategy.yaml"
  "${WORKSPACE_ROOT}/_templates/operations/kpi-scorecards.yaml"
  "${WORKSPACE_ROOT}/_templates/operations/commission-design.yaml"
)

for file in "${REQUIRED_TEMPLATE_FILES[@]}"; do
  if [[ ! -f "${file}" ]]; then
    warnings=$((warnings + 1))
    echo "warning: missing canonical template ${file}"
  fi
done

echo "bootstrap-workspace: created_dirs=${created_dirs} created_files=${created_files} warnings=${warnings}"
