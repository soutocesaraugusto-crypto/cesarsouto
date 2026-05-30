/**
 * Campaign Monitor Loop
 *
 * Autonomous monitoring system for Meta Ads campaigns.
 * Applies 47 decision rules from 5 experts to detect issues,
 * take automated actions, and generate decision reports.
 *
 * Based on the autonomous-build-loop.js pattern from AIOS.
 *
 * @version 1.0.0
 * @domain media-buyer
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

// ============================================================================
// CONFIGURATION
// ============================================================================

const MonitorConfig = {
  // Timing
  checkIntervalMs: 15 * 60 * 1000, // 15 minutes
  cooldownMs: 30 * 60 * 1000, // 30 min between actions on same target
  maxDailyActions: 10, // Per campaign

  // Safety
  maxBudgetChangePercent: 20,
  requireApprovalAbovePercent: 50,

  // Rollback
  rollbackWindowHours: 24,
  autoRollbackConditions: {
    roasDropPercent: 50,
    cpaIncreasePercent: 100,
    timeWindowHours: 2,
  },

  // Active hours (Brazil timezone)
  activeHours: { start: 8, end: 22 },
  timezone: 'America/Sao_Paulo',

  // Logging
  logPath: '.aios-core/logs/campaign-decisions/',
  retentionDays: 90,
};

// ============================================================================
// EVENT TYPES
// ============================================================================

const MonitorEvent = {
  MONITOR_STARTED: 'monitor_started',
  MONITOR_STOPPED: 'monitor_stopped',
  CHECK_STARTED: 'check_started',
  CHECK_COMPLETED: 'check_completed',
  TRIGGER_DETECTED: 'trigger_detected',
  DECISION_MADE: 'decision_made',
  ACTION_EXECUTED: 'action_executed',
  ACTION_FAILED: 'action_failed',
  HUMAN_REQUIRED: 'human_required',
  SKILL_DISPATCHED: 'skill_dispatched',
  AGENT_NOTIFIED: 'agent_notified',
  ROLLBACK_TRIGGERED: 'rollback_triggered',
  COOLDOWN_ACTIVE: 'cooldown_active',
};

// ============================================================================
// STATE MANAGEMENT
// ============================================================================

class MonitorState {
  constructor(stateFilePath) {
    this.stateFilePath = stateFilePath;
    this.state = this.loadState();
  }

  loadState() {
    try {
      if (fs.existsSync(this.stateFilePath)) {
        return JSON.parse(fs.readFileSync(this.stateFilePath, 'utf8'));
      }
    } catch (error) {
      console.error('Error loading state:', error);
    }

    return {
      isRunning: false,
      startedAt: null,
      lastCheck: null,
      checksCompleted: 0,
      decisionsToday: [],
      actionsToday: [],
      cooldowns: {},
      pendingApprovals: [],
      rollbackRegistry: [],
    };
  }

  save() {
    const dir = path.dirname(this.stateFilePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(this.stateFilePath, JSON.stringify(this.state, null, 2));
  }

  isOnCooldown(targetId) {
    const cooldownEnd = this.state.cooldowns[targetId];
    if (!cooldownEnd) return false;
    return Date.now() < cooldownEnd;
  }

  setCooldown(targetId) {
    this.state.cooldowns[targetId] = Date.now() + MonitorConfig.cooldownMs;
    this.save();
  }

  clearExpiredCooldowns() {
    const now = Date.now();
    for (const [targetId, endTime] of Object.entries(this.state.cooldowns)) {
      if (endTime < now) {
        delete this.state.cooldowns[targetId];
      }
    }
    this.save();
  }

  registerAction(action) {
    this.state.actionsToday.push({
      ...action,
      timestamp: new Date().toISOString(),
    });
    this.save();
  }

  registerRollbackPoint(action, previousState) {
    this.state.rollbackRegistry.push({
      actionId: action.id,
      previousState,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(
        Date.now() + MonitorConfig.rollbackWindowHours * 60 * 60 * 1000
      ).toISOString(),
    });
    this.save();
  }

  getActionsForCampaign(campaignId) {
    const today = new Date().toDateString();
    return this.state.actionsToday.filter(
      (a) => a.campaignId === campaignId && new Date(a.timestamp).toDateString() === today
    );
  }

  canTakeAction(campaignId) {
    return this.getActionsForCampaign(campaignId).length < MonitorConfig.maxDailyActions;
  }
}

// ============================================================================
// DECISION LOGGER
// ============================================================================

class DecisionLogger {
  constructor(logPath) {
    this.logPath = logPath;
    this.ensureLogDirectory();
  }

  ensureLogDirectory() {
    if (!fs.existsSync(this.logPath)) {
      fs.mkdirSync(this.logPath, { recursive: true });
    }
  }

  generateId() {
    return `DEC-${Date.now()}`;
  }

  log(decision) {
    const logEntry = {
      id: this.generateId(),
      timestamp: new Date().toISOString(),
      ...decision,
    };

    // Daily log file
    const dateStr = new Date().toISOString().split('T')[0];
    const logFile = path.join(this.logPath, `decisions-${dateStr}.json`);

    let logs = [];
    if (fs.existsSync(logFile)) {
      try {
        logs = JSON.parse(fs.readFileSync(logFile, 'utf8'));
      } catch (e) {
        logs = [];
      }
    }

    logs.push(logEntry);
    fs.writeFileSync(logFile, JSON.stringify(logs, null, 2));

    return logEntry;
  }

  getDecisionsForPeriod(startDate, endDate) {
    const decisions = [];
    const start = new Date(startDate);
    const end = new Date(endDate);

    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const dateStr = d.toISOString().split('T')[0];
      const logFile = path.join(this.logPath, `decisions-${dateStr}.json`);

      if (fs.existsSync(logFile)) {
        try {
          const dayLogs = JSON.parse(fs.readFileSync(logFile, 'utf8'));
          decisions.push(...dayLogs);
        } catch (e) {
          console.error(`Error reading log file ${logFile}:`, e);
        }
      }
    }

    return decisions;
  }
}

// ============================================================================
// RULE ENGINE
// ============================================================================

class RuleEngine {
  constructor(rulesPath) {
    this.rules = this.loadRules(rulesPath);
  }

  loadRules(rulesPath) {
    try {
      const content = fs.readFileSync(rulesPath, 'utf8');
      return yaml.load(content);
    } catch (error) {
      console.error('Error loading rules:', error);
      return { kill_rules: [], scale_rules: [], creative_rules: [], alert_rules: [] };
    }
  }

  evaluateMetric(metric, operator, value, actualValue, context = {}) {
    // Handle dynamic value references
    let threshold = value;
    if (typeof value === 'string') {
      if (value.includes('target')) {
        threshold = eval(value.replace('target', context.target || 0));
      } else if (value.includes('baseline')) {
        threshold = eval(value.replace('baseline', context.baseline || 0));
      } else if (value.includes('benchmark')) {
        threshold = eval(value.replace('benchmark', context.benchmark || 0));
      }
    }

    switch (operator) {
      case '>':
        return actualValue > threshold;
      case '<':
        return actualValue < threshold;
      case '>=':
        return actualValue >= threshold;
      case '<=':
        return actualValue <= threshold;
      case '==':
        return actualValue === threshold;
      case '!=':
        return actualValue !== threshold;
      case 'dropped':
        // Check if metric dropped by X% over window
        return (
          context.previousValue &&
          ((context.previousValue - actualValue) / context.previousValue) * 100 >= threshold
        );
      default:
        return false;
    }
  }

  checkMinimumData(rule, metrics) {
    const minData = rule.trigger.min_data;
    if (!minData) return true;

    if (minData.includes('impressions')) {
      const required = parseInt(minData);
      return metrics.impressions >= required;
    }

    return true;
  }

  evaluateRule(rule, metrics, context = {}) {
    // Check minimum data requirement
    if (!this.checkMinimumData(rule, metrics)) {
      return { matches: false, reason: 'insufficient_data' };
    }

    const trigger = rule.trigger;
    const actualValue = metrics[trigger.metric];

    if (actualValue === undefined) {
      return { matches: false, reason: 'metric_not_available' };
    }

    // Evaluate primary condition
    const primaryMatch = this.evaluateMetric(
      trigger.metric,
      trigger.operator,
      trigger.value,
      actualValue,
      context
    );

    if (!primaryMatch) {
      return { matches: false, reason: 'primary_condition_failed' };
    }

    // Evaluate secondary condition if exists
    if (trigger.secondary) {
      const secondaryValue = metrics[trigger.secondary.metric];
      const secondaryMatch = this.evaluateMetric(
        trigger.secondary.metric,
        trigger.secondary.operator,
        trigger.secondary.value,
        secondaryValue,
        context
      );

      if (!secondaryMatch) {
        return { matches: false, reason: 'secondary_condition_failed' };
      }
    }

    return {
      matches: true,
      rule: rule,
      actualValue,
      threshold: trigger.value,
    };
  }

  findMatchingRules(metrics, context = {}) {
    const matches = [];
    const allRules = [
      ...(this.rules.kill_rules || []),
      ...(this.rules.scale_rules || []),
      ...(this.rules.creative_rules || []),
      ...(this.rules.audience_rules || []),
      ...(this.rules.budget_rules || []),
      ...(this.rules.tracking_rules || []),
      ...(this.rules.funnel_rules || []),
      ...(this.rules.economics_rules || []),
      ...(this.rules.platform_rules || []),
      ...(this.rules.alert_rules || []),
      ...(this.rules.scheduling_rules || []),
    ];

    for (const rule of allRules) {
      const result = this.evaluateRule(rule, metrics, context);
      if (result.matches) {
        matches.push(result);
      }
    }

    // Sort by urgency and confidence
    const urgencyOrder = { critical: 0, high: 1, medium: 2, low: 3 };
    matches.sort((a, b) => {
      const urgencyDiff = urgencyOrder[a.rule.urgency] - urgencyOrder[b.rule.urgency];
      if (urgencyDiff !== 0) return urgencyDiff;
      return b.rule.confidence - a.rule.confidence;
    });

    return matches;
  }
}

// ============================================================================
// ACTION EXECUTOR
// ============================================================================

class ActionExecutor {
  constructor(state, logger) {
    this.state = state;
    this.logger = logger;
  }

  async execute(decision) {
    const action = decision.rule.action;

    // Check if requires approval
    if (action.requires_approval) {
      return this.queueForApproval(decision);
    }

    // Check cooldown
    if (this.state.isOnCooldown(decision.target)) {
      return {
        status: 'cooldown_active',
        message: `Target ${decision.target} is on cooldown`,
      };
    }

    // Check daily action limit
    if (!this.state.canTakeAction(decision.campaignId)) {
      return {
        status: 'limit_reached',
        message: `Daily action limit reached for campaign ${decision.campaignId}`,
      };
    }

    try {
      // Log the decision before execution
      const logEntry = this.logger.log({
        trigger: {
          type: 'metric',
          rule_id: decision.rule.id,
          rule_name: decision.rule.name,
          metric: decision.rule.trigger.metric,
          current_value: decision.actualValue,
          threshold: decision.threshold,
        },
        decision: {
          type: action.type,
          target: decision.target,
          confidence: decision.rule.confidence,
          reasoning: decision.rule.explanation,
        },
        expert_source: {
          name: decision.rule.expert,
          framework: decision.rule.framework,
          weight: this.getExpertWeight(decision.rule.expert),
        },
        execution: {
          status: 'pending',
        },
        agents_notified: [],
      });

      // Store rollback point
      this.state.registerRollbackPoint(logEntry, decision.previousState);

      // Execute the action (in real implementation, this calls Meta Ads API)
      const result = await this.executeAction(action, decision);

      // Update log with result
      logEntry.execution.status = result.success ? 'executed' : 'failed';
      logEntry.execution.result = result.message;

      // Set cooldown
      this.state.setCooldown(decision.target);

      // Register action
      this.state.registerAction({
        ...logEntry,
        result,
      });

      return result;
    } catch (error) {
      return {
        status: 'failed',
        message: error.message,
        error,
      };
    }
  }

  async executeAction(action, decision) {
    // This is a placeholder for actual Meta Ads API calls
    // In production, this would use the Meta Marketing API

    console.log(`[ACTION] Executing ${action.type} on ${decision.target}`);

    switch (action.type) {
      case 'pause_ad':
      case 'pause_adset':
      case 'pause_campaign':
        return { success: true, message: `Paused ${decision.target}` };

      case 'scale_budget':
        return { success: true, message: `Scaled budget ${action.amount} on ${decision.target}` };

      case 'alert_and_pause':
        return { success: true, message: `Alerted and paused ${decision.target}` };

      case 'diagnose':
      case 'pause_and_diagnose':
        return {
          success: true,
          message: `Diagnosed ${decision.target}`,
          chain_skill: action.chain_skill,
        };

      default:
        return { success: true, message: `Executed ${action.type} on ${decision.target}` };
    }
  }

  queueForApproval(decision) {
    this.state.state.pendingApprovals.push({
      decision,
      queuedAt: new Date().toISOString(),
    });
    this.state.save();

    return {
      status: 'pending_approval',
      message: `Decision ${decision.rule.id} queued for human approval`,
    };
  }

  getExpertWeight(expertId) {
    const weights = {
      'jeremy-haynes': 0.95,
      'brian-moncada': 0.9,
      'alex-hormozi': 0.92,
      'brandon-carter': 0.88,
      'jordan-stupar': 0.85,
    };
    return weights[expertId] || 0.8;
  }
}

// ============================================================================
// AGENT DISPATCHER
// ============================================================================

class AgentDispatcher {
  constructor(logger) {
    this.logger = logger;
    this.dispatchRules = {
      '@media-strategist': {
        receives: ['strategic_decisions', 'escalations', 'campaign_health_summary'],
        isLead: true,
      },
      '@performance-analyst': {
        receives: ['metric_anomalies', 'diagnosis_requests'],
        triggers: ['cpa_variance > 30%', 'roas_drop > 25%'],
      },
      '@creative-analyst': {
        receives: ['creative_fatigue_alerts', 'hook_generation_requests'],
        triggers: ['ctr < benchmark * 0.7', 'hook_rate < 15%'],
      },
      '@pixel-specialist': {
        receives: ['tracking_issues', 'conversion_anomalies'],
        triggers: ['conversions == 0 AND clicks > 100', 'event_match_rate < 50%'],
      },
    };
  }

  dispatch(decision, agentId, message) {
    console.log(`[DISPATCH] Notifying ${agentId}: ${message}`);

    // Log the dispatch
    this.logger.log({
      type: 'agent_dispatch',
      agent: agentId,
      decision_id: decision.rule?.id,
      message,
      timestamp: new Date().toISOString(),
    });

    return {
      agent: agentId,
      dispatched: true,
      message,
    };
  }

  notifyLead(summary) {
    return this.dispatch(
      { rule: { id: 'summary' } },
      '@media-strategist',
      `Campaign Health Summary: ${summary}`
    );
  }

  escalate(decision, reason) {
    return this.dispatch(
      decision,
      '@media-strategist',
      `ESCALATION: ${reason} - Rule: ${decision.rule?.id}`
    );
  }

  dispatchSkill(skillId, context) {
    console.log(`[SKILL] Dispatching skill: ${skillId}`);

    return {
      skill: skillId,
      dispatched: true,
      context,
    };
  }
}

// ============================================================================
// CAMPAIGN MONITOR
// ============================================================================

class CampaignMonitor {
  constructor(options = {}) {
    this.options = {
      rulesPath: options.rulesPath || path.join(__dirname, '../rules/decision-rules.yaml'),
      statePath: options.statePath || '.aios-core/state/campaign-monitor.json',
      logPath: options.logPath || MonitorConfig.logPath,
    };

    this.state = new MonitorState(this.options.statePath);
    this.logger = new DecisionLogger(this.options.logPath);
    this.ruleEngine = new RuleEngine(this.options.rulesPath);
    this.executor = new ActionExecutor(this.state, this.logger);
    this.dispatcher = new AgentDispatcher(this.logger);

    this.intervalId = null;
  }

  isWithinActiveHours() {
    const now = new Date();
    const hour = now.getHours();
    return hour >= MonitorConfig.activeHours.start && hour < MonitorConfig.activeHours.end;
  }

  async fetchCampaignMetrics() {
    // Placeholder - in production, this fetches from Meta Ads API
    // Returns array of campaign/adset/ad metrics

    console.log('[FETCH] Fetching campaign metrics from Meta Ads API...');

    // Mock data for demonstration
    return [
      {
        id: 'campaign_123',
        type: 'campaign',
        name: 'Test Campaign',
        metrics: {
          roas: 2.1,
          cpa: 45,
          ctr: 1.2,
          cpm: 35,
          impressions: 5000,
          clicks: 60,
          conversions: 5,
          spend: 175,
          frequency: 1.8,
          hook_rate: 22,
        },
        context: {
          target: 30, // CPA target
          baseline: 30, // CPM baseline
          benchmark: 1.5, // CTR benchmark
        },
      },
    ];
  }

  async runCheck() {
    if (!this.isWithinActiveHours()) {
      console.log('[MONITOR] Outside active hours, skipping check');
      return;
    }

    console.log(`[CHECK] Starting check at ${new Date().toISOString()}`);
    this.state.clearExpiredCooldowns();

    try {
      // Fetch metrics from all campaigns
      const campaigns = await this.fetchCampaignMetrics();

      const results = {
        checked: 0,
        triggers: [],
        actions: [],
        escalations: [],
      };

      for (const campaign of campaigns) {
        results.checked++;

        // Find matching rules
        const matches = this.ruleEngine.findMatchingRules(campaign.metrics, campaign.context);

        for (const match of matches) {
          results.triggers.push({
            campaign: campaign.name,
            rule: match.rule.id,
            urgency: match.rule.urgency,
          });

          // Prepare decision object
          const decision = {
            ...match,
            target: campaign.id,
            campaignId: campaign.id,
            previousState: campaign.metrics,
          };

          // Execute or escalate
          if (match.rule.escalate) {
            this.dispatcher.escalate(decision, match.rule.explanation);
            results.escalations.push(decision);
          } else {
            const result = await this.executor.execute(decision);
            results.actions.push({
              decision,
              result,
            });

            // Chain skill if specified
            if (result.chain_skill) {
              this.dispatcher.dispatchSkill(result.chain_skill, { decision });
            }
          }
        }
      }

      // Update state
      this.state.state.lastCheck = new Date().toISOString();
      this.state.state.checksCompleted++;
      this.state.save();

      // Notify lead if there were significant events
      if (results.escalations.length > 0 || results.actions.length > 0) {
        this.dispatcher.notifyLead(
          `${results.triggers.length} triggers, ${results.actions.length} actions, ${results.escalations.length} escalations`
        );
      }

      console.log('[CHECK] Complete:', results);
      return results;
    } catch (error) {
      console.error('[CHECK] Error:', error);
      throw error;
    }
  }

  start() {
    if (this.state.state.isRunning) {
      console.log('[MONITOR] Already running');
      return;
    }

    console.log('[MONITOR] Starting campaign monitor...');
    console.log(`[CONFIG] Check interval: ${MonitorConfig.checkIntervalMs / 60000} min`);
    console.log(
      `[CONFIG] Active hours: ${MonitorConfig.activeHours.start}-${MonitorConfig.activeHours.end}`
    );
    console.log(`[CONFIG] Rules loaded: ${this.countRules()}`);

    this.state.state.isRunning = true;
    this.state.state.startedAt = new Date().toISOString();
    this.state.save();

    // Run initial check
    this.runCheck();

    // Set up interval
    this.intervalId = setInterval(() => {
      this.runCheck();
    }, MonitorConfig.checkIntervalMs);

    console.log('[MONITOR] Started successfully');
  }

  stop() {
    if (!this.state.state.isRunning) {
      console.log('[MONITOR] Not running');
      return;
    }

    console.log('[MONITOR] Stopping...');

    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }

    this.state.state.isRunning = false;
    this.state.save();

    console.log('[MONITOR] Stopped');
  }

  countRules() {
    const rules = this.ruleEngine.rules;
    return Object.values(rules)
      .filter(Array.isArray)
      .reduce((sum, arr) => sum + arr.length, 0);
  }

  getStatus() {
    return {
      isRunning: this.state.state.isRunning,
      startedAt: this.state.state.startedAt,
      lastCheck: this.state.state.lastCheck,
      checksCompleted: this.state.state.checksCompleted,
      actionsToday: this.state.state.actionsToday.length,
      pendingApprovals: this.state.state.pendingApprovals.length,
      rulesLoaded: this.countRules(),
    };
  }

  generateReport(startDate, endDate) {
    const decisions = this.logger.getDecisionsForPeriod(startDate, endDate);

    const summary = {
      period: { startDate, endDate },
      totalDecisions: decisions.length,
      executed: decisions.filter((d) => d.execution?.status === 'executed').length,
      pending: decisions.filter((d) => d.execution?.status === 'pending_approval').length,
      failed: decisions.filter((d) => d.execution?.status === 'failed').length,
      rolledBack: decisions.filter((d) => d.execution?.status === 'rolled_back').length,
      byExpert: {},
      byUrgency: { critical: 0, high: 0, medium: 0, low: 0 },
      topTriggers: [],
    };

    // Group by expert
    for (const decision of decisions) {
      const expert = decision.expert_source?.name || 'unknown';
      summary.byExpert[expert] = (summary.byExpert[expert] || 0) + 1;
    }

    // Count by urgency
    const ruleIdCounts = {};
    for (const decision of decisions) {
      const ruleId = decision.trigger?.rule_id;
      if (ruleId) {
        ruleIdCounts[ruleId] = (ruleIdCounts[ruleId] || 0) + 1;
      }
    }

    // Top triggers
    summary.topTriggers = Object.entries(ruleIdCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([ruleId, count]) => ({ ruleId, count }));

    return {
      summary,
      decisions,
    };
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  CampaignMonitor,
  MonitorConfig,
  MonitorEvent,
  MonitorState,
  DecisionLogger,
  RuleEngine,
  ActionExecutor,
  AgentDispatcher,
};

// ============================================================================
// CLI
// ============================================================================

if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];

  const monitor = new CampaignMonitor();

  switch (command) {
    case 'start':
      monitor.start();
      break;

    case 'stop':
      monitor.stop();
      break;

    case 'status':
      console.log(JSON.stringify(monitor.getStatus(), null, 2));
      break;

    case 'check':
      monitor.runCheck().then((result) => {
        console.log(JSON.stringify(result, null, 2));
        process.exit(0);
      });
      break;

    case 'report':
      const startDate =
        args[1] || new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
      const endDate = args[2] || new Date().toISOString().split('T')[0];
      const report = monitor.generateReport(startDate, endDate);
      console.log(JSON.stringify(report, null, 2));
      break;

    default:
      console.log(`
Campaign Monitor CLI

Usage:
  node campaign-monitor-loop.js <command>

Commands:
  start   - Start the monitoring loop
  stop    - Stop the monitoring loop
  status  - Show current status
  check   - Run a single check immediately
  report [start] [end] - Generate decision report
      `);
  }
}
