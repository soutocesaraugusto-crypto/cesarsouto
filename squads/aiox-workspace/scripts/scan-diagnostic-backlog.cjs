#!/usr/bin/env node

/**
 * scan-diagnostic-backlog.cjs
 *
 * Escaneia DUAS fontes de diagnóstico e retorna JSON determinístico:
 * 1. diagnostic-backlog.yaml — items pendentes aprovados pelo usuário
 * 2. docs/diagnostics/ — relatórios de diagnóstico recentes (últimos 30 dias)
 *
 * Uso:
 *   node squads/aiox-workspace/scripts/scan-diagnostic-backlog.cjs
 *   node squads/aiox-workspace/scripts/scan-diagnostic-backlog.cjs --business=aiox
 *   node squads/aiox-workspace/scripts/scan-diagnostic-backlog.cjs --format=full
 */

const fs = require('fs');
const path = require('path');

let yaml;
try {
  yaml = require('js-yaml');
} catch {
  console.error('ERROR: js-yaml not found. Run from repo root or install dependency.');
  process.exit(1);
}

const ROOT = process.cwd();
const WORKSPACE_BUSINESSES = path.join(ROOT, 'workspace', 'businesses');
const DIAGNOSTICS_DIR = path.join(ROOT, 'docs', 'diagnostics');
const BACKLOG_FILENAME = 'operations/diagnostic-backlog.yaml';
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

function parseArgs(argv) {
  const args = { business: null, format: 'summary' };
  for (const raw of argv.slice(2)) {
    if (raw.startsWith('--business=') || raw.startsWith('--bu=')) {
      args.business = raw.split('=')[1].trim() || null;
    }
    if (raw.startsWith('--format=')) {
      args.format = raw.split('=')[1].trim() || 'summary';
    }
  }
  return args;
}

// ========== BACKLOG SCANNING ==========

function loadBacklog(businessPath) {
  const backlogPath = path.join(businessPath, BACKLOG_FILENAME);
  if (!fs.existsSync(backlogPath)) return null;
  try {
    const content = fs.readFileSync(backlogPath, 'utf8');
    return yaml.load(content);
  } catch (err) {
    return { _parse_error: err.message };
  }
}

function classifyItems(items) {
  const counts = { total: 0, pending: 0, in_progress: 0, done: 0, skipped: 0 };
  const pendingItems = [];
  if (!Array.isArray(items)) return { counts, pendingItems };

  for (const item of items) {
    counts.total++;
    const status = (item.status || 'pending').toLowerCase();
    if (status === 'pending') { counts.pending++; pendingItems.push(item); }
    else if (status === 'in_progress') { counts.in_progress++; }
    else if (status === 'done') { counts.done++; }
    else if (status === 'skipped') { counts.skipped++; }
  }
  return { counts, pendingItems };
}

function getPriorityOrder(priority) {
  const map = { 'CRÍTICO': 0, 'ALTO': 1, 'MÉDIO': 2, 'BAIXO': 3 };
  return map[priority] ?? 99;
}

// ========== DIAGNOSTIC REPORT SCANNING ==========

function scanDiagnosticReports(businessFilter) {
  const reports = [];
  if (!fs.existsSync(DIAGNOSTICS_DIR)) return reports;

  const now = Date.now();
  const files = fs.readdirSync(DIAGNOSTICS_DIR)
    .filter(f => f.endsWith('-diagnostic.md'))
    .sort()
    .reverse();

  for (const file of files) {
    const filePath = path.join(DIAGNOSTICS_DIR, file);
    const stat = fs.statSync(filePath);

    // Skip files older than 30 days
    if (now - stat.mtimeMs > THIRTY_DAYS_MS) continue;

    // Extract slug from filename: YYYY-MM-DD-{slug}-diagnostic.md
    const match = file.match(/^(\d{4}-\d{2}-\d{2})-(.+)-diagnostic\.md$/);
    if (!match) continue;

    const [, date, slug] = match;
    if (slug === 'all-businesses') continue;
    if (businessFilter && slug !== businessFilter) continue;

    // Parse report for key data
    const report = parseReport(filePath, date, slug);
    if (report) reports.push(report);
  }

  return reports;
}

