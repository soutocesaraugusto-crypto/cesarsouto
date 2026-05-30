#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const {
  getProductReadinessConsumerConfig,
  getProductReadinessNarrativeArtifactsConfig,
  getSupportedProductReadinessConsumers,
} = require('./lib/workspace-governance.cjs');

const ROOT = process.cwd();

function normalizePath(filePath) {
  return filePath.split(path.sep).join('/');
}

function toRelative(targetPath) {
  return normalizePath(path.relative(ROOT, targetPath) || '.');
}

function readYaml(filePath) {
  return yaml.load(fs.readFileSync(filePath, 'utf8')) || {};
}

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    business: null,
    product: null,
    consumer: null,
    format: 'json',
  };

  for (const raw of argv) {
    if (raw.startsWith('--business=')) {
      args.business = raw.slice('--business='.length).trim() || null;
      continue;
    }
    if (raw.startsWith('--product=')) {
      args.product = raw.slice('--product='.length).trim() || null;
      continue;
    }
    if (raw.startsWith('--consumer=')) {
      args.consumer = raw.slice('--consumer='.length).trim() || null;
      continue;
    }
    if (raw.startsWith('--format=')) {
      args.format = raw.slice('--format='.length).trim() || 'json';
    }
  }

  return args;
}

function parseScore(score) {
  if (typeof score !== 'string') return null;
  const match = score.match(/^\s*(\d+)\s*\/\s*(\d+)\s*$/);
  if (!match) return null;
  return {
    current: Number(match[1]),
    total: Number(match[2]),
  };
}

function fileRecord(relPath, label, required = true) {
  const absPath = path.join(ROOT, relPath);
  return {
    id: label,
    label,
    path: relPath,
    exists: fs.existsSync(absPath),
    required,
  };
}

function compileRelativePath(businessRootRel, sourceConfig, productSlug) {
  const relativePath = String(sourceConfig.path || '').replace('{product}', productSlug);
  return `${businessRootRel}/${relativePath}`;
}

function buildConfiguredFileRecords(businessRootRel, consumerConfig, productSlug) {
  const shared = Array.isArray(consumerConfig.required_shared_sources)
    ? consumerConfig.required_shared_sources.map((sourceConfig) =>
        fileRecord(compileRelativePath(businessRootRel, sourceConfig, productSlug), sourceConfig.id, true)
      )
    : [];

  const product = Array.isArray(consumerConfig.required_product_sources)
    ? consumerConfig.required_product_sources.map((sourceConfig) =>
        fileRecord(compileRelativePath(businessRootRel, sourceConfig, productSlug), sourceConfig.id, true)
      )
    : [];

  return { shared, product };
}

function findStructureCandidate(productRootRel) {
  const candidates = [
    `${productRootRel}/curriculum.yaml`,
    `${productRootRel}/agenda.yaml`,
    `${productRootRel}/deliverables.yaml`,
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(path.join(ROOT, candidate))) {
      return { path: candidate, source: 'file' };
    }
  }

  const offerbookPath = `${productRootRel}/offerbook.yaml`;
  if (!fs.existsSync(path.join(ROOT, offerbookPath))) {
    return null;
  }

  const content = readText(path.join(ROOT, offerbookPath));
  if (/^curriculum_summary:|^agenda:|^\s*agenda_[a-z0-9_]+:|^\s*deliverables?:/m.test(content)) {
    return { path: offerbookPath, source: 'offerbook_section' };
  }

  return null;
}

function findPricingSource(productRootRel) {
  const directCandidates = [
    `${productRootRel}/pricing.yaml`,
    `${productRootRel}/pricing-strategy.yaml`,
    `${productRootRel}/curriculum.yaml`,
    `${productRootRel}/offerbook.yaml`,
  ];

  for (const candidate of directCandidates) {
    const absPath = path.join(ROOT, candidate);
    if (!fs.existsSync(absPath)) {
      continue;
    }
    const content = readText(absPath);
    if (/^pricing:|^\s*preco:|^\s*investimento:|^\s*valor_ancoragem_e_bonus:/m.test(content)) {
      return candidate;
    }
  }

  return null;
}

function collectNarrativeFiles(businessRootRel, productSlug) {
  const registry = getProductReadinessNarrativeArtifactsConfig();
  const companySources = Array.isArray(registry.company) ? registry.company : [];
  const productSources = Array.isArray(registry.product) ? registry.product : [];

  return {
    company: companySources
      .map((sourceConfig) => compileRelativePath(businessRootRel, sourceConfig, productSlug))
      .filter((candidate) => fs.existsSync(path.join(ROOT, candidate))),
    product: productSources
      .map((sourceConfig) => compileRelativePath(businessRootRel, sourceConfig, productSlug))
      .filter((candidate) => fs.existsSync(path.join(ROOT, candidate))),
  };
}

function getComplianceAudit(index, productSlug) {
  return index.prerequisites_gate &&
    index.prerequisites_gate.compliance_audit &&
    index.prerequisites_gate.compliance_audit[productSlug]
    ? index.prerequisites_gate.compliance_audit[productSlug]
    : null;
}

