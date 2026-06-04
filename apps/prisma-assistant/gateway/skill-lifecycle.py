#!/usr/bin/env python3
"""
Skill Lifecycle Manager — Epic 110 Stories 110.8, 110.9, 110.10, 110.11

Unified module for skill promotion, generation, security scanning, and budget cap.

Commands:
    python3 skill-lifecycle.py promote     # Run lifecycle transitions (110.8)
    python3 skill-lifecycle.py generate    # Generate SKILL.md for ACTIVE skills (110.9)
    python3 skill-lifecycle.py scan        # Security scan all pending skills (110.10)
    python3 skill-lifecycle.py budget      # Build budget-capped skills prompt (110.11)
    python3 skill-lifecycle.py status      # Show lifecycle status summary

Environment:
    CRM_AGENT_NAME  - Agent name (default: prisma)
    CRM_ROOT        - CRM state root (default: ~/.claude-remote/default)

Design references:
    - Hermes skill_manager_tool.py (YAML frontmatter, atomic writes)
    - Hermes skills_guard.py (70 regex patterns)
    - Sinkra MIS fact-promoter.js (promotion state machine)
"""

import json
import math
import os
import re
import sqlite3
import sys
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

# --- Configuration ---
AGENT = os.environ.get("CRM_AGENT_NAME", "prisma")
CRM_ROOT = os.environ.get("CRM_ROOT", str(Path.home() / ".claude-remote" / "default"))

# Self-contained package: PRISMA_HOME is the install root. Skills live inside the
# agent dir (<gateway>/agents/<slug>/skills/auto-generated). Falls back to the
# legacy hub layout (.claude/skills/auto-generated) only if PRISMA_HOME is unset.
PRISMA_HOME = os.environ.get("PRISMA_HOME", "")
CRM_TEMPLATE_ROOT = os.environ.get("CRM_TEMPLATE_ROOT", "")

DB_PATH = Path(CRM_ROOT) / "state" / AGENT / "skills.db"

if CRM_TEMPLATE_ROOT and (Path(CRM_TEMPLATE_ROOT) / "agents" / AGENT).is_dir():
    # Self-contained package layout
    SKILLS_DIR = Path(CRM_TEMPLATE_ROOT) / "agents" / AGENT / "skills" / "auto-generated"
    CONFIG_PATH = Path(CRM_TEMPLATE_ROOT) / "agents" / AGENT / "config.json"
elif PRISMA_HOME:
    SKILLS_DIR = Path(PRISMA_HOME) / ".claude" / "skills" / "auto-generated"
    CONFIG_PATH = Path(PRISMA_HOME) / ".aiox" / "message-gateway" / "config.yaml"
else:
    SKILLS_DIR = None
    CONFIG_PATH = None

# Default thresholds (overridden by config.yaml)
THRESHOLDS = {
    "promotion_threshold_active": 3,
    "promotion_threshold_proven": 5,
    "min_distinct_sessions": 2,
    "stale_days": 30,
    "archive_days": 90,
    "max_skills_in_prompt": 20,
    "max_tokens_skills": 5000,
}


def load_config():
    """Load thresholds from config.yaml if available."""
    if CONFIG_PATH and CONFIG_PATH.exists():
        try:
            import yaml
            with open(CONFIG_PATH) as f:
                cfg = yaml.safe_load(f) or {}
            lifecycle = cfg.get("skill_lifecycle", {})
            budget = cfg.get("skill_budget", {})
            for k, v in {**lifecycle, **budget}.items():
                if k in THRESHOLDS:
                    THRESHOLDS[k] = v
        except ImportError:
            # PyYAML not available — try manual parse
            try:
                content = CONFIG_PATH.read_text()
                for key in THRESHOLDS:
                    match = re.search(rf"{key}:\s*(\d+)", content)
                    if match:
                        THRESHOLDS[key] = int(match.group(1))
            except Exception:
                pass
    return THRESHOLDS


def get_db():
    """Get SQLite connection."""
    if not DB_PATH.exists():
        return None
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


