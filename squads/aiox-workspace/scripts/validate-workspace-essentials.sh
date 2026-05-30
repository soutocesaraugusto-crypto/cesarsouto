#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQUAD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SQUAD_DIR}/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-${REPO_ROOT}/workspace}"

python3 - "${SQUAD_DIR}" "${REPO_ROOT}" "${WORKSPACE_ROOT}" <<'PY'
import os
import sys
from pathlib import Path

import yaml

squad_dir = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
workspace_root = Path(sys.argv[3])

errors = []
warnings = []

required_scripts = [
    squad_dir / "scripts" / "bootstrap-workspace.sh",
    squad_dir / "scripts" / "validate-workspace-essentials.sh",
    squad_dir / "scripts" / "validate-structure.sh",
    squad_dir / "scripts" / "workflow-integrity.test.js",
]
for script in required_scripts:
    if not script.exists():
        errors.append(f"missing script: {script.relative_to(repo_root)}")

if required_scripts[0].exists() and not os.access(required_scripts[0], os.X_OK):
    errors.append("bootstrap-workspace.sh must be executable")
if required_scripts[1].exists() and not os.access(required_scripts[1], os.X_OK):
    errors.append("validate-workspace-essentials.sh must be executable")

expected_ws_scripts = {
    "bootstrap": "scripts/bootstrap-workspace.sh",
    "essentials_validation": "scripts/validate-workspace-essentials.sh",
}

