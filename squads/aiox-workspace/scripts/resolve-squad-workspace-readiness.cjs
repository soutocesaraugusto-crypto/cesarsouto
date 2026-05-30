#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

let designResolver;
try {
  designResolver = require('../../aiox-design/scripts/design-system/resolve_business_design_system.cjs');
} catch {
  designResolver = null;
}
const { resolveProductReadiness } = require('./resolve-product-readiness.cjs');
const {
  getSupportedSquads,
  getSquadReadinessConfig,
} = require('./lib/workspace-governance.cjs');

const ROOT = process.cwd();
const WORKSPACE_CONFIG_PATH = 'workspace/config.yaml';

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    squad: null,
    business: null,
    product: null,
    app: null,
    contextType: null,
    format: 'json',
  };

  for (const raw of argv) {
    if (raw.startsWith('--squad=')) {
      args.squad = raw.slice('--squad='.length).trim() || null;
      continue;
    }
    if (raw.startsWith('--business=')) {
      args.business = raw.slice('--business='.length).trim() || null;
      continue;
    }
    if (raw.startsWith('--bu=')) {
      args.business = raw.slice('--bu='.length).trim() || null;
      continue;
    }
    if (raw.startsWith('--product=')) {
      args.product = raw.slice('--product='.length).trim() || null;
      continue;
    }
    if (raw.startsWith('--app=')) {
      args.app = raw.slice('--app='.length).trim() || null;
      continue;
    }
    if (raw.startsWith('--context-type=')) {
      args.contextType = raw.slice('--context-type='.length).trim() || null;
      continue;
    }
    if (raw.startsWith('--format=')) {
      args.format = raw.slice('--format='.length).trim() || 'json';
    }
  }

  return args;
}

function normalizePath(filePath) {
  return filePath.split(path.sep).join('/');
}

function toRelative(targetPath) {
  return normalizePath(path.relative(ROOT, targetPath) || '.');
}

function uniq(items) {
  return [...new Set(items.filter(Boolean))];
}

function readYaml(filePath) {
  return yaml.load(fs.readFileSync(filePath, 'utf8')) || {};
}

function getWorkspaceConfig() {
  return readYaml(path.join(ROOT, WORKSPACE_CONFIG_PATH));
}

function loadSquadConfig(squad) {
  const candidates = [
    path.join(ROOT, 'squads', squad, 'config.yaml'),
    path.join(ROOT, 'squads', squad, 'squad.yaml'),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return {
        path: toRelative(candidate),
        data: readYaml(candidate),
      };
    }
  }

  return null;
}

function getIntegrationMode(squadConfig, squad) {
  const readinessConfig = getSquadReadinessConfig(squad);
  const declared = squadConfig && squadConfig.data && squadConfig.data.workspace_integration
    ? squadConfig.data.workspace_integration.level || null
    : null;

  if (declared) {
    return {
      declared: true,
      level: declared,
      config_path: squadConfig.path,
    };
  }

  return {
    declared: false,
    level: readinessConfig ? readinessConfig.fallback_integration_level || 'none' : 'none',
    config_path: squadConfig ? squadConfig.path : null,
  };
}

function getAllowedWritePaths(squadConfig) {
  const writePaths = squadConfig && squadConfig.data && squadConfig.data.workspace_integration
    ? squadConfig.data.workspace_integration.write_paths
    : [];

  return Array.isArray(writePaths) ? writePaths : [];
}

function findBusiness(workspaceConfig, businessSlug) {
  if (!workspaceConfig || !Array.isArray(workspaceConfig.businesses) || !businessSlug) {
    return null;
  }
  return workspaceConfig.businesses.find((b) => b.slug === businessSlug) || null;
}

function getBusinessCapabilityStatus(workspaceConfig, businessSlug, capability) {
  const business = findBusiness(workspaceConfig, businessSlug);
  if (!business || !business.capabilities || !business.capabilities[capability]) {
    return null;
  }
  return business.capabilities[capability] || null;
}