# ============================================================
# STORY 110.10: Security Guard (70+ regex patterns)
# ============================================================

SECURITY_PATTERNS = {
    "exfiltration": [
        r"curl.*\$\{?\w*(TOKEN|SECRET|KEY|PASS|CRED)",
        r"wget.*\$\{?\w*(TOKEN|SECRET|KEY|PASS|CRED)",
        r"curl.*-d.*\$\(cat",
        r"nc\s+-[a-z]*\s+\d+\.\d+\.\d+\.\d+",
        r"curl.*\.onion",
        r"nslookup.*\$\(",
        r"dig.*\$\(",
        r"curl.*pastebin|curl.*hastebin|curl.*transfer\.sh",
        r"base64.*\|\s*curl",
        r"cat\s+~/.ssh/id_",
        r"cat\s+/etc/shadow",
    ],
    "injection": [
        r"ignore\s+(all\s+)?previous\s+instructions",
        r"ignore\s+your\s+(system|initial)\s+prompt",
        r"you\s+are\s+now\s+(DAN|evil|unrestricted)",
        r"jailbreak",
        r"pretend\s+you\s+are",
        r"role[:\s]+system",
        r"act\s+as\s+(if|though)\s+you\s+(have|are)",
        r"override\s+(your|the)\s+(rules|instructions|constraints)",
        r"new\s+instructions?\s*:",
        r"disregard\s+(all|any|the)",
        r"from\s+now\s+on\s+you\s+(will|must|should)",
        r"system\s*prompt\s*override",
        r"<\|.*\|>",
        r"\[\[SYSTEM\]\]",
        r"BEGIN\s+OVERRIDE",
    ],
    "destructive": [
        r"rm\s+-rf\s+/(?!\s*tmp)",
        r"mkfs\.",
        r"dd\s+if=.*of=/dev/",
        r":\(\)\s*\{\s*:\|:\s*&\s*\}\s*;",  # fork bomb
        r"chmod\s+-R\s+777\s+/",
        r"shred\s+-",
        r"wipefs",
        r"truncate\s+-s\s+0",
    ],
    "persistence": [
        r"crontab\s+-[el]?\s",
        r"echo.*>>\s*/etc/cron",
        r"ssh-keygen.*-f\s+~/.ssh/authorized",
        r"echo.*>>\s*~/.ssh/authorized_keys",
        r"systemctl\s+enable",
        r"launchctl\s+load",
        r"echo.*>>\s*/etc/sudoers",
        r"visudo",
        r"chkconfig.*on",
        r"update-rc\.d",
        r"at\s+\d+:\d+",
    ],
    "network": [
        r"bash\s+-i\s+>&\s+/dev/tcp/",
        r"python.*socket.*connect",
        r"nc\s+-e\s+/bin/(ba)?sh",
        r"socat.*exec:",
        r"ssh\s+-R\s+\d+:",
        r"ngrok",
        r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b(?!.*localhost|127\.0\.0\.1|0\.0\.0\.0)",
        r"reverse.shell|revshell",
    ],
    "obfuscation": [
        r"eval\s*\(",
        r"base64\s+(-d|--decode)\s*\|",
        r"echo\s+.*\|\s*(ba)?sh",
        r"\$\(\s*echo\s+.*\|\s*base64\s+-d\s*\)",
        r"python\s+-c\s+['\"]import\s+base64",
        r"exec\s*\(\s*compile",
        r"\\x[0-9a-f]{2}.*\\x[0-9a-f]{2}",
        r"chr\(\d+\).*chr\(\d+\)",
        r"fromCharCode",
        r"String\.fromCodePoint",
    ],
    "privilege": [
        r"sudo\s+(?!-v)",
        r"chmod\s+[u+]*s\s",
        r"NOPASSWD",
        r"pkexec",
        r"doas\s+",
    ],
    "credentials": [
        r"(?:api[_-]?key|token|secret|password)\s*[=:]\s*['\"][a-zA-Z0-9]{16,}['\"]",
        r"-----BEGIN\s+(RSA|EC|OPENSSH|PGP)\s+PRIVATE\s+KEY-----",
        r"ghp_[a-zA-Z0-9]{36}",
        r"sk-[a-zA-Z0-9]{32,}",
        r"AKIA[A-Z0-9]{16}",
    ],
}


