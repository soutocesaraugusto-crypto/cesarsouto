---
task_id: configure-mcp
version: 1.0
category: ads_setup
squad: aiox-ads
agent: ad-midas
elicit: false
references:
  - mcp/setup-guide.md
  - mcp/mcp-config.json
  - config/safety-rules.yaml
  - scripts/bootstrap.sh
---

# Configure MCP — Platform Connection Validation

> **Type:** Automated task (elicit: false)
> **Version:** 1.0.0
> **Agent:** @ad-midas (concierge) or @dev (manual)
> **Output:** `platform-status.yaml` saved to `workspace/businesses/{slug}/ads/`

---

## Overview

This task validates that MCP servers are properly configured and connected to ad platforms. It checks environment variables, tests MCP connectivity, validates Meta account access, and verifies Pixel status if configured.

**Prerequisite:** `.env` must have the AIOX-ADS section populated. Refer to `squads/aiox-ads/mcp/setup-guide.md` for token acquisition instructions.

---

## Process

### Step 1 — Check .env for Required Tokens

Read `.env` and verify the presence of AIOX-ADS section tokens.

**Required checks:**

| Token | Required | Purpose |
|-------|----------|---------|
| `META_ADS_ACCESS_TOKEN` | FAIL if missing | Pipeboard MCP primary token |
| `META_ADS_ACCOUNT_ID` | WARN if missing | Target ad account ID |
| `META_ADS_PIXEL_ID` | WARN if missing | Conversion tracking pixel |
| `META_ADS_PAGE_ID` | WARN if missing | Facebook Page for ad delivery |
| `META_ADS_ACCESS_TOKEN_SECONDARY` | INFO if missing | Adspirer fallback token |
| `GOOGLE_ADS_DEVELOPER_TOKEN` | INFO if missing | Google Ads (optional platform) |
| `GOOGLE_ADS_CLIENT_ID` | INFO if missing | Google OAuth (optional) |
| `GOOGLE_ADS_CLIENT_SECRET` | INFO if missing | Google OAuth (optional) |
| `GOOGLE_ADS_REFRESH_TOKEN` | INFO if missing | Google OAuth (optional) |
| `GOOGLE_ADS_CUSTOMER_ID` | INFO if missing | Google Ads account (optional) |
| `LINKEDIN_ADS_ACCESS_TOKEN` | INFO if missing | LinkedIn (optional) |
| `TIKTOK_ADS_ACCESS_TOKEN` | INFO if missing | TikTok (optional) |

**Validation logic:**
- If `META_ADS_ACCESS_TOKEN` is missing: HALT with error, link to `mcp/setup-guide.md` Phase 2A
- If WARN-level vars are missing: log warning, continue
- If INFO-level vars are missing: log as not configured, continue

### Step 2 — Test MCP Connection (Health Check)

For each MCP server defined in `mcp/mcp-config.json`, attempt a lightweight read-only call.

**Pipeboard (meta-ads-mcp):**

```
Tool: get_ad_accounts
Expected: Returns array with at least 1 ad account object
Timeout: 30 seconds
```

- If returns accounts: status = OK, log account count
- If returns empty: status = WARN ("Token valid but no ad accounts found")
- If returns error 401: status = FAIL ("Token expired or invalid")
- If returns error 429: status = FAIL ("Rate limited -- wait 5 min and retry")
- If tool not available: status = FAIL ("MCP server not loaded -- restart Claude Code")

**Adspirer (ads-mcp):**

Only test if at least one non-Meta platform token is configured.

```
Tool: list_campaigns (for first configured platform)
Expected: Returns campaign list or empty array
Timeout: 30 seconds
```

- Same status mapping as Pipeboard

### Step 3 — Validate Meta Account Access

If Pipeboard health check passed (Step 2), validate the specific ad account.

```
Tool: get_account_info (using META_ADS_ACCOUNT_ID)
Expected: Returns account object with account_status field
```

**Validation:**

| Account Status | Result | Action |
|----------------|--------|--------|
| 1 (ACTIVE) | OK | Proceed |
| 2 (DISABLED) | FAIL | "Account disabled -- contact Meta support" |
| 3 (UNSETTLED) | WARN | "Payment method issue -- resolve before campaign launch" |
| 7 (PENDING_RISK_REVIEW) | WARN | "Account under review -- do not launch campaigns until resolved" |
| 9 (IN_GRACE_PERIOD) | WARN | "Payment grace period -- update payment method" |
| 101 (PENDING_CLOSURE) | FAIL | "Account pending closure -- contact Meta support" |