function parseReport(filePath, date, slug) {
  let content;
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }

  const report = {
    slug,
    date,
    file: path.relative(ROOT, filePath),
    score: null,
    classification: null,
    critical_gaps: [],
    attention_gaps: [],
    action_plan: []
  };

  // Extract global score: **Score Global:** 68/100
  const scoreMatch = content.match(/\*\*Score Global:\*\*\s*(\d+)\/100/);
  if (scoreMatch) report.score = parseInt(scoreMatch[1], 10);

  // Extract classification: **Classificação:** ATENÇÃO
  const classMatch = content.match(/\*\*Classificação:\*\*\s*(\S+)/);
  if (classMatch) report.classification = classMatch[1];

  // Extract dimension scores from the summary table
  // Pattern: | DimensionName | XX% | YY/100 | STATUS | squad |
  // Status can be: CRÍTICO, ATENÇÃO, ADEQUADO, FORTE (unicode chars)
  const tableRows = content.matchAll(
    /\|\s*([A-Za-z][\w\s-]*?)\s*\|\s*\d+%\s*\|\s*(\d+)\/100\s*\|\s*([^\|]+?)\s*\|\s*(.*?)\s*\|/g
  );
  for (const row of tableRows) {
    const [, dimension, score, status, squad] = row;
    const dim = dimension.trim();
    const sc = parseInt(score, 10);
    const st = status.trim();
    const sq = squad.trim().replace(/^-$/, '');

    if (st === 'CRÍTICO') {
      report.critical_gaps.push({ dimension: dim, score: sc, squad: sq || null });
    } else if (st === 'ATENÇÃO') {
      report.attention_gaps.push({ dimension: dim, score: sc, squad: sq || null });
    }
  }

  // Extract action plan items from numbered table rows
  // Pattern: | N | PRIORIDADE | Ação | Comando |
  const actionRows = content.matchAll(
    /\|\s*(\d+)\s*\|\s*(CRÍTICO|ALTO|MÉDIO|BAIXO)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|/g
  );
  for (const row of actionRows) {
    const [, num, priority, action, command] = row;
    report.action_plan.push({
      order: parseInt(num, 10),
      priority: priority.trim(),
      action: action.trim(),
      command: command.trim()
    });
  }

  return report;
}

// ========== MAIN ==========

function main() {
  const args = parseArgs(process.argv);

  const result = {
    scanned_at: new Date().toISOString(),
    // Backlog section
    backlog: {
      businesses_scanned: 0,
      total_items: 0,
      pending_items: 0,
      in_progress_items: 0,
      done_items: 0,
      businesses: []
    },
    // Recent diagnostics section
    recent_diagnostics: {
      reports_found: 0,
      reports: []
    }
  };

  // ---- Scan backlogs ----
  if (fs.existsSync(WORKSPACE_BUSINESSES)) {
    let slugs;
    if (args.business) {
      const bPath = path.join(WORKSPACE_BUSINESSES, args.business);
      slugs = fs.existsSync(bPath) ? [args.business] : [];
    } else {
      slugs = fs.readdirSync(WORKSPACE_BUSINESSES)
        .filter(name => {
          const full = path.join(WORKSPACE_BUSINESSES, name);
          return fs.statSync(full).isDirectory() && !name.startsWith('.');
        })
        .sort();
    }

    result.backlog.businesses_scanned = slugs.length;

    for (const slug of slugs) {
      const businessPath = path.join(WORKSPACE_BUSINESSES, slug);
      const backlog = loadBacklog(businessPath);

      if (!backlog) continue;

      const entry = { slug, total: 0, pending: 0, in_progress: 0, done: 0, top_priority: null };

      if (!backlog._parse_error) {
        const { counts, pendingItems } = classifyItems(backlog.items || []);
        entry.total = counts.total;
        entry.pending = counts.pending;
        entry.in_progress = counts.in_progress;
        entry.done = counts.done;

        if (pendingItems.length > 0) {
          pendingItems.sort((a, b) => getPriorityOrder(a.priority) - getPriorityOrder(b.priority));
          entry.top_priority = {
            id: pendingItems[0].id,
            dimension: pendingItems[0].dimension,
            priority: pendingItems[0].priority,
            recommended_command: pendingItems[0].recommended_command
          };
        }

        if (args.format === 'full') {
          entry.items = pendingItems;
        }
      }

      result.backlog.total_items += entry.total;
      result.backlog.pending_items += entry.pending;
      result.backlog.in_progress_items += entry.in_progress;
      result.backlog.done_items += entry.done;
      result.backlog.businesses.push(entry);
    }
  }

  // ---- Scan recent diagnostics ----
  const reports = scanDiagnosticReports(args.business);
  result.recent_diagnostics.reports_found = reports.length;
  result.recent_diagnostics.reports = reports;

  console.log(JSON.stringify(result, null, 2));
}

main();
