# MCP Setup Guide -- aiox-ads Squad

> **Type:** Conversational task (elicit: true)
> **Version:** 1.0.0
> **Last updated:** 2026-03-17
> **Executor:** @ad-midas (concierge) or @dev (manual setup)

---

## Overview

This guide walks you through connecting the aiox-ads squad to your ad platforms via MCP servers. It is designed as a conversation, not a wall of text -- each phase asks you a question, waits for your answer, then proceeds.

There are two MCP servers:

| MCP | Package | Version | Platforms | Role |
|-----|---------|---------|-----------|------|
| **Pipeboard** | `@pipeboard/meta-ads-mcp` | `1.0.59` | Meta (Facebook/Instagram) | Primary for all Meta R/W operations |
| **Adspirer** | `@adspirer/ads-mcp` | `0.3.2` | Google, LinkedIn, TikTok, Meta (fallback) | Cross-platform + Meta fallback |

**Separation of responsibilities:**
- **Pipeboard** = Meta read/write operations (campaigns, ad sets, creatives, audiences, pixel, reporting)
- **Adspirer** = Everything else (Google, LinkedIn, TikTok) + Meta fallback when Pipeboard is unavailable

**Critical rule:** Never two MCPs writing to the same campaign/ad simultaneously.

---

## Phase 1 -- Platform Selection

```yaml
elicit: true
prompt: |
  Which ad platform(s) do you want to connect?

  1. Meta (Facebook/Instagram) -- requires Pipeboard MCP
  2. Google Ads -- requires Adspirer MCP
  3. LinkedIn Ads -- requires Adspirer MCP
  4. TikTok Ads -- requires Adspirer MCP
  5. Multiple platforms (I'll specify)

  Type the number(s) separated by commas (e.g., "1,2" for Meta + Google):
```

### Platform-to-MCP mapping

After the user selects, map to MCP requirements:

| User selects | MCPs needed | Tokens required |
|-------------|-------------|-----------------|
| Meta only | Pipeboard | `META_ADS_ACCESS_TOKEN` |
| Google only | Adspirer | Google Ads token set (5 vars) |
| LinkedIn only | Adspirer | `LINKEDIN_ADS_ACCESS_TOKEN` |
| TikTok only | Adspirer | `TIKTOK_ADS_ACCESS_TOKEN` |
| Meta + any other | Pipeboard + Adspirer | Meta token + platform tokens (separate Meta tokens for each MCP) |
| Multiple non-Meta | Adspirer | All relevant platform tokens |

**Important:** If both Pipeboard AND Adspirer are needed, the user MUST provide **two separate Meta access tokens** -- one for each MCP. This prevents exhausting the Meta API rate limit twice as fast (DevOps roundtable decision).

---

## Phase 2 -- Token Acquisition

```yaml
elicit: true
prompt: |
  Based on your selection, here are the tokens you need.
  I'll guide you through getting each one.

  Ready to start? (yes/no)
```

### 2A -- Meta (Pipeboard) Token

**Where to get it:** https://pipeboard.co/settings/tokens