function resolveDesignReadiness(args, squadConfig, integrationMode) {
  if (!args.business && !args.app) {
    throw new Error('Design readiness requires --business=<slug> or --app=<id>');
  }

  if (!designResolver) {
    return {
      owner: 'workspace-chief',
      squad_slug: 'design',
      context_type: 'design_system',
      integration_mode: integrationMode.level,
      integration_declared: integrationMode.declared,
      integration_config_path: integrationMode.config_path,
      status: 'not_applicable',
      reason: 'Design resolver not available (legacy design-system scripts removed).',
      business_slug: args.business || null,
      product_slug: null,
      app_id: args.app || null,
      design_system: null,
      required_loaded: [{ id: 'workspace_config', path: WORKSPACE_CONFIG_PATH, required: true }],
      missing_required: [],
      delegated_resolver: null,
    };
  }

  const workspaceConfig = designResolver.getWorkspaceConfig();
  const result = args.app
    ? designResolver.resolveByApp(workspaceConfig, args.app)
    : designResolver.buildBusinessResult(workspaceConfig, args.business);

  let status = 'ready';
  let reason = 'Design System configured and ready.';
  const missingRequired = [];

  if (result.status === 'not_configured') {
    status = 'blocked';
    reason = 'Business has no configured Design System.';
    missingRequired.push({
      id: 'design_system_config',
      path: result.config_path,
      required: true,
    });
  } else if (result.status === 'not_applicable') {
    status = 'not_applicable';
    reason = 'Design System is marked as not applicable for this business.';
  }

  const requiredLoaded = uniq([
    WORKSPACE_CONFIG_PATH,
    result.status === 'configured' ? result.config_path : null,
  ]).map((filePath) => ({
    id: filePath === WORKSPACE_CONFIG_PATH ? 'workspace_config' : 'design_system_config',
    path: filePath,
    required: true,
  }));

  const designSystem = result.design_system
    ? {
        id: result.design_system.id || null,
        name: result.design_system.name || null,
        default_theme: result.design_system.default_theme || null,
        source: result.design_system.source || null,
      }
    : null;

  return {
    owner: 'workspace-chief',
    squad_slug: 'design',
    context_type: 'design_system',
    integration_mode: integrationMode.level,
    integration_declared: integrationMode.declared,
    integration_config_path: integrationMode.config_path,
    status,
    reason,
    business_slug: result.business_slug || args.business || null,
    product_slug: null,
    app_id: args.app || (result.design_system && result.design_system.app ? result.design_system.app.id || null : null),
    delegated_resolver: 'squads/aiox-design/scripts/design-system/resolve_business_design_system.cjs',
    canonical_config_paths: uniq([
      WORKSPACE_CONFIG_PATH,
      result.config_path,
    ]),
    required_sources_loaded: requiredLoaded,
    missing_required_sources: missingRequired,
    allowed_write_paths: getAllowedWritePaths(squadConfig),
    readiness_payload: {
      business_slug: result.business_slug,
      design_system: designSystem,
      original_status: result.status,
      config_path: result.config_path,
    },
  };
}

function resolveProductConsumerReadiness(args, squadConfig, integrationMode) {
  if (!args.business || !args.product) {
    throw new Error('Product readiness requires --business=<slug> and --product=<slug>');
  }

  const consumer = args.squad;
  const readiness = resolveProductReadiness({
    business: args.business,
    product: args.product,
    consumer,
  });

  const requiredLoaded = readiness.requirements
    .filter((item) => item.required && item.exists)
    .map((item) => ({
      id: item.id,
      path: item.path,
      required: true,
      source: item.source || null,
    }));

  const missingRequired = readiness.missing_required.map((item) => ({
    id: item.id,
    path: item.path,
    required: true,
    source: item.source || null,
  }));

  const canonicalConfigPaths = uniq([
    WORKSPACE_CONFIG_PATH,
    readiness.company_offerbook_index,
    ...readiness.requirements.filter((item) => item.exists).map((item) => item.path),
  ]);

  return {
    owner: 'workspace-chief',
    squad_slug: consumer,
    context_type: 'product',
    integration_mode: integrationMode.level,
    integration_declared: integrationMode.declared,
    integration_config_path: integrationMode.config_path,
    status: readiness.status,
    reason: readiness.reasons.length > 0 ? readiness.reasons.join(' | ') : 'Product readiness resolved.',
    business_slug: readiness.business_slug,
    product_slug: readiness.product_slug,
    app_id: null,
    delegated_resolver: 'squads/aiox-workspace/scripts/resolve-product-readiness.cjs',
    canonical_config_paths: canonicalConfigPaths,
    required_sources_loaded: requiredLoaded,
    missing_required_sources: missingRequired,
    allowed_write_paths: getAllowedWritePaths(squadConfig),
    readiness_payload: readiness,
  };
}

