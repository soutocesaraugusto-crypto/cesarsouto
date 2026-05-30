#!/usr/bin/env node

/**
 * @aios/media-buyer-squad - Validation Script
 *
 * Validates the integrity of the squad package:
 * - All agent files exist
 * - All skill files exist
 * - Configuration is valid
 * - No broken references
 */

const fs = require('fs');
const path = require('path');

const PACKAGE_ROOT = path.resolve(__dirname, '..');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function success(message) {
  log(`✅ ${message}`, 'green');
}

function error(message) {
  log(`❌ ${message}`, 'red');
}

function warn(message) {
  log(`⚠️  ${message}`, 'yellow');
}

function info(message) {
  log(`ℹ️  ${message}`, 'blue');
}

function header(message) {
  log(`\n${'═'.repeat(60)}`, 'cyan');
  log(`  ${message}`, 'cyan');
  log(`${'═'.repeat(60)}`, 'cyan');
}

let errors = 0;
let warnings = 0;

// ============================================================================
// Validation Functions
// ============================================================================

function validateAgents() {
  header('Validating Agents');

  const agentsDir = path.join(PACKAGE_ROOT, 'agents');
  const expectedAgents = ['ad-midas.md', 'performance-analyst.md', 'creative-analyst.md', 'pixel-specialist.md'];

  for (const agent of expectedAgents) {
    const agentPath = path.join(agentsDir, agent);
    if (fs.existsSync(agentPath)) {
      const content = fs.readFileSync(agentPath, 'utf-8');
      const lines = content.split('\n').length;
      success(`${agent} (${lines} lines)`);
    } else {
      error(`Missing agent: ${agent}`);
      errors++;
    }
  }
}

function validateSkills() {
  header('Validating Skills');

  const skillsDir = path.join(PACKAGE_ROOT, 'skills');
  const categories = ['diagnostic', 'generative', 'optimization', 'strategic', 'automation'];

  const expectedSkills = {
    diagnostic: ['metric-diagnosis', 'tracking-audit', 'creative-fatigue-detector', 'funnel-analysis', 'attribution-analysis'],
    generative: ['hook-generator', 'copy-generator', 'creative-brief', 'angle-generator', 'dsl-structure'],
    optimization: ['kill-scale-rules', 'budget-allocation', 'audience-expansion'],
    strategic: ['funnel-selection', 'unit-economics', 'scale-readiness-check', 'campaign-structure'],
    automation: ['campaign-monitor']
  };

  let totalSkills = 0;

  for (const category of categories) {
    info(`Category: ${category}`);
    const categoryDir = path.join(skillsDir, category);

    if (!fs.existsSync(categoryDir)) {
      error(`  Missing category directory: ${category}`);
      errors++;
      continue;
    }

    for (const skill of expectedSkills[category]) {
      const skillDir = path.join(categoryDir, skill);
      const skillFile = path.join(skillDir, 'SKILL.md');

      if (fs.existsSync(skillFile)) {
        success(`  ${skill}/SKILL.md`);
        totalSkills++;
      } else if (fs.existsSync(skillDir)) {
        warn(`  ${skill}/ exists but missing SKILL.md`);
        warnings++;
      } else {
        error(`  Missing skill: ${skill}`);
        errors++;
      }
    }
  }

  info(`Total skills validated: ${totalSkills}/18`);
}

function validateConfig() {
  header('Validating Configuration');

  const configDir = path.join(PACKAGE_ROOT, 'config');
  const expectedConfigs = ['squad.yaml', 'registry.yaml', 'router.yaml'];

  for (const config of expectedConfigs) {
    const configPath = path.join(configDir, config);
    if (fs.existsSync(configPath)) {
      const content = fs.readFileSync(configPath, 'utf-8');
      const lines = content.split('\n').length;
      success(`${config} (${lines} lines)`);
    } else {
      error(`Missing config: ${config}`);
      errors++;
    }
  }

  // Validate config module
  try {
    const configModule = require('../config');
    const validation = configModule.validateConfig();

    if (validation.valid) {
      success('Configuration cross-references valid');
    } else {
      for (const issue of validation.issues) {
        error(`  ${issue}`);
        errors++;
      }
    }
  } catch (e) {
    error(`Config module error: ${e.message}`);
    errors++;
  }
}