**Steps:**
1. Go to [pipeboard.co](https://pipeboard.co) and log in (or create account)
2. Navigate to **Settings** > **API Tokens**
3. Click **Generate Token**
4. Select scope: **Full Access** (required for campaign management)
5. Copy the token -- it will not be shown again

**Token type:** Long-lived access token (Pipeboard manages refresh internally)

```yaml
elicit: true
prompt: |
  Paste your Pipeboard (Meta) access token below.
  It should start with "EAA" and be ~200 characters long.

  Token:
```

**Where it goes:** Add to `.env` as `META_ADS_ACCESS_TOKEN=<your-token>`

---

### 2B -- Meta (Adspirer fallback) Token

> Only needed if you selected Meta + another platform, or want Meta fallback capability.

**Where to get it:** https://developers.facebook.com/tools/explorer/

**Steps:**
1. Go to [Meta Graph API Explorer](https://developers.facebook.com/tools/explorer/)
2. Select your app from the dropdown
3. Click **Generate Access Token**
4. Required permissions: `ads_management`, `ads_read`, `business_management`
5. Click **Generate Long-Lived Token** (short-lived tokens expire in ~1 hour)
6. Copy the token

**CRITICAL:** This MUST be a different token than the one used for Pipeboard. Using the same token for both MCPs will cause both to count against the same rate limit, effectively halving your API quota.

```yaml
elicit: true
prompt: |
  Paste your Meta fallback token for Adspirer (must be DIFFERENT from Pipeboard token).

  Token:
```

**Where it goes:** Add to `.env` as `META_ADS_ACCESS_TOKEN_SECONDARY=<your-token>`

---

### 2C -- Google Ads Tokens

**Where to get them:**
- Developer Token: https://ads.google.com/aw/apicenter
- OAuth credentials: https://console.cloud.google.com/apis/credentials

**Steps:**

1. **Developer Token**
   - Log in to [Google Ads](https://ads.google.com)
   - Go to **Tools & Settings** > **API Center**
   - Copy your **Developer Token** (apply for one if you don't have it -- Basic access is sufficient for read operations)

2. **OAuth2 Client Credentials**
   - Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   - Create project (or select existing)
   - Enable the **Google Ads API**
   - Create **OAuth 2.0 Client ID** (type: Web application)
   - Copy **Client ID** and **Client Secret**

3. **Refresh Token**
   - Use the [Google OAuth2 Playground](https://developers.google.com/oauthplayground/)
   - Configure with your Client ID and Client Secret
   - Authorize the `https://www.googleapis.com/auth/adwords` scope
   - Exchange authorization code for refresh token
   - Copy the **Refresh Token**

4. **Customer ID**
   - In Google Ads, look at the top-right corner
   - Your account ID is in format `123-456-7890`
   - Copy it (with or without dashes)

```yaml
elicit: true
prompt: |
  I need 5 values for Google Ads. Paste them one at a time:

  1. Developer Token:
  2. Client ID:
  3. Client Secret:
  4. Refresh Token:
  5. Customer ID (format: 123-456-7890):
```

**Where they go in `.env`:**
```
GOOGLE_ADS_DEVELOPER_TOKEN=<your-token>
GOOGLE_ADS_CLIENT_ID=<your-client-id>
GOOGLE_ADS_CLIENT_SECRET=<your-secret>
GOOGLE_ADS_REFRESH_TOKEN=<your-refresh-token>
GOOGLE_ADS_CUSTOMER_ID=<your-customer-id>
```

---

### 2D -- LinkedIn Ads Token

**Where to get it:** https://www.linkedin.com/developers/apps

**Steps:**
1. Go to [LinkedIn Developer Portal](https://www.linkedin.com/developers/apps)
2. Create app (or select existing)
3. Go to **Auth** tab
4. Under **OAuth 2.0 settings**, add redirect URL
5. Request the `r_ads`, `r_ads_reporting`, `rw_ads` scopes
6. Use the OAuth flow to get an access token
7. Copy the token

```yaml
elicit: true
prompt: |
  Paste your LinkedIn Marketing API access token:

  Token:
```

**Where it goes:** Add to `.env` as `LINKEDIN_ADS_ACCESS_TOKEN=<your-token>`

---

### 2E -- TikTok Ads Token

**Where to get it:** https://ads.tiktok.com/marketing_api/developer

**Steps:**
1. Go to [TikTok Marketing API Developer Portal](https://ads.tiktok.com/marketing_api/developer)
2. Create app (or select existing)
3. Generate a **Long-term Access Token** (valid 1 year)
4. Required scope: Campaign Management + Reporting
5. Copy the token

```yaml
elicit: true
prompt: |
  Paste your TikTok Marketing API access token:

  Token:
```

**Where it goes:** Add to `.env` as `TIKTOK_ADS_ACCESS_TOKEN=<your-token>`

---

## Phase 3 -- Connection Validation

```yaml
elicit: true
prompt: |
  Tokens saved. Now I'll validate each connection.

  This will make a lightweight read-only API call to each platform
  to confirm your tokens work.

  Ready to validate? (yes/no)
```

### Health Check Protocol

For each configured MCP, run a minimal read-only operation:

| MCP | Health Check Tool | What it does | Expected result |
|-----|-------------------|--------------|-----------------|
| Pipeboard | `get_ad_accounts` | Lists ad accounts | Returns array with at least 1 account |
| Adspirer (Google) | `list_campaigns` | Lists Google campaigns | Returns campaign list or empty array |
| Adspirer (LinkedIn) | `list_campaigns` | Lists LinkedIn campaigns | Returns campaign list or empty array |
| Adspirer (TikTok) | `list_campaigns` | Lists TikTok campaigns | Returns campaign list or empty array |

**Validation output format:**
```
Platform          Status    Details
-----------       -------   --------
Meta (Pipeboard)  OK        Found 3 ad accounts
Google Ads        OK        Found 12 campaigns
LinkedIn Ads      FAIL      Token expired (see Troubleshooting)
TikTok Ads        SKIP      Not configured
```

```yaml
elicit: true
prompt: |
  Validation complete. Results above.

  - OK: Platform is connected and working
  - FAIL: See Troubleshooting section below
  - SKIP: Platform not configured (no token provided)

  Want to retry any failed connections, or proceed? (retry/proceed)
```

---

## Troubleshooting

### Token expired

**Symptoms:** API returns 401 or "Invalid OAuth access token" error.

**Meta (Pipeboard):**
- Go to https://pipeboard.co/settings/tokens
- Revoke the old token
- Generate a new one
- Update `META_ADS_ACCESS_TOKEN` in `.env`
- Restart Claude Code to reload MCP

**Meta (Adspirer fallback):**
- Go to https://developers.facebook.com/tools/explorer/
- Generate new long-lived token
- Update `META_ADS_ACCESS_TOKEN_SECONDARY` in `.env`
- Restart Claude Code

**Google Ads:**
- The refresh token should auto-renew. If it fails:
- Go to https://developers.google.com/oauthplayground/
- Re-authorize and get a new refresh token
- Update `GOOGLE_ADS_REFRESH_TOKEN` in `.env`
- Restart Claude Code

**LinkedIn:**
- LinkedIn tokens expire in 60 days
- Re-run the OAuth flow at https://www.linkedin.com/developers/apps
- Update `LINKEDIN_ADS_ACCESS_TOKEN` in `.env`
- Restart Claude Code

**TikTok:**
- Long-term tokens are valid for 1 year
- If expired, regenerate at https://ads.tiktok.com/marketing_api/developer
- Update `TIKTOK_ADS_ACCESS_TOKEN` in `.env`
- Restart Claude Code

---

### Rate limit hit

**Symptoms:** API returns 429 or "User request limit reached" error.

**Immediate action:**
- Wait 5 minutes before retrying (most ad APIs reset per-minute quotas)
- Check if both MCPs are hitting the same platform with the same token (this is a config error -- see Separate Tokens below)

**Prevention:**
- Ensure Pipeboard and Adspirer use **separate tokens** for Meta
- Avoid running reports + writes simultaneously on the same account
- Space batch operations with reasonable intervals
- Use the `rate-limits.yaml` config to enforce per-platform request spacing

**If persistent:**
- Check your API tier/level in the platform's developer console
- Meta: Standard access allows ~200 calls/hour/token; Business verification unlocks higher limits
- Google: Basic access has 10,000 operations/day; Apply for Standard access for more

---

### MCP not connecting

**Symptoms:** Claude Code shows "MCP server failed to start" or tools are not available.

**Step 1 -- Verify installation:**
```bash
# Check if the MCP packages are accessible
npx @pipeboard/meta-ads-mcp@1.0.59 --version
npx @adspirer/ads-mcp@0.3.2 --version
```

**Step 2 -- Check settings file:**
- Open `.claude/settings.local.json` (NOT the example file)
- Verify it matches the structure in `.claude/settings.local.example.json`
- Verify tokens are actual values, not placeholder text

**Step 3 -- Check env vars:**
- Verify `.env` contains the required tokens
- Verify no trailing whitespace or newline in token values
- Verify token names match exactly (e.g., `META_ADS_ACCESS_TOKEN`, not `META_ACCESS_TOKEN`)

**Step 4 -- Restart:**
- Close Claude Code completely
- Reopen the project
- MCP servers reload on startup

**Step 5 -- Version mismatch:**
- If a new version was released and something broke, downgrade:
  - Edit `.claude/settings.local.json`
  - Change the version in the args array
  - The known-good versions are in `mcp/mcp-config.json`

---

### Wrong account / no permissions

**Symptoms:** Health check returns OK but shows unexpected accounts, or returns empty when you expect data.

**Meta:**
- Verify your token has access to the correct Business Manager
- Go to https://business.facebook.com/settings/people to check access
- The token inherits the permissions of the user who generated it

**Google:**
- Verify the `GOOGLE_ADS_CUSTOMER_ID` matches the account you want to manage
- If using a manager account (MCC), you may need to specify a sub-account ID

---

## Post-Setup Checklist

After all platforms show OK status:

- [ ] All required tokens added to `.env`
- [ ] `.claude/settings.local.json` configured with correct MCP entries
- [ ] Health check passed for all configured platforms
- [ ] Separate tokens confirmed for Pipeboard and Adspirer (if both configured)
- [ ] Claude Code restarted to load MCPs
- [ ] Test: can call at least one read-only tool per configured platform

---

## Quick Reference -- Token Locations

| Token | Where to get | Env var name | MCP |
|-------|-------------|--------------|-----|
| Meta (primary) | https://pipeboard.co/settings/tokens | `META_ADS_ACCESS_TOKEN` | Pipeboard |
| Meta (fallback) | https://developers.facebook.com/tools/explorer/ | `META_ADS_ACCESS_TOKEN_SECONDARY` | Adspirer |
| Google Developer | https://ads.google.com/aw/apicenter | `GOOGLE_ADS_DEVELOPER_TOKEN` | Adspirer |
| Google OAuth Client | https://console.cloud.google.com/apis/credentials | `GOOGLE_ADS_CLIENT_ID` + `GOOGLE_ADS_CLIENT_SECRET` | Adspirer |
| Google Refresh | OAuth flow (Playground) | `GOOGLE_ADS_REFRESH_TOKEN` | Adspirer |
| Google Customer ID | Google Ads UI (top-right) | `GOOGLE_ADS_CUSTOMER_ID` | Adspirer |
| LinkedIn | https://www.linkedin.com/developers/apps | `LINKEDIN_ADS_ACCESS_TOKEN` | Adspirer |
| TikTok | https://ads.tiktok.com/marketing_api/developer | `TIKTOK_ADS_ACCESS_TOKEN` | Adspirer |
