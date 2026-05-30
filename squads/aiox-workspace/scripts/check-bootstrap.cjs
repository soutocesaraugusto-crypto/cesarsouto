#!/usr/bin/env node
/**
 * check-bootstrap.cjs
 *
 * Gate determinístico do COO. Verifica se o workspace tem os 5 items obrigatórios.
 * Roda ANTES de qualquer task do aiox-workspace squad.
 *
 * Usage:
 *   node squads/aiox-workspace/scripts/check-bootstrap.cjs
 *
 * Exit code 0 = PASS, exit code 1 = FAIL
 * Output: JSON { status, missing, found }
 */

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..', '..');

const REQUIRED = [
  { id: 'user_yaml', path: 'workspace/user.yaml', type: 'file' },
  { id: 'config_yaml', path: 'workspace/config.yaml', type: 'file' },
  { id: 'canonical_sources', path: 'workspace/canonical-sources.yaml', type: 'file' },
  { id: 'businesses_dir', path: 'workspace/businesses', type: 'dir' },
  { id: 'templates_dir', path: 'workspace/_templates', type: 'dir' },
];

function check() {
  const found = [];
  const missing = [];

  for (const item of REQUIRED) {
    const fullPath = path.join(ROOT, item.path);
    const exists = item.type === 'dir'
      ? fs.existsSync(fullPath) && fs.statSync(fullPath).isDirectory()
      : fs.existsSync(fullPath) && fs.statSync(fullPath).isFile();

    if (exists) {
      found.push(item.id);
    } else {
      missing.push({ id: item.id, path: item.path, type: item.type });
    }
  }

  const status = missing.length === 0 ? 'PASS' : 'FAIL';

  return { status, found, missing };
}

const result = check();

console.log(JSON.stringify(result, null, 2));

process.exit(result.status === 'PASS' ? 0 : 1);