Also verify:
- `currency` is populated (needed for budget calculations)
- `timezone_name` is populated (needed for reporting alignment)
- `business` object exists (Business Manager connected)

### Step 4 — Validate Pixel Status

If `META_ADS_PIXEL_ID` is configured in `.env`:

```
Tool: get_ad_accounts (filter for pixel data) or direct pixel query
Check: Pixel is active and has received events in last 24h
```

**Validation:**

| Condition | Result | Action |
|-----------|--------|--------|
| Pixel found, events in last 24h | OK | Log event count |
| Pixel found, no recent events | WARN | "Pixel installed but no events in 24h -- verify site installation" |
| Pixel not found | FAIL | "Pixel ID not found in this ad account -- verify META_ADS_PIXEL_ID" |
| No pixel_id configured | SKIP | "No pixel configured -- tracking setup needed before campaign launch" |

---

## Output

Generate `platform-status.yaml` with per-platform results:

```yaml
# Platform Status Report — AIOX Ads MCP Validation
# Generated: {timestamp}
# Business: {slug}
# Agent: @ad-midas

version: "1.0.0"
generated_at: "{ISO timestamp}"
business_slug: "{slug}"

overall_status: "OK"  # OK = all critical checks pass, WARN = non-blocking issues, FAIL = blocking issues

env_check:
  meta_ads_access_token: "OK"       # OK / MISSING
  meta_ads_account_id: "OK"         # OK / MISSING
  meta_ads_pixel_id: "OK"           # OK / MISSING / NOT_CONFIGURED
  meta_ads_page_id: "MISSING"       # OK / MISSING
  meta_ads_access_token_secondary: "NOT_CONFIGURED"
  google_ads: "NOT_CONFIGURED"      # OK / PARTIAL / NOT_CONFIGURED
  linkedin_ads: "NOT_CONFIGURED"    # OK / NOT_CONFIGURED
  tiktok_ads: "NOT_CONFIGURED"      # OK / NOT_CONFIGURED

mcp_health:
  pipeboard:
    status: "OK"                    # OK / FAIL / NOT_LOADED
    ad_accounts_found: 3
    response_time_ms: 450
    error: null
  adspirer:
    status: "SKIP"                  # OK / FAIL / NOT_LOADED / SKIP
    platforms_tested: []
    error: null

meta_account:
  status: "OK"                      # OK / FAIL / WARN
  account_id: "{id}"
  account_status: "ACTIVE"
  currency: "BRL"
  timezone: "America/Sao_Paulo"
  business_manager: true
  warnings: []

pixel:
  status: "OK"                      # OK / WARN / FAIL / SKIP
  pixel_id: "{id}"
  events_last_24h: 1547
  last_event_time: "{timestamp}"
  warnings: []

platforms:
  meta:
    status: "OK"
    mcp: "pipeboard"
  google:
    status: "NOT_CONFIGURED"
    mcp: "adspirer"
  linkedin:
    status: "NOT_CONFIGURED"
    mcp: "adspirer"
  tiktok:
    status: "NOT_CONFIGURED"
    mcp: "adspirer"

blocking_issues: []
# Example: ["META_ADS_ACCESS_TOKEN missing", "Ad account DISABLED"]

warnings: []
# Example: ["META_ADS_PAGE_ID not configured", "Pixel has no events in 24h"]

next_steps: []
# Example: ["Run setup-guide Phase 2A to get Meta token", "Verify pixel installation on website"]
```

**Save to:** `workspace/businesses/{slug}/ads/platform-status.yaml`

---

## Error Handling

| Error | Action |
|-------|--------|
| .env file not found | HALT -- "Run bootstrap.sh first or create .env from .env.example" |
| MCP server not loaded | HALT -- "Restart Claude Code to load MCP servers. See mcp/setup-guide.md" |
| Token expired (401) | Log FAIL, link to setup-guide.md troubleshooting section |
| Rate limited (429) | Log FAIL, suggest waiting 5 minutes and retrying |
| Network timeout | Log FAIL, suggest checking internet connection |
| All checks fail | overall_status = FAIL, populate blocking_issues and next_steps |

---

## Re-run Behavior

This task is idempotent. Running it again overwrites the previous `platform-status.yaml` with fresh results. The previous file is NOT archived -- current status is what matters.

---

_Task: configure-mcp v1.0 | @ad-midas_