for cfg_name in ("config.yaml", "squad.yaml"):
    cfg_path = squad_dir / cfg_name
    if not cfg_path.exists():
        errors.append(f"missing file: {cfg_path.relative_to(repo_root)}")
        continue

    with cfg_path.open("r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    ws = cfg.get("workspace_integration")
    if not isinstance(ws, dict):
        errors.append(f"{cfg_name}: missing workspace_integration block")
        continue

    if ws.get("level") != "workspace_first":
        errors.append(f"{cfg_name}: workspace_integration.level must be workspace_first")

    bootstrap = ws.get("bootstrap") or {}
    if bootstrap.get("required") is not True:
        errors.append(f"{cfg_name}: workspace_integration.bootstrap.required must be true")
    if bootstrap.get("script") != expected_ws_scripts["bootstrap"]:
        errors.append(f"{cfg_name}: bootstrap script mismatch")

    essentials = ws.get("essentials_validation") or {}
    if essentials.get("required") is not True:
        errors.append(f"{cfg_name}: workspace_integration.essentials_validation.required must be true")
    if essentials.get("script") != expected_ws_scripts["essentials_validation"]:
        errors.append(f"{cfg_name}: essentials_validation script mismatch")

    read_paths = ws.get("read_paths") or []
    write_paths = ws.get("write_paths") or []
    if not isinstance(read_paths, list) or len(read_paths) == 0:
        errors.append(f"{cfg_name}: workspace_integration.read_paths must be non-empty list")
    if not isinstance(write_paths, list) or len(write_paths) == 0:
        errors.append(f"{cfg_name}: workspace_integration.write_paths must be non-empty list")

    for rel in read_paths + write_paths:
        candidate = repo_root / rel
        if not candidate.exists():
            errors.append(f"{cfg_name}: declared workspace path not found: {rel}")

    for key in ("agents", "tasks", "workflows", "checklists"):
        for entry in cfg.get(key, []) or []:
            if not isinstance(entry, dict):
                continue
            file_rel = entry.get("file")
            entry_id = entry.get("id", "<unknown>")
            if not file_rel:
                errors.append(f"{cfg_name}: {key}.{entry_id} missing file path")
                continue
            file_path = squad_dir / file_rel
            if not file_path.exists():
                errors.append(f"{cfg_name}: {key}.{entry_id} missing file {file_rel}")

    task_ids = {entry.get("id") for entry in (cfg.get("tasks") or []) if isinstance(entry, dict)}
    if "load-workspace-context" not in task_ids:
        errors.append(f"{cfg_name}: task load-workspace-context must be registered")

required_workspace_files = [
    workspace_root / "config.yaml",
    workspace_root / "user.md",
    workspace_root / "config.md",
    workspace_root / "domains" / "aiox-workspace" / "entities.yaml",
    workspace_root / "domains" / "aiox-workspace" / "workflows.yaml",
    workspace_root / "_templates" / "README.md",
    workspace_root / "_templates" / "TEMPLATE_SYSTEM.md",
    workspace_root / "_templates" / "company" / "founder-dna.yaml",
    workspace_root / "_templates" / "company" / "credentials.yaml",
    workspace_root / "_templates" / "company" / "company-profile.yaml",
    workspace_root / "_templates" / "company" / "brand.yaml",
    workspace_root / "_templates" / "company" / "icp.yaml",
    workspace_root / "_templates" / "company" / "diagnosis.yaml",
    workspace_root / "_templates" / "company" / "analytics.yaml",
    workspace_root / "_templates" / "company" / "authority-story.yaml",
    workspace_root / "_templates" / "operations" / "team-structure.yaml",
    workspace_root / "_templates" / "operations" / "pricing-strategy.yaml",
    workspace_root / "_templates" / "operations" / "kpi-scorecards.yaml",
    workspace_root / "_templates" / "operations" / "commission-design.yaml",
    workspace_root / "_templates" / "tech" / "strategy.yaml",
    workspace_root / "_templates" / "tech" / "stack.yaml",
    workspace_root / "_templates" / "ai" / "strategy.yaml",
    workspace_root / "_templates" / "evidence" / "workspace-context-summary.yaml",
]
for path in required_workspace_files:
    if not path.exists():
        errors.append(f"missing workspace essential: {path.relative_to(repo_root)}")

bp_path = squad_dir / "workflows" / "business-profile-pipeline.yaml"
if bp_path.exists():
    bp_raw = bp_path.read_text(encoding="utf-8")
    for token in (
        "load-workspace-context",
        "bootstrap-workspace.sh",
        "validate-workspace-essentials.sh",
    ):
        if token not in bp_raw:
            errors.append(f"business-profile-pipeline.yaml missing token: {token}")
else:
    errors.append("missing workflow: workflows/business-profile-pipeline.yaml")

wg_path = squad_dir / "workflows" / "workspace-governance.yaml"
if wg_path.exists():
    wg_raw = wg_path.read_text(encoding="utf-8")
    if "validate-workspace-essentials.sh" not in wg_raw:
        errors.append("workspace-governance.yaml missing validate-workspace-essentials.sh")
else:
    errors.append("missing workflow: workflows/workspace-governance.yaml")

coo_path = squad_dir / "agents" / "workspace-chief.md"
if coo_path.exists():
    coo_raw = coo_path.read_text(encoding="utf-8")
    for token in (
        "*workspace-preflight",
        "*workspace-context",
        "scripts/bootstrap-workspace.sh",
        "scripts/validate-workspace-essentials.sh",
        "load-workspace-context.md",
    ):
        if token not in coo_raw:
            errors.append(f"workspace-chief.md missing token: {token}")
else:
    errors.append("missing agent: agents/workspace-chief.md")

readme_path = squad_dir / "README.md"
if readme_path.exists():
    readme_raw = readme_path.read_text(encoding="utf-8")
    for token in (
        "bootstrap-workspace.sh",
        "validate-workspace-essentials.sh",
        "*workspace-preflight",
        "*workspace-context",
    ):
        if token not in readme_raw:
            errors.append(f"README.md missing token: {token}")
else:
    errors.append("missing file: squads/aiox-workspace/README.md")

if errors:
    print("validate-workspace-essentials: FAIL")
    for error in errors:
        print(f"  - {error}")
    for warning in warnings:
        print(f"  - warning: {warning}")
    sys.exit(1)

print("validate-workspace-essentials: PASS")
for warning in warnings:
    print(f"  - warning: {warning}")
PY