function validateLib() {
  header('Validating Library');

  const libFiles = [
    { path: 'lib/index.js', desc: 'Main module' },
    { path: 'lib/index.d.ts', desc: 'TypeScript definitions' },
    { path: 'mcp/index.js', desc: 'MCP configuration' },
    { path: 'config/index.js', desc: 'Config loader' }
  ];

  for (const file of libFiles) {
    const filePath = path.join(PACKAGE_ROOT, file.path);
    if (fs.existsSync(filePath)) {
      success(`${file.path} - ${file.desc}`);
    } else {
      error(`Missing: ${file.path}`);
      errors++;
    }
  }

  // Test main module loads
  try {
    const squad = require('../lib');
    success('Main module loads successfully');

    // Verify exports
    const requiredExports = ['squad', 'registry', 'router', 'agents', 'loadSkill', 'routeIntent', 'getMcpConfig', 'install'];
    for (const exp of requiredExports) {
      if (squad[exp]) {
        success(`  Export: ${exp}`);
      } else {
        error(`  Missing export: ${exp}`);
        errors++;
      }
    }
  } catch (e) {
    error(`Main module error: ${e.message}`);
    errors++;
  }
}

function validateMcp() {
  header('Validating MCP Configuration');

  try {
    const mcp = require('../mcp');

    // Test generateMcpConfig
    const config = mcp.generateMcpConfig();
    if (config.mcpServers.exa && config.mcpServers.context7) {
      success('generateMcpConfig() works');
    } else {
      error('Missing required MCP servers in config');
      errors++;
    }

    // Test getAvailableTools
    const tools = mcp.getAvailableTools();
    const expectedServers = ['exa', 'context7', 'playwright', 'meta-pixel', 'meta-ads'];
    for (const server of expectedServers) {
      if (tools[server]) {
        success(`  MCP tools: ${server} (${tools[server].tools.length} tools)`);
      } else {
        warn(`  MCP tools: ${server} not defined`);
        warnings++;
      }
    }

    // Test validateMcpConfig
    const validation = mcp.validateMcpConfig(config);
    if (validation.valid) {
      success('MCP config validation works');
    } else {
      error(`MCP validation failed: ${validation.missing.join(', ')}`);
      errors++;
    }
  } catch (e) {
    error(`MCP module error: ${e.message}`);
    errors++;
  }
}

function validatePackageJson() {
  header('Validating package.json');

  const packagePath = path.join(PACKAGE_ROOT, 'package.json');

  try {
    const pkg = require(packagePath);

    // Check required fields
    const requiredFields = ['name', 'version', 'description', 'main', 'types', 'exports'];
    for (const field of requiredFields) {
      if (pkg[field]) {
        success(`${field}: ${typeof pkg[field] === 'object' ? 'defined' : pkg[field]}`);
      } else {
        error(`Missing field: ${field}`);
        errors++;
      }
    }

    // Check exports
    if (pkg.exports) {
      const requiredExports = ['.', './agents', './skills', './mcp', './config'];
      for (const exp of requiredExports) {
        if (pkg.exports[exp]) {
          success(`  Export: ${exp}`);
        } else {
          warn(`  Missing export: ${exp}`);
          warnings++;
        }
      }
    }
  } catch (e) {
    error(`package.json error: ${e.message}`);
    errors++;
  }
}

function validateData() {
  header('Validating Data Directories');

  const dataDirs = [
    { path: 'data', desc: 'Data directory' },
    { path: 'tasks', desc: 'Task definitions' },
    { path: 'templates', desc: 'Output templates' },
    { path: 'checklists', desc: 'Validation checklists' }
  ];

  for (const dir of dataDirs) {
    const dirPath = path.join(PACKAGE_ROOT, dir.path);
    if (fs.existsSync(dirPath)) {
      const files = fs.readdirSync(dirPath);
      success(`${dir.path}/ - ${dir.desc} (${files.length} items)`);
    } else {
      warn(`${dir.path}/ - Not found (optional)`);
      warnings++;
    }
  }
}

// ============================================================================
// Main Execution
// ============================================================================

function main() {
  console.log(`
╔══════════════════════════════════════════════════════════════════════════════╗
║               @aios/media-buyer-squad - Validation Report                     ║
╚══════════════════════════════════════════════════════════════════════════════╝
`);

  validatePackageJson();
  validateAgents();
  validateSkills();
  validateConfig();
  validateLib();
  validateMcp();
  validateData();

  // Summary
  header('Validation Summary');

  if (errors === 0 && warnings === 0) {
    log(`
  ✅ All validations passed!

  The squad package is ready for distribution.
`, 'green');
  } else {
    console.log(`
  Results:
    • Errors:   ${errors}
    • Warnings: ${warnings}
`);

    if (errors > 0) {
      log('  ❌ Validation failed. Please fix errors before publishing.', 'red');
      process.exit(1);
    } else {
      log('  ⚠️  Validation passed with warnings.', 'yellow');
    }
  }
}

main();