function resolveMovementReadiness(args, squadConfig, integrationMode) {
  if (!args.business) {
    throw new Error('Movement readiness requires --business=<slug>');
  }

  const workspaceConfig = getWorkspaceConfig();
  const businessExists = Boolean(findBusiness(workspaceConfig, args.business));
  const capabilityStatus = getBusinessCapabilityStatus(workspaceConfig, args.business, 'movement');
  const requiredPaths = [
    {
      id: 'workspace_config',
      path: WORKSPACE_CONFIG_PATH,
      exists: true,
      required: true,
    },
    {
      id: 'business_registered',
      path: `workspace/config.yaml#businesses.${args.business}`,
      exists: businessExists,
      required: true,
    },
    {
      id: 'movement_templates',
      path: 'workspace/_templates/movement',
      exists: fs.existsSync(path.join(ROOT, 'workspace/_templates/movement')),
      required: true,
    },
    {
      id: 'business_movement_namespace',
      path: `workspace/businesses/${args.business}/movement`,
      exists: fs.existsSync(path.join(ROOT, `workspace/businesses/${args.business}/movement`)),
      required: true,
    },
  ];

  let status = 'ready';
  let reason = 'Movement namespace is configured and ready.';

  if (!businessExists) {
    status = 'blocked';
    reason = 'Business is not registered in workspace/config.yaml.';
  } else if (capabilityStatus === 'not_applicable') {
    status = 'not_applicable';
    reason = 'Movement capability is marked as not applicable for this business.';
  } else if (capabilityStatus !== 'configured') {
    status = 'blocked';
    reason = 'Movement capability is not configured in workspace/config.yaml.';
  }

  const missingRequired = requiredPaths
    .filter((item) => item.required && !item.exists)
    .map((item) => ({
      id: item.id,
      path: item.path,
      required: true,
    }));

  if (status === 'ready' && missingRequired.length > 0) {
    status = 'blocked';
    reason = 'Movement workspace namespace is missing required canonical sources.';
  }

  return {
    owner: 'workspace-chief',
    squad_slug: 'movement',
    context_type: 'movement',
    integration_mode: integrationMode.level,
    integration_declared: integrationMode.declared,
    integration_config_path: integrationMode.config_path,
    status,
    reason,
    business_slug: args.business,
    product_slug: null,
    app_id: null,
    delegated_resolver: null,
    canonical_config_paths: requiredPaths.filter((item) => item.exists).map((item) => item.path),
    required_sources_loaded: requiredPaths
      .filter((item) => item.required && item.exists)
      .map((item) => ({
        id: item.id,
        path: item.path,
        required: true,
      })),
    missing_required_sources: missingRequired,
    allowed_write_paths: getAllowedWritePaths(squadConfig),
    readiness_payload: {
      business_slug: args.business,
      business_registered: businessExists,
      capability_status: capabilityStatus,
      original_status: capabilityStatus || 'missing',
      namespace_path: `workspace/businesses/${args.business}/movement`,
    },
  };
}

