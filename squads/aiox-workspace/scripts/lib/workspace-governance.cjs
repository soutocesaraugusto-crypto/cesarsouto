#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const ROOT = path.resolve(__dirname, '..', '..', '..', '..');
const WORKSPACE_CONFIG_PATH = path.join(ROOT, 'squads', 'aiox-workspace', 'config.yaml');

let cachedGovernanceConfig = null;

function readYaml(filePath) {
  return yaml.load(fs.readFileSync(filePath, 'utf8')) || {};
}

function getWorkspaceGovernanceConfig() {
  if (!cachedGovernanceConfig) {
    const cLevelConfig = readYaml(WORKSPACE_CONFIG_PATH);
    cachedGovernanceConfig = cLevelConfig.workspace_governance || {};
  }

  return cachedGovernanceConfig;
}

function getReadinessRegistry() {
  return getWorkspaceGovernanceConfig().readiness || {};
}

function getSquadReadinessRegistry() {
  return getReadinessRegistry().squads || {};
}

function getSupportedSquads() {
  return Object.keys(getSquadReadinessRegistry());
}

function getSquadReadinessConfig(squad) {
  return getSquadReadinessRegistry()[squad] || null;
}

function getProductReadinessRegistry() {
  return getWorkspaceGovernanceConfig().product_readiness || {};
}

function getProductReadinessNarrativeArtifactsConfig() {
  return getProductReadinessRegistry().narrative_artifacts || {};
}

function getProductReadinessConsumersRegistry() {
  return getProductReadinessRegistry().consumers || {};
}

function getSupportedProductReadinessConsumers() {
  return Object.keys(getProductReadinessConsumersRegistry());
}

function getProductReadinessConsumerConfig(consumer) {
  return getProductReadinessConsumersRegistry()[consumer] || null;
}

module.exports = {
  getProductReadinessConsumerConfig,
  getProductReadinessNarrativeArtifactsConfig,
  getSupportedProductReadinessConsumers,
  getSupportedSquads,
  getSquadReadinessConfig,
  getWorkspaceGovernanceConfig,
};