def scan_security(content: str) -> dict:
    """Scan content for security patterns. Returns verdict + findings."""
    findings = []
    for category, patterns in SECURITY_PATTERNS.items():
        for pattern in patterns:
            matches = re.findall(pattern, content, re.I | re.M)
            if matches:
                findings.append({
                    "category": category,
                    "pattern": pattern,
                    "match_count": len(matches),
                    "sample": str(matches[0])[:50],
                })

    if not findings:
        return {"verdict": "SAFE", "findings": []}

    has_critical = any(f["category"] in ("exfiltration", "destructive", "injection", "credentials", "network")
                       for f in findings)
    return {
        "verdict": "DANGEROUS" if has_critical else "CAUTION",
        "findings": findings,
    }


# ============================================================
# STORY 110.8: Skill Promoter (lifecycle state machine)
# ============================================================

def cmd_promote():
    """Run lifecycle transitions."""
    cfg = load_config()
    conn = get_db()
    if not conn:
        print("No skills database found.")
        return

    now = datetime.utcnow()
    changes = []

    # CANDIDATE → ACTIVE (usage_count >= threshold AND distinct_sessions >= min)
    candidates = conn.execute(
        """SELECT id, name, usage_count, distinct_sessions FROM skills
           WHERE status = 'CANDIDATE'
           AND usage_count >= ? AND distinct_sessions >= ?""",
        (cfg["promotion_threshold_active"], cfg["min_distinct_sessions"])
    ).fetchall()

    for row in candidates:
        # Security scan before promotion
        skill_content = conn.execute(
            "SELECT summary, files_touched FROM skills WHERE id = ?", (row["id"],)
        ).fetchone()
        scan_result = scan_security(
            f"{skill_content['summary']} {skill_content['files_touched']}"
        )

        if scan_result["verdict"] == "DANGEROUS":
            conn.execute(
                "UPDATE skills SET security_verdict = 'DANGEROUS' WHERE id = ?",
                (row["id"],)
            )
            changes.append(f"BLOCKED {row['name']}: DANGEROUS ({len(scan_result['findings'])} findings)")
            continue

        conn.execute(
            """UPDATE skills SET status = 'ACTIVE', promoted_at = ?,
               security_verdict = ? WHERE id = ?""",
            (now.isoformat(), scan_result["verdict"], row["id"])
        )
        changes.append(f"PROMOTED {row['name']}: CANDIDATE → ACTIVE")

    # ACTIVE → PROVEN (usage_count >= threshold)
    actives = conn.execute(
        """SELECT id, name, usage_count FROM skills
           WHERE status = 'ACTIVE' AND usage_count >= ?""",
        (cfg["promotion_threshold_proven"],)
    ).fetchall()

    for row in actives:
        conn.execute(
            "UPDATE skills SET status = 'PROVEN', promoted_at = ? WHERE id = ?",
            (now.isoformat(), row["id"])
        )
        changes.append(f"PROMOTED {row['name']}: ACTIVE → PROVEN")

    # Any → STALE (no use in stale_days)
    stale_threshold = (now - timedelta(days=cfg["stale_days"])).isoformat()
    stale_rows = conn.execute(
        """SELECT id, name FROM skills
           WHERE status IN ('ACTIVE', 'PROVEN')
           AND (last_used_at IS NULL OR last_used_at < ?)""",
        (stale_threshold,)
    ).fetchall()

    for row in stale_rows:
        conn.execute(
            "UPDATE skills SET status = 'STALE', stale_at = ? WHERE id = ?",
            (now.isoformat(), row["id"])
        )
        changes.append(f"STALE {row['name']}: no use in {cfg['stale_days']}d")

    # STALE → ARCHIVED (no use in archive_days)
    archive_threshold = (now - timedelta(days=cfg["archive_days"])).isoformat()
    archived_rows = conn.execute(
        """SELECT id, name FROM skills
           WHERE status = 'STALE'
           AND (last_used_at IS NULL OR last_used_at < ?)""",
        (archive_threshold,)
    ).fetchall()

    for row in archived_rows:
        conn.execute(
            "UPDATE skills SET status = 'ARCHIVED', archived_at = ? WHERE id = ?",
            (now.isoformat(), row["id"])
        )
        changes.append(f"ARCHIVED {row['name']}: no use in {cfg['archive_days']}d")

    conn.commit()
    conn.close()

    if changes:
        print(f"Lifecycle sweep: {len(changes)} transitions")
        for c in changes:
            print(f"  {c}")
    else:
        print("Lifecycle sweep: no transitions needed")