function resolveBrandReadiness(args, squadConfig, integrationMode) {
  if (!args.business) {
    throw new Error('Brand readiness requires --business=<slug>');
  }

  const workspaceConfig = getWorkspaceConfig();
  const businessExists = Boolean(findBusiness(workspaceConfig, args.business));
  const namespacePath = `workspace/businesses/${args.business}/brand`;
  const templateRoot = 'workspace/_templates/brand';
  const requiredPaths = [
    {
      id: 'workspace_config',
      path: WORKSPACE_CONFIG_PATH,
      exists: true,
      required: true,
    },
    {
      id: 'business_registered',
      path: `workspace/config.yaml#businesses.${args.business}`,
      exists: businessExists,
      required: true,
    },
    {
      id: 'brand_templates',
      path: templateRoot,
      exists: fs.existsSync(path.join(ROOT, templateRoot)),
      required: true,
    },
    {
      id: 'company_profile',
      path: `workspace/businesses/${args.business}/company/company-profile.yaml`,
      exists: fs.existsSync(path.join(ROOT, `workspace/businesses/${args.business}/company/company-profile.yaml`)),
      required: true,
    },
    {
      id: 'company_icp',
      path: `workspace/businesses/${args.business}/company/icp.yaml`,
      exists: fs.existsSync(path.join(ROOT, `workspace/businesses/${args.business}/company/icp.yaml`)),
      required: true,
    },
    {
      id: 'brandbook',
      path: `workspace/businesses/${args.business}/brand/brandbook.yaml`,
      exists: fs.existsSync(path.join(ROOT, `workspace/businesses/${args.business}/brand/brandbook.yaml`)),
      required: true,
    },
    {
      id: 'operations_pricing_strategy',
      path: `workspace/businesses/${args.business}/operations/pricing-strategy.yaml`,
      exists: fs.existsSync(path.join(ROOT, `workspace/businesses/${args.business}/operations/pricing-strategy.yaml`)),
      required: true,
    },
    {
      id: 'operations_kpi_scorecards',
      path: `workspace/businesses/${args.business}/operations/kpi-scorecards.yaml`,
      exists: fs.existsSync(path.join(ROOT, `workspace/businesses/${args.business}/operations/kpi-scorecards.yaml`)),
      required: true,
    },
    {
      id: 'business_brand_namespace',
      path: namespacePath,
      exists: fs.existsSync(path.join(ROOT, namespacePath)),
      required: true,
    },
  ];

  let status = 'ready';
  let reason = 'Brand namespace is configured and ready.';

  const missingRequired = requiredPaths
    .filter((item) => item.required && !item.exists)
    .map((item) => ({
      id: item.id,
      path: item.path,
      required: true,
    }));

  if (!businessExists) {
    status = 'blocked';
    reason = 'Business is not registered in workspace/config.yaml.';
  } else if (!fs.existsSync(path.join(ROOT, namespacePath))) {
    status = 'blocked';
    reason = 'Brand namespace is not bootstrapped for this business.';
  } else if (missingRequired.length > 0) {
    status = 'blocked';
    reason = 'Brand workspace namespace is missing required canonical sources.';
  }

  return {
    owner: 'workspace-chief',
    squad_slug: 'brand',
    context_type: 'brand',
    integration_mode: integrationMode.level,
    integration_declared: integrationMode.declared,
    integration_config_path: integrationMode.config_path,
    status,
    reason,
    business_slug: args.business,
    product_slug: null,
    app_id: null,
    delegated_resolver: null,
    canonical_config_paths: requiredPaths.filter((item) => item.exists).map((item) => item.path),
    required_sources_loaded: requiredPaths
      .filter((item) => item.required && item.exists)
      .map((item) => ({
        id: item.id,
        path: item.path,
        required: true,
      })),
    missing_required_sources: missingRequired,
    allowed_write_paths: getAllowedWritePaths(squadConfig),
    readiness_payload: {
      business_slug: args.business,
      namespace_path: namespacePath,
      template_root: templateRoot,
      original_status: status,
    },
  };
}