function resolveProductReadiness({ business, product, consumer }) {
  const consumerConfig = consumer ? getProductReadinessConsumerConfig(consumer) : null;
  const supportedConsumers = getSupportedProductReadinessConsumers();

  if (!consumer || !consumerConfig) {
    throw new Error(`Unsupported consumer "${consumer}". Allowed: ${supportedConsumers.join(', ')}`);
  }
  if (!business) {
    throw new Error('Missing business slug');
  }
  if (!product) {
    throw new Error('Missing product slug');
  }

  const businessRootRel = `workspace/businesses/${business}`;
  const businessRootAbs = path.join(ROOT, businessRootRel);
  if (!fs.existsSync(businessRootAbs)) {
    throw new Error(`Business not found: ${businessRootRel}`);
  }

  const productRootRel = `${businessRootRel}/products/${product}`;
  const productRootAbs = path.join(ROOT, productRootRel);
  if (!fs.existsSync(productRootAbs)) {
    throw new Error(`Product not found: ${productRootRel}`);
  }

  const companyOfferbookRel = `${businessRootRel}/company/offerbook.yaml`;
  const companyOfferbookAbs = path.join(ROOT, companyOfferbookRel);
  const companyOfferbook = fs.existsSync(companyOfferbookAbs) ? readYaml(companyOfferbookAbs) : {};
  const complianceAudit = getComplianceAudit(companyOfferbook, product);
  const complianceScore = complianceAudit ? parseScore(complianceAudit.score) : null;

  const configuredFiles = buildConfiguredFileRecords(businessRootRel, consumerConfig, product);
  const sharedFiles = configuredFiles.shared;
  const productFiles = configuredFiles.product;

  const optionalFiles = [];
  if (fs.existsSync(path.join(ROOT, `${productRootRel}/testimonials.yaml`))) {
    optionalFiles.push(fileRecord(`${productRootRel}/testimonials.yaml`, 'testimonials', false));
  }
  if (fs.existsSync(path.join(ROOT, `${productRootRel}/curriculum.yaml`))) {
    optionalFiles.push(fileRecord(`${productRootRel}/curriculum.yaml`, 'curriculum', false));
  }

  const structureSource = findStructureCandidate(productRootRel);
  const pricingSource = findPricingSource(productRootRel);
  const narrativeFiles = collectNarrativeFiles(businessRootRel, product);

  const requirements = [
    ...sharedFiles,
    ...productFiles,
    {
      id: 'product_structure',
      label: 'product_structure',
      path: structureSource ? structureSource.path : null,
      exists: Boolean(structureSource),
      required: false,
      source: structureSource ? structureSource.source : null,
    },
    {
      id: 'pricing',
      label: 'pricing',
      path: pricingSource,
      exists: Boolean(pricingSource),
      required: true,
    },
  ];

  const missingRequired = requirements.filter((item) => item.required && !item.exists);
  const readyByFiles = missingRequired.length === 0;

  let status = 'ready';
  const reasons = [];

  if (!readyByFiles) {
    status = 'blocked';
    reasons.push('Missing required canonical sources');
  }

  if (complianceScore) {
    if (complianceScore.current <= 5) {
      status = 'blocked';
      reasons.push(`Offerbook prerequisites gate below minimum (${complianceAudit.score})`);
    } else if (complianceScore.current === 6 && status !== 'blocked') {
      status = 'draft';
      reasons.push(`Offerbook prerequisites gate is partial (${complianceAudit.score})`);
    }
  }

  if (complianceAudit && /partial|missing|not exist|nao existem/i.test(complianceAudit.status || '')) {
    if (status !== 'blocked') {
      status = 'draft';
    }
    reasons.push(complianceAudit.status);
  }

  return {
    consumer,
    business_slug: business,
    product_slug: product,
    status,
    company_offerbook_index: fs.existsSync(companyOfferbookAbs) ? companyOfferbookRel : null,
    compliance_audit: complianceAudit
      ? {
          score: complianceAudit.score || null,
          status: complianceAudit.status || null,
          action: complianceAudit.action || null,
        }
      : null,
    requirements,
    missing_required: missingRequired,
    optional_files: optionalFiles,
    narrative_files: narrativeFiles,
    reasons,
  };
}

function printOutput(output, format) {
  if (format === 'yaml') {
    process.stdout.write(yaml.dump(output, { lineWidth: 120, noRefs: true, sortKeys: false }));
    return;
  }
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const supportedConsumers = getSupportedProductReadinessConsumers();
  if (!args.consumer) {
    fail(`Provide --consumer=${supportedConsumers.join('|')}`);
  }
  if (!args.product) {
    fail('Provide --product=<slug>');
  }

  try {
    const output = resolveProductReadiness(args);
    printOutput(output, args.format);
  } catch (error) {
    fail(error.message);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  resolveProductReadiness,
};