# ============================================================
# STORY 110.9: Skill Generator (SKILL.md with frontmatter)
# ============================================================

def cmd_generate():
    """Generate SKILL.md files for ACTIVE/PROVEN skills that don't have one yet."""
    if not SKILLS_DIR:
        print("ERROR: cannot determine skills directory (set PRISMA_HOME or run via the gateway)")
        return

    conn = get_db()
    if not conn:
        print("No skills database found.")
        return

    skills = conn.execute(
        """SELECT * FROM skills
           WHERE status IN ('ACTIVE', 'PROVEN')
           AND security_verdict != 'DANGEROUS'"""
    ).fetchall()

    generated = 0
    for skill in skills:
        skill_dir = SKILLS_DIR / skill["name"]
        skill_file = skill_dir / "SKILL.md"

        if skill_file.exists():
            continue  # Already generated

        # Collision detection: check for similar names
        if SKILLS_DIR.exists():
            existing = [d.name for d in SKILLS_DIR.iterdir() if d.is_dir()]
            skill_words = set(skill["name"].replace("-", " ").split())
            for ex in existing:
                ex_words = set(ex.replace("-", " ").split())
                if len(skill_words & ex_words) >= 2:
                    print(f"  SKIP {skill['name']}: collision with {ex}")
                    continue

        # Generate SKILL.md with frontmatter
        content = f"""---
name: {skill["name"]}
description: {skill["description"] or skill["summary"]}
status: {skill["status"]}
created_at: {skill["created_at"]}
last_used_at: {skill["last_used_at"] or skill["created_at"]}
usage_count: {skill["usage_count"]}
source_sessions: ["{skill["source_session_id"]}"]
security_verdict: {skill["security_verdict"]}
origin: auto-generated
---

# {skill["name"]}

{skill["summary"]}

## Files Involved

```json
{skill["files_touched"]}
```

## Usage

This skill was auto-detected from session activity and promoted through the lifecycle:
CANDIDATE → ACTIVE (after {THRESHOLDS["promotion_threshold_active"]} uses) → PROVEN (after {THRESHOLDS["promotion_threshold_proven"]} uses)
"""

        # Atomic write: tempfile → rename
        skill_dir.mkdir(parents=True, exist_ok=True)
        tmp_fd, tmp_path = tempfile.mkstemp(dir=str(skill_dir), suffix=".md")
        try:
            with os.fdopen(tmp_fd, "w") as f:
                f.write(content)
            os.rename(tmp_path, str(skill_file))
            generated += 1
            print(f"  GENERATED {skill['name']}/SKILL.md")
        except Exception as e:
            os.unlink(tmp_path)
            print(f"  ERROR generating {skill['name']}: {e}")

    conn.close()
    print(f"Generated: {generated} SKILL.md files")


# ============================================================
# STORY 110.10: Security Scan command
# ============================================================

