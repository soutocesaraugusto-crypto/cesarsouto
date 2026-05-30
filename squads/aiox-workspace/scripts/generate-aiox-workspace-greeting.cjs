#!/usr/bin/env node

/**
 * generate-aiox-workspace-greeting.cjs
 *
 * Greeting determinístico para o COO (workspace-chief).
 * Integra scan de diagnóstico + inferência de Next Action.
 *
 * Uso:
 *   node squads/aiox-workspace/scripts/generate-aiox-workspace-greeting.cjs
 *
 * Padrão: GREETING-CONTINUITY-001 (squad-creator-pro/tasks/next-action.md)
 */

const fs = require('fs');
const path = require('path');

let yaml;
try {
  yaml = require('js-yaml');
} catch {
  console.error('ERROR: js-yaml not found.');
  process.exit(1);
}

const ROOT = process.cwd();
const WORKSPACE_BUSINESSES = path.join(ROOT, 'workspace', 'businesses');
const DIAGNOSTICS_DIR = path.join(ROOT, 'docs', 'diagnostics');
const BACKLOG_FILENAME = 'operations/diagnostic-backlog.yaml';
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

// ========================================================================
// DATA COLLECTION (deterministic, no LLM)
// ========================================================================

function countBusinesses() {
  if (!fs.existsSync(WORKSPACE_BUSINESSES)) return 0;
  return fs.readdirSync(WORKSPACE_BUSINESSES)
    .filter(n => {
      const full = path.join(WORKSPACE_BUSINESSES, n);
      return fs.statSync(full).isDirectory() && !n.startsWith('.');
    }).length;
}

function scanBacklogs() {
  const result = { total: 0, pending: 0, businesses: [] };
  if (!fs.existsSync(WORKSPACE_BUSINESSES)) return result;

  const slugs = fs.readdirSync(WORKSPACE_BUSINESSES)
    .filter(n => {
      const full = path.join(WORKSPACE_BUSINESSES, n);
      return fs.statSync(full).isDirectory() && !n.startsWith('.');
    });

  for (const slug of slugs) {
    const bp = path.join(WORKSPACE_BUSINESSES, slug, BACKLOG_FILENAME);
    if (!fs.existsSync(bp)) continue;
    try {
      const data = yaml.load(fs.readFileSync(bp, 'utf8'));
      const items = data.items || [];
      const pending = items.filter(i => (i.status || 'pending') === 'pending');
      if (pending.length > 0) {
        result.total += items.length;
        result.pending += pending.length;
        const top = pending.sort((a, b) => {
          const m = { 'CRÍTICO': 0, 'ALTO': 1, 'MÉDIO': 2, 'BAIXO': 3 };
          return (m[a.priority] ?? 99) - (m[b.priority] ?? 99);
        })[0];
        result.businesses.push({
          slug,
          pending: pending.length,
          top_priority: top ? { id: top.id, dimension: top.dimension, priority: top.priority, command: top.recommended_command } : null
        });
      }
    } catch { /* skip unparseable */ }
  }
  return result;
}