function resolveFranchiseReadiness(args, squadConfig, integrationMode) {
  if (!args.business) {
    throw new Error('Franchise readiness requires --business=<slug>');
  }

  const workspaceConfig = getWorkspaceConfig();
  const businessExists = Boolean(findBusiness(workspaceConfig, args.business));
  const namespacePath = `workspace/businesses/${args.business}/franchise`;
  const templateRoot = 'workspace/_templates/franchise';
  const requiredPaths = [
    {
      id: 'workspace_config',
      path: WORKSPACE_CONFIG_PATH,
      exists: true,
      required: true,
    },
    {
      id: 'business_registered',
      path: `workspace/config.yaml#businesses.${args.business}`,
      exists: businessExists,
      required: true,
    },
    {
      id: 'franchise_templates',
      path: templateRoot,
      exists: fs.existsSync(path.join(ROOT, templateRoot)),
      required: true,
    },
    {
      id: 'business_franchise_namespace',
      path: namespacePath,
      exists: fs.existsSync(path.join(ROOT, namespacePath)),
      required: true,
    },
  ];

  let status = 'ready';
  let reason = 'Franchise namespace is configured and ready.';

  const missingRequired = requiredPaths
    .filter((item) => item.required && !item.exists)
    .map((item) => ({
      id: item.id,
      path: item.path,
      required: true,
    }));

  if (!businessExists) {
    status = 'blocked';
    reason = 'Business is not registered in workspace/config.yaml.';
  } else if (!fs.existsSync(path.join(ROOT, namespacePath))) {
    status = 'blocked';
    reason = 'Franchise namespace is not bootstrapped for this business.';
  } else if (missingRequired.length > 0) {
    status = 'blocked';
    reason = 'Franchise workspace namespace is missing required canonical sources.';
  }

  return {
    owner: 'workspace-chief',
    squad_slug: 'franchise',
    context_type: 'franchise',
    integration_mode: integrationMode.level,
    integration_declared: integrationMode.declared,
    integration_config_path: integrationMode.config_path,
    status,
    reason,
    business_slug: args.business,
    product_slug: null,
    app_id: null,
    delegated_resolver: null,
    canonical_config_paths: requiredPaths.filter((item) => item.exists).map((item) => item.path),
    required_sources_loaded: requiredPaths
      .filter((item) => item.required && item.exists)
      .map((item) => ({
        id: item.id,
        path: item.path,
        required: true,
      })),
    missing_required_sources: missingRequired,
    allowed_write_paths: getAllowedWritePaths(squadConfig),
    readiness_payload: {
      business_slug: args.business,
      namespace_path: namespacePath,
      template_root: templateRoot,
      original_status: status,
    },
  };
}

function resolveOperationsReadiness(args, squadConfig, integrationMode) {
  if (!args.business) {
    throw new Error('Operations readiness requires --business=<slug>');
  }

  const workspaceConfig = getWorkspaceConfig();
  const businessExists = Boolean(findBusiness(workspaceConfig, args.business));
  const namespacePath = `workspace/businesses/${args.business}/operations`;
  const templateRoot = 'workspace/_templates/operations';
  const requiredPaths = [
    {
      id: 'workspace_config',
      path: WORKSPACE_CONFIG_PATH,
      exists: true,
      required: true,
    },
    {
      id: 'business_registered',
      path: `workspace/config.yaml#businesses.${args.business}`,
      exists: businessExists,
      required: true,
    },
    {
      id: 'operations_templates',
      path: templateRoot,
      exists: fs.existsSync(path.join(ROOT, templateRoot)),
      required: true,
    },
    {
      id: 'business_operations_namespace',
      path: namespacePath,
      exists: fs.existsSync(path.join(ROOT, namespacePath)),
      required: true,
    },
    {
      id: 'operations_team_structure',
      path: `${namespacePath}/team-structure.yaml`,
      exists: fs.existsSync(path.join(ROOT, `${namespacePath}/team-structure.yaml`)),
      required: true,
    },
    {
      id: 'operations_pricing_strategy',
      path: `${namespacePath}/pricing-strategy.yaml`,
      exists: fs.existsSync(path.join(ROOT, `${namespacePath}/pricing-strategy.yaml`)),
      required: true,
    },
    {
      id: 'operations_kpi_scorecards',
      path: `${namespacePath}/kpi-scorecards.yaml`,
      exists: fs.existsSync(path.join(ROOT, `${namespacePath}/kpi-scorecards.yaml`)),
      required: true,
    },
  ];

  let status = 'ready';
  let reason = 'Operations namespace is configured and ready.';

  const missingRequired = requiredPaths
    .filter((item) => item.required && !item.exists)
    .map((item) => ({
      id: item.id,
      path: item.path,
      required: true,
    }));

  if (!businessExists) {
    status = 'blocked';
    reason = 'Business is not registered in workspace/config.yaml.';
  } else if (!fs.existsSync(path.join(ROOT, namespacePath))) {
    status = 'blocked';
    reason = 'Operations namespace is not bootstrapped for this business.';
  } else if (missingRequired.length > 0) {
    status = 'blocked';
    reason = 'Operations workspace namespace is missing required canonical sources.';
  }

  return {
    owner: 'workspace-chief',
    squad_slug: args.squad,
    context_type: 'operations',
    integration_mode: integrationMode.level,
    integration_declared: integrationMode.declared,
    integration_config_path: integrationMode.config_path,
    status,
    reason,
    business_slug: args.business,
    product_slug: null,
    app_id: null,
    delegated_resolver: null,
    canonical_config_paths: requiredPaths.filter((item) => item.exists).map((item) => item.path),
    required_sources_loaded: requiredPaths
      .filter((item) => item.required && item.exists)
      .map((item) => ({
        id: item.id,
        path: item.path,
        required: true,
      })),
    missing_required_sources: missingRequired,
    allowed_write_paths: getAllowedWritePaths(squadConfig),
    readiness_payload: {
      business_slug: args.business,
      namespace_path: namespacePath,
      template_root: templateRoot,
      original_status: status,
    },
  };
}

