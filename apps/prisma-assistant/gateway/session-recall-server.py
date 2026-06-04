#!/usr/bin/env python3
"""
Session Recall MCP Server — Epic 110 Story 110.6

Lightweight MCP server that provides a session_recall tool for searching
past Claude Code sessions stored in SQLite FTS5.

Usage:
    python3 gateway/session-recall-server.py

Configuration via environment:
    CRM_AGENT_NAME  - Agent name (default: prisma)
    CRM_ROOT        - CRM state root (default: ~/.claude-remote/default)

Design reference: Hermes session_search_tool.py (FTS queries, truncation)
"""

import json
import os
import sqlite3
import sys
from pathlib import Path

AGENT = os.environ.get("CRM_AGENT_NAME", "prisma")
CRM_ROOT = os.environ.get("CRM_ROOT", str(Path.home() / ".claude-remote" / "default"))
# Expand tilde — env vars from JSON config are NOT shell-expanded (F3 fix, Story 110.25)
CRM_ROOT = str(Path(CRM_ROOT).expanduser())
DB_PATH = Path(CRM_ROOT) / "state" / AGENT / "sessions.db"

# MCP protocol constants
JSONRPC = "2.0"

def get_db():
    """Get SQLite connection with WAL mode."""
    if not DB_PATH.exists():
        return None
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=3000")
    return conn

def search_sessions(query: str, limit: int = 3) -> list:
    """Search sessions using FTS5. Returns summarized results."""
    conn = get_db()
    if not conn:
        return [{"error": "No sessions database found. Sessions will be stored after the first session ends."}]

    try:
        if not query or not query.strip():
            # No query — return latest sessions metadata only
            rows = conn.execute(
                """SELECT id, started_at, ended_at, duration_seconds, cwd
                   FROM sessions ORDER BY ended_at DESC LIMIT ?""",
                (min(limit, 5),)
            ).fetchall()
            return [
                {
                    "session_id": r["id"],
                    "date": r["ended_at"],
                    "duration_minutes": round((r["duration_seconds"] or 0) / 60, 1),
                    "cwd": r["cwd"],
                }
                for r in rows
            ]

        # FTS5 search with snippet
        rows = conn.execute(
            """SELECT f.session_id,
                      snippet(messages_fts, 1, '>>>', '<<<', '...', 40) as excerpt,
                      s.ended_at, s.duration_seconds
               FROM messages_fts f
               JOIN sessions s ON s.id = f.session_id
               WHERE messages_fts MATCH ?
               ORDER BY rank
               LIMIT ?""",
            (query, min(limit, 5))
        ).fetchall()

        if not rows:
            return [{"message": f"No sessions found matching '{query}'."}]

        results = []
        for r in rows:
            # Truncate excerpt around match (Hermes pattern)
            excerpt = r["excerpt"] or ""
            if len(excerpt) > 500:
                # Find match markers and center around them
                start = max(0, excerpt.find(">>>") - 100)
                end = min(len(excerpt), excerpt.rfind("<<<") + 100)
                excerpt = "..." + excerpt[start:end] + "..."

            results.append({
                "session_id": r["session_id"],
                "date": r["ended_at"],
                "duration_minutes": round((r["duration_seconds"] or 0) / 60, 1),
                "excerpt": excerpt,
            })

        return results

    except Exception as e:
        return [{"error": f"Search failed: {str(e)}"}]
    finally:
        conn.close()

def handle_request(request: dict) -> dict:
    """Handle a JSON-RPC request."""
    method = request.get("method", "")
    req_id = request.get("id")

    if method == "initialize":
        return {
            "jsonrpc": JSONRPC,
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {
                    "name": "session-recall",
                    "version": "1.0.0"
                }
            }
        }

    if method == "notifications/initialized":
        return None  # No response for notifications

    if method == "tools/list":
        return {
            "jsonrpc": JSONRPC,
            "id": req_id,
            "result": {
                "tools": [
                    {
                        "name": "session_recall",
                        "description": "Search past Claude Code sessions. Use to answer 'what did I do last week?' or find context from previous work. Returns session excerpts with FTS5 full-text search.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "query": {
                                    "type": "string",
                                    "description": "Search query (keywords). Leave empty to list recent sessions."
                                },
                                "limit": {
                                    "type": "integer",
                                    "description": "Max results (1-5, default 3)",
                                    "default": 3,
                                    "minimum": 1,
                                    "maximum": 5
                                }
                            },
                            "required": []
                        }
                    }
                ]
            }
        }

    if method == "tools/call":
        args = request.get("params", {}).get("arguments", {})
        tool_name = request.get("params", {}).get("name", "")

        if tool_name == "session_recall":
            query = args.get("query", "")
            limit = min(int(args.get("limit", 3)), 5)
            results = search_sessions(query, limit)
            return {
                "jsonrpc": JSONRPC,
                "id": req_id,
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(results, indent=2, ensure_ascii=False)
                        }
                    ]
                }
            }

        return {
            "jsonrpc": JSONRPC,
            "id": req_id,
            "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"}
        }

    if method == "ping":
        return {"jsonrpc": JSONRPC, "id": req_id, "result": {}}

    return None

def main():
    """MCP stdio transport: read JSON-RPC from stdin, write to stdout."""
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            continue

        response = handle_request(request)
        if response:
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