def cmd_scan():
    """Scan all PENDING skills for security patterns."""
    conn = get_db()
    if not conn:
        print("No skills database found.")
        return

    pending = conn.execute(
        "SELECT id, name, summary, files_touched FROM skills WHERE security_verdict = 'PENDING'"
    ).fetchall()

    if not pending:
        print("No skills pending security scan.")
        return

    for skill in pending:
        content = f"{skill['summary']} {skill['files_touched']}"

        # Also scan SKILL.md if it exists
        if SKILLS_DIR:
            skill_file = SKILLS_DIR / skill["name"] / "SKILL.md"
            if skill_file.exists():
                content += "\n" + skill_file.read_text()

        result = scan_security(content)
        conn.execute(
            "UPDATE skills SET security_verdict = ? WHERE id = ?",
            (result["verdict"], skill["id"])
        )

        if result["findings"]:
            categories = set(f["category"] for f in result["findings"])
            print(f"  {result['verdict']}: {skill['name']} ({', '.join(categories)})")
        else:
            print(f"  SAFE: {skill['name']}")

    conn.commit()
    conn.close()
    print(f"Scanned: {len(pending)} skills")


# ============================================================
# STORY 110.11: Budget Cap (prompt builder)
# ============================================================

def cmd_budget():
    """Build budget-capped skills prompt to stdout."""
    cfg = load_config()
    conn = get_db()
    if not conn:
        # No skills yet — empty prompt
        return

    # Only ACTIVE + PROVEN, ranked by usage_count desc (PROVEN first)
    skills = conn.execute(
        """SELECT name, description, summary, status, usage_count
           FROM skills
           WHERE status IN ('ACTIVE', 'PROVEN')
           AND security_verdict != 'DANGEROUS'
           ORDER BY
             CASE status WHEN 'PROVEN' THEN 0 ELSE 1 END,
             usage_count DESC
           LIMIT ?""",
        (cfg["max_skills_in_prompt"],)
    ).fetchall()

    conn.close()

    if not skills:
        return

    # Build prompt within token budget (chars/4 approximation)
    max_chars = cfg["max_tokens_skills"] * 4
    lines = ["## Auto-Generated Skills (ranked by usage)\n"]
    total_chars = len(lines[0])

    for skill in skills:
        entry = f"- **{skill['name']}** [{skill['status']}] ({skill['usage_count']}x): {skill['summary'][:100]}\n"
        if total_chars + len(entry) > max_chars:
            lines.append(f"\n_({len(skills) - len(lines) + 1} skills truncated by budget cap)_\n")
            break
        lines.append(entry)
        total_chars += len(entry)

    print("".join(lines))


# ============================================================
# Status command
# ============================================================

def cmd_status():
    """Show lifecycle status summary."""
    conn = get_db()
    if not conn:
        print("No skills database found.")
        return

    rows = conn.execute(
        """SELECT status, count(*) as cnt, sum(usage_count) as total_usage
           FROM skills GROUP BY status ORDER BY
           CASE status
             WHEN 'PROVEN' THEN 1
             WHEN 'ACTIVE' THEN 2
             WHEN 'CANDIDATE' THEN 3
             WHEN 'STALE' THEN 4
             WHEN 'ARCHIVED' THEN 5
           END"""
    ).fetchall()

    total = sum(r["cnt"] for r in rows)
    print(f"Skills Lifecycle Status ({total} total):")
    print(f"{'Status':<12} {'Count':>5} {'Usage':>7}")
    print("-" * 26)
    for r in rows:
        print(f"{r['status']:<12} {r['cnt']:>5} {r['total_usage'] or 0:>7}")

    # Security summary
    sec = conn.execute(
        "SELECT security_verdict, count(*) as cnt FROM skills GROUP BY security_verdict"
    ).fetchall()
    sec_parts = [f"{r['security_verdict']}={r['cnt']}" for r in sec]
    print(f"\nSecurity: {', '.join(sec_parts)}")

    conn.close()


# ============================================================
# Main
# ============================================================

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    commands = {
        "promote": cmd_promote,
        "generate": cmd_generate,
        "scan": cmd_scan,
        "budget": cmd_budget,
        "status": cmd_status,
    }

    if cmd in commands:
        commands[cmd]()
    else:
        print(f"Usage: {sys.argv[0]} [{'/'.join(commands)}]")
        sys.exit(1)