function resolveCustomerSuccessReadiness(args, squadConfig, integrationMode) {
  if (!args.business) {
    throw new Error('Customer Success readiness requires --business=<slug>');
  }

  const workspaceConfig = getWorkspaceConfig();
  const businessExists = Boolean(findBusiness(workspaceConfig, args.business));
  const namespacePath = `workspace/businesses/${args.business}/analytics/customer-success`;
  const templateRoot = 'workspace/_templates/customer-success';
  const requiredPaths = [
    {
      id: 'workspace_config',
      path: WORKSPACE_CONFIG_PATH,
      exists: true,
      required: true,
    },
    {
      id: 'business_registered',
      path: `workspace/config.yaml#businesses.${args.business}`,
      exists: businessExists,
      required: true,
    },
    {
      id: 'cs_templates',
      path: templateRoot,
      exists: fs.existsSync(path.join(ROOT, templateRoot)),
      required: true,
    },
    {
      id: 'cs_analytics_namespace',
      path: namespacePath,
      exists: fs.existsSync(path.join(ROOT, namespacePath)),
      required: true,
    },
    {
      id: 'cs_maturity',
      path: `${namespacePath}/cs-maturity.yaml`,
      exists: fs.existsSync(path.join(ROOT, `${namespacePath}/cs-maturity.yaml`)),
      required: false,
    },
    {
      id: 'company_profile',
      path: `workspace/businesses/${args.business}/company/company-profile.yaml`,
      exists: fs.existsSync(path.join(ROOT, `workspace/businesses/${args.business}/company/company-profile.yaml`)),
      required: true,
    },
    {
      id: 'company_icp',
      path: `workspace/businesses/${args.business}/company/icp.yaml`,
      exists: fs.existsSync(path.join(ROOT, `workspace/businesses/${args.business}/company/icp.yaml`)),
      required: false,
    },
  ];

  // Check for product-level health scores
  const productsDir = path.join(ROOT, `workspace/businesses/${args.business}/products`);
  if (fs.existsSync(productsDir)) {
    const products = fs.readdirSync(productsDir, { withFileTypes: true })
      .filter(d => d.isDirectory() && !d.name.startsWith('_') && !d.name.startsWith('.'))
      .map(d => d.name);
    for (const product of products) {
      const hsPath = `${namespacePath}/${product}/health-score.yaml`;
      requiredPaths.push({
        id: `health_score_${product}`,
        path: hsPath,
        exists: fs.existsSync(path.join(ROOT, hsPath)),
        required: false,
      });
    }
  }

  let status = 'ready';
  let reason = 'Customer Success namespace is configured and ready.';

  const missingRequired = requiredPaths
    .filter((item) => item.required && !item.exists)
    .map((item) => ({
      id: item.id,
      path: item.path,
      required: true,
    }));

  if (!businessExists) {
    status = 'blocked';
    reason = 'Business is not registered in workspace/config.yaml.';
  } else if (!fs.existsSync(path.join(ROOT, namespacePath))) {
    status = 'blocked';
    reason = 'Customer Success analytics namespace is not bootstrapped for this business.';
  } else if (missingRequired.length > 0) {
    status = 'blocked';
    reason = 'Customer Success workspace namespace is missing required canonical sources.';
  }

  return {
    owner: 'workspace-chief',
    squad_slug: 'customer-success',
    context_type: 'customer-success',
    integration_mode: integrationMode.level,
    integration_declared: integrationMode.declared,
    integration_config_path: integrationMode.config_path,
    status,
    reason,
    business_slug: args.business,
    product_slug: null,
    app_id: null,
    delegated_resolver: null,
    canonical_config_paths: requiredPaths.filter((item) => item.exists).map((item) => item.path),
    required_sources_loaded: requiredPaths
      .filter((item) => item.required && item.exists)
      .map((item) => ({
        id: item.id,
        path: item.path,
        required: true,
      })),
    missing_required_sources: missingRequired,
    allowed_write_paths: getAllowedWritePaths(squadConfig),
    readiness_payload: {
      business_slug: args.business,
      namespace_path: namespacePath,
      template_root: templateRoot,
      original_status: status,
      cs_maturity_exists: requiredPaths.find(p => p.id === 'cs_maturity')?.exists || false,
      health_scores: requiredPaths
        .filter(p => p.id.startsWith('health_score_'))
        .map(p => ({ product: p.id.replace('health_score_', ''), exists: p.exists, path: p.path })),
    },
  };
}

