/**
 * @aios/media-buyer-squad - Configuration Loader
 *
 * Provides easy access to squad configuration files.
 */

const fs = require('fs');
const path = require('path');
const yaml = require('yaml');

const CONFIG_DIR = __dirname;

/**
 * Load a YAML configuration file
 */
function loadConfig(filename) {
  const fullPath = path.join(CONFIG_DIR, filename);
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Configuration file not found: ${filename}`);
  }
  const content = fs.readFileSync(fullPath, 'utf-8');
  return yaml.parse(content);
}

/**
 * Squad configuration
 */
const squad = loadConfig('squad.yaml');

/**
 * Skills registry
 */
const registry = loadConfig('registry.yaml');

/**
 * Skill router
 */
const router = loadConfig('router.yaml');

/**
 * Get all agent configurations
 */
function getAgents() {
  return squad.squad.agents;
}

/**
 * Get agent by ID
 */
function getAgent(agentId) {
  return squad.squad.agents.find(a => a.id === agentId);
}

/**
 * Get all skills
 */
function getSkills() {
  return registry.skills;
}

/**
 * Get skill by ID
 */
function getSkill(skillId) {
  return registry.skills[skillId];
}

/**
 * Get skills by category
 */
function getSkillsByCategory(category) {
  return Object.entries(registry.skills)
    .filter(([_, skill]) => skill.category === category)
    .map(([id, skill]) => ({ id, ...skill }));
}

/**
 * Get skills by agent
 */
function getSkillsByAgent(agentId) {
  const agentSkills = registry.agent_skills[agentId];
  if (!agentSkills) return [];

  return agentSkills.primary_skills.map(skillId => ({
    id: skillId,
    ...registry.skills[skillId]
  }));
}

/**
 * Get expert sources
 */
function getExperts() {
  return registry.experts;
}

/**
 * Get handoff rules
 */
function getHandoffRules() {
  return squad.squad.collaboration.handoff_rules;
}

/**
 * Get skill chains
 */
function getSkillChains() {
  return router.skill_chains;
}

/**
 * Get semantic triggers for a category
 */
function getSemanticTriggers(category = null) {
  if (category) {
    return router.semantic_triggers[category] || [];
  }
  return router.semantic_triggers;
}

/**
 * Get metric triggers for an urgency level
 */
function getMetricTriggers(urgency = null) {
  if (urgency) {
    return router.metric_triggers[urgency] || [];
  }
  return router.metric_triggers;
}

/**
 * Get routing configuration
 */
function getRoutingConfig() {
  return router.routing_config;
}

/**
 * Get fallback rules
 */
function getFallbackRules() {
  return router.fallback_rules;
}

/**
 * Validate configuration integrity
 */
function validateConfig() {
  const issues = [];

  // Check all agents referenced in skills exist
  for (const [skillId, skill] of Object.entries(registry.skills)) {
    for (const agent of skill.agents.primary) {
      const agentExists = squad.squad.agents.some(a => `@${a.id}` === agent);
      if (!agentExists) {
        issues.push(`Skill ${skillId} references unknown agent: ${agent}`);
      }
    }
  }

  // Check all skills in chains exist
  for (const [chainId, chain] of Object.entries(router.skill_chains)) {
    for (const step of chain.steps) {
      if (!registry.skills[step.skill]) {
        issues.push(`Chain ${chainId} references unknown skill: ${step.skill}`);
      }
    }
  }

  // Check handoff rules reference valid agents
  for (const rule of squad.squad.collaboration.handoff_rules) {
    const fromExists = squad.squad.agents.some(a => `@${a.id}` === rule.from);
    const toExists = squad.squad.agents.some(a => `@${a.id}` === rule.to);

    if (!fromExists) {
      issues.push(`Handoff rule references unknown source agent: ${rule.from}`);
    }
    if (!toExists) {
      issues.push(`Handoff rule references unknown target agent: ${rule.to}`);
    }
  }

  return {
    valid: issues.length === 0,
    issues
  };
}

/**
 * Get squad statistics
 */
function getStatistics() {
  return {
    agents: squad.squad.agents.length,
    skills: Object.keys(registry.skills).length,
    frameworks: Object.values(registry.experts).reduce((sum, e) => sum + e.frameworks_count, 0),
    experts: Object.keys(registry.experts).length,
    skillChains: Object.keys(router.skill_chains).length,
    handoffRules: squad.squad.collaboration.handoff_rules.length,
    byCategory: registry.statistics?.by_category || {},
    byExpert: registry.statistics?.by_expert || {}
  };
}

module.exports = {
  // Raw configs
  squad,
  registry,
  router,

  // Agent functions
  getAgents,
  getAgent,

  // Skill functions
  getSkills,
  getSkill,
  getSkillsByCategory,
  getSkillsByAgent,

  // Expert functions
  getExperts,

  // Collaboration functions
  getHandoffRules,
  getSkillChains,

  // Router functions
  getSemanticTriggers,
  getMetricTriggers,
  getRoutingConfig,
  getFallbackRules,

  // Utility functions
  validateConfig,
  getStatistics,
  loadConfig
};