function scanRecentDiagnostics() {
  const reports = [];
  if (!fs.existsSync(DIAGNOSTICS_DIR)) return reports;

  const now = Date.now();
  const files = fs.readdirSync(DIAGNOSTICS_DIR)
    .filter(f => f.endsWith('-diagnostic.md'))
    .sort().reverse();

  for (const file of files) {
    const fp = path.join(DIAGNOSTICS_DIR, file);
    const stat = fs.statSync(fp);
    if (now - stat.mtimeMs > THIRTY_DAYS_MS) continue;

    const match = file.match(/^(\d{4}-\d{2}-\d{2})-(.+)-diagnostic\.md$/);
    if (!match || match[2] === 'all-businesses') continue;

    const [, date, slug] = match;
    let content;
    try { content = fs.readFileSync(fp, 'utf8'); } catch { continue; }

    const report = { slug, date, score: null, classification: null, critical_gaps: [], action_plan: [] };

    const scoreMatch = content.match(/\*\*Score Global:\*\*\s*(\d+)\/100/);
    if (scoreMatch) report.score = parseInt(scoreMatch[1], 10);

    const classMatch = content.match(/\*\*Classificação:\*\*\s*(\S+)/);
    if (classMatch) report.classification = classMatch[1];

    // Extract dimension gaps
    const rows = content.matchAll(
      /\|\s*([A-Za-z][\w\s-]*?)\s*\|\s*\d+%\s*\|\s*(\d+)\/100\s*\|\s*([^\|]+?)\s*\|\s*(.*?)\s*\|/g
    );
    for (const row of rows) {
      const [, dim, score, status, squad] = row;
      const st = status.trim();
      if (st === 'CRÍTICO') {
        report.critical_gaps.push({ dimension: dim.trim(), score: parseInt(score, 10), squad: squad.trim().replace(/^-$/, '') });
      }
    }

    // Extract action plan
    const actions = content.matchAll(
      /\|\s*(\d+)\s*\|\s*(CRÍTICO|ALTO|MÉDIO|BAIXO)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|/g
    );
    for (const row of actions) {
      const [, num, priority, action, command] = row;
      report.action_plan.push({ order: parseInt(num, 10), priority: priority.trim(), action: action.trim(), command: command.trim() });
    }

    reports.push(report);
  }
  return reports;
}

// ========================================================================
// NEXT ACTION INFERENCE (deterministic heuristics)
// ========================================================================

function inferNextAction(businessCount, backlogs, diagnostics) {
  // Priority 1: Blocking gaps — backlog with CRÍTICO items
  for (const b of backlogs.businesses) {
    if (b.top_priority && b.top_priority.priority === 'CRÍTICO') {
      return {
        action: b.top_priority.command || `*backlog-execute ${b.slug} ${b.top_priority.id}`,
        reason: `Backlog CRÍTICO pendente: ${b.top_priority.dimension} (${b.slug})`,
        severity: 'blocking'
      };
    }
  }

  // Priority 2: Recent diagnostic with critical gaps but no backlog
  for (const d of diagnostics) {
    if (d.critical_gaps.length > 0 && !backlogs.businesses.find(b => b.slug === d.slug)) {
      const gap = d.critical_gaps[0];
      return {
        action: d.action_plan.length > 0
          ? `*diagnose-business ${d.slug}` // re-run to get backlog prompt
          : `*diagnose-business ${d.slug}`,
        reason: `${d.slug}: ${gap.dimension} em ${gap.score}/100 (CRÍTICO). Gaps não adicionados ao backlog ainda.`,
        severity: 'blocking'
      };
    }
  }

  // Priority 3: Backlog with ALTO items
  for (const b of backlogs.businesses) {
    if (b.top_priority && b.top_priority.priority === 'ALTO') {
      return {
        action: b.top_priority.command || `*backlog-execute ${b.slug} ${b.top_priority.id}`,
        reason: `Backlog ALTO pendente: ${b.top_priority.dimension} (${b.slug})`,
        severity: 'non_blocking'
      };
    }
  }

  // Priority 4: Recent diagnostic with non-critical attention gaps
  for (const d of diagnostics) {
    if (d.score !== null && d.score < 70) {
      return {
        action: `*growth-levers ${d.slug}`,
        reason: `${d.slug}: score ${d.score}/100 (${d.classification}). Identificar alavancas de crescimento.`,
        severity: 'non_blocking'
      };
    }
  }

  // Priority 5: No diagnostics exist — suggest first diagnostic
  if (diagnostics.length === 0 && businessCount > 0) {
    // Find first business with company-profile.yaml
    if (fs.existsSync(WORKSPACE_BUSINESSES)) {
      const slugs = fs.readdirSync(WORKSPACE_BUSINESSES)
        .filter(n => fs.statSync(path.join(WORKSPACE_BUSINESSES, n)).isDirectory() && !n.startsWith('.'))
        .sort();
      for (const slug of slugs) {
        const cp = path.join(WORKSPACE_BUSINESSES, slug, 'company', 'company-profile.yaml');
        if (fs.existsSync(cp)) {
          return {
            action: `*diagnose-business ${slug}`,
            reason: `Nenhum diagnóstico recente. ${slug} tem dados suficientes para iniciar.`,
            severity: 'intake'
          };
        }
      }
    }
    return {
      action: '*status',
      reason: 'Nenhum business com dados suficientes para diagnóstico.',
      severity: 'intake'
    };
  }

  // Priority 6: Everything is fine
  if (diagnostics.length > 0 && diagnostics.every(d => d.score >= 70)) {
    return {
      action: '*progress-check ' + diagnostics[0].slug,
      reason: `Todos os diagnósticos >= 70. Verificar progresso de ${diagnostics[0].slug}.`,
      severity: 'ready'
    };
  }

  // Fallback
  return {
    action: '*status',
    reason: 'Descreva sua necessidade.',
    severity: 'intake'
  };
}