function resolveSquadWorkspaceReadiness(args) {
  const readinessConfig = args.squad ? getSquadReadinessConfig(args.squad) : null;
  const supportedSquads = getSupportedSquads();

  if (!args.squad || !readinessConfig) {
    throw new Error(`Unsupported squad "${args.squad}". Allowed: ${supportedSquads.join(', ')}`);
  }

  const contextType = args.contextType || readinessConfig.default_context;
  const allowedContexts = new Set(readinessConfig.allowed_contexts || []);
  if (!allowedContexts.has(contextType)) {
    throw new Error(`Unsupported context_type "${contextType}" for squad "${args.squad}"`);
  }

  const squadConfig = loadSquadConfig(args.squad);
  const integrationMode = getIntegrationMode(squadConfig, args.squad);

  if (args.squad === 'design') {
    return resolveDesignReadiness({ ...args, contextType }, squadConfig, integrationMode);
  }

  if (args.squad === 'movement') {
    return resolveMovementReadiness({ ...args, contextType }, squadConfig, integrationMode);
  }

  if (args.squad === 'brand') {
    return resolveBrandReadiness({ ...args, contextType }, squadConfig, integrationMode);
  }

  if (args.squad === 'franchise') {
    return resolveFranchiseReadiness({ ...args, contextType }, squadConfig, integrationMode);
  }

  if (args.squad === 'customer-success') {
    return resolveCustomerSuccessReadiness({ ...args, contextType }, squadConfig, integrationMode);
  }

  if (readinessConfig.resolver_kind === 'operations') {
    return resolveOperationsReadiness({ ...args, contextType }, squadConfig, integrationMode);
  }

  return resolveProductConsumerReadiness({ ...args, contextType }, squadConfig, integrationMode);
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

  try {
    const output = resolveSquadWorkspaceReadiness(args);
    printOutput(output, args.format);
  } catch (error) {
    fail(error.message);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  parseArgs,
  resolveSquadWorkspaceReadiness,
};
