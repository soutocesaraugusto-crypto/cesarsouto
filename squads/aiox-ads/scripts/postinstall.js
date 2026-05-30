#!/usr/bin/env node

/**
 * @aios/media-buyer-squad - Post-install Script
 *
 * Runs after npm install to display setup instructions.
 */

const { validateConfig, getStatistics } = require('../config');

console.log(`
╔══════════════════════════════════════════════════════════════════════════════╗
║                      @aios/media-buyer-squad                                  ║
║                   Multi-Agent Paid Traffic System                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║   ✅ Package installed successfully!                                         ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
`);

// Display statistics
const stats = getStatistics();
console.log(`
📊 Squad Statistics:
   • Agents: ${stats.agents}
   • Skills: ${stats.skills}
   • Frameworks: ${stats.frameworks}
   • Experts: ${stats.experts}
   • Skill Chains: ${stats.skillChains}
`);

// Validate configuration
const validation = validateConfig();
if (!validation.valid) {
  console.log(`
⚠️  Configuration Issues:
${validation.issues.map(i => `   • ${i}`).join('\n')}
`);
} else {
  console.log(`   ✅ Configuration validated successfully
`);
}

// Setup instructions
console.log(`
📋 Quick Setup:

1. Set environment variables:
   export EXA_API_KEY=your_exa_api_key

2. Optional (for @pixel-specialist):
   export META_ACCESS_TOKEN=your_token
   export META_PIXEL_ID=your_pixel_id

3. Configure MCP servers:

   const { generateMcpConfig } = require('@aios/media-buyer-squad/mcp');
   const config = generateMcpConfig();
   // Write to .mcp.json

4. Use the squad:

   const squad = require('@aios/media-buyer-squad');

   // Load an agent
   const midas = squad.agents['ad-midas'].load();

   // Route user intent
   const route = squad.routeIntent('meu CPA está alto');
   // { skill: 'metric-diagnosis', agent: '@performance-analyst', ... }

📚 Documentation: https://github.com/thiagofinch/aios-core/tree/main/packages/media-buyer-squad
`);

// Check for missing environment variables
const requiredEnvVars = ['EXA_API_KEY'];
const missingVars = requiredEnvVars.filter(v => !process.env[v]);

if (missingVars.length > 0) {
  console.log(`
⚠️  Missing environment variables:
${missingVars.map(v => `   • ${v}`).join('\n')}

   Some features may not work without these variables.
`);
}

console.log(`
───────────────────────────────────────────────────────────────────────────────
   Ready to deploy! Activate agents with @ad-midas, @performance-analyst,
   @creative-analyst, or @pixel-specialist.
───────────────────────────────────────────────────────────────────────────────
`);