// ========================================================================
// GREETING BUILDER
// ========================================================================

function buildGreeting(businessCount, backlogs, diagnostics, nextAction) {
  const lines = [];

  // Diagnostic context (if exists)
  if (diagnostics.length > 0) {
    lines.push('## Diagnósticos Recentes');
    lines.push('');
    lines.push('| Business | Score | Status | Gaps Críticos |');
    lines.push('|----------|-------|--------|---------------|');
    for (const d of diagnostics) {
      const gaps = d.critical_gaps.map(g => `${g.dimension}(${g.score})`).join(', ') || 'nenhum';
      lines.push(`| ${d.slug} | ${d.score}/100 | ${d.classification} | ${gaps} |`);
    }
    lines.push('');
  }

  // Backlog context (if exists)
  if (backlogs.pending > 0) {
    lines.push(`## Backlog: ${backlogs.pending} ações pendentes`);
    lines.push('');
    for (const b of backlogs.businesses) {
      const tp = b.top_priority;
      lines.push(`- **${b.slug}:** ${b.pending} pendentes. Top: ${tp ? `${tp.dimension} (${tp.priority})` : 'N/A'}`);
    }
    lines.push('');
  }

  // Quick commands
  lines.push('## Comandos');
  lines.push('');
  lines.push('| Comando | Descrição |');
  lines.push('|---------|-----------|');
  lines.push('| `*diagnose-business {slug}` | Diagnóstico estratégico (10 dimensões) |');
  lines.push('| `*diagnose-offer {slug} {product}` | Diagnóstico vertical da oferta |');
  lines.push('| `*growth-levers {slug}` | Top 3 alavancas de crescimento |');
  lines.push('| `*next-best-action {slug}` | UMA ação prioritária |');
  lines.push('| `*progress-check {slug}` | Progresso vs diagnóstico anterior |');
  lines.push('| `*backlog-status` | Ver ações pendentes |');
  lines.push('| `*setup-business-profile {slug}` | Pipeline de perfil (7 YAMLs) |');
  lines.push('| `*elicit-culture {slug}` | Cultura organizacional |');
  lines.push('| `*help` | Todos os comandos |');
  lines.push('');

  // Next Action CTA (MANDATORY — GREETING-CONTINUITY-001)
  const severityIcon = { blocking: '🔴', non_blocking: '🟡', intake: '🔵', ready: '🟢' };
  lines.push(`**Next Action:** ${severityIcon[nextAction.severity] || '⚪'} \`${nextAction.action}\``);
  lines.push(`> ${nextAction.reason}`);

  return lines.join('\n');
}

// ========================================================================
// MAIN
// ========================================================================

function main() {
  const businessCount = countBusinesses();
  const backlogs = scanBacklogs();
  const diagnostics = scanRecentDiagnostics();
  const nextAction = inferNextAction(businessCount, backlogs, diagnostics);

  const greeting = buildGreeting(businessCount, backlogs, diagnostics, nextAction);

  // Runtime directives (for agent consumption)
  const directives = [
    '<!-- CLEVEL_RUNTIME_DIRECTIVES',
    `businesses_count: ${businessCount}`,
    `backlog_pending: ${backlogs.pending}`,
    `recent_diagnostics: ${diagnostics.length}`,
    `next_action: "${nextAction.action}"`,
    `next_action_severity: "${nextAction.severity}"`,
    `next_action_reason: "${nextAction.reason}"`,
    '-->'
  ].join('\n');

  console.log(directives);
  console.log('');
  console.log(greeting);
}

main();
