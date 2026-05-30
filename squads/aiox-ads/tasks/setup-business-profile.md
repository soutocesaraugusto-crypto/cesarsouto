---
task_id: setup-business-profile
version: 2.0
category: ads_onboarding
squad: aiox-ads
agent: ad-midas
elicit: true
depends_on:
  - load-workspace-context
templates:
  - business-profile.yaml
  - product-card.yaml
  - icp-profile.yaml
---

# Setup Business Profile -- Conversational Onboarding

> **Type:** Conversational task (elicit: true)
> **Version:** 2.0.0
> **Agent:** @ad-midas (concierge)
> **Output:** 3 YAML files saved to `workspace/businesses/{slug}/ads/`

---

## Overview

This task guides the user through a structured conversation to populate the three foundational YAML files that every campaign needs. The conversation is split into 3 phases, each focused on a different data domain. Questions are presented one at a time, validated before proceeding.

**Prerequisite:** MCP setup is NOT required for this task. Business profile can be filled before any platform connection.

---

## Phase 0 -- Workspace Context Pre-fill (v2.0)

> Goal: Eliminate redundant questions by loading data from canonical workspace sources.

Before asking any questions, execute the `load-workspace-context` task:

1. **Run** `load-workspace-context` for the target business slug.
2. **Receive** the context object with `pre_filled` and `pending_elicitation` sections.
3. **Display** summary to user:

```yaml
elicit: true
prompt: |
  I found existing workspace data for your business.

  Pre-filled from workspace: {pre_filled_count}/40 fields ({coverage_pct}%)
  Remaining questions: {pending_count}

  {display pre-filled fields grouped by phase}

  Does this pre-filled data look correct?
  (yes / edit {field_name} / reset-all)
```

4. **On "yes":** Proceed to Phase 1 but SKIP all pre-filled questions.
5. **On "edit {field}":** Allow user to override specific pre-filled values.
6. **On "reset-all":** Discard pre-filled data and run full 40-question flow.

**Fallback:** If `load-workspace-context` returns zero pre-filled fields (no workspace found), proceed directly to Phase 1 with all 40 questions. No error, no interruption.

---

## Phase 1 -- Business Identity

> Goal: Populate `business-profile.yaml` (template: `squads/aiox-ads/templates/business-profile.yaml`)
>
> **Context-aware rule:** If Phase 0 pre-filled any fields in this phase, SKIP those questions. Only ask fields marked `pending_elicitation`. If ALL fields are pre-filled, show the summary and confirm, then proceed to Phase 2.

```yaml
elicit: true
prompt: |
  Let's start with your business DNA. I'll ask you a few questions to understand
  your company, brand, and market positioning.

  First — what is your company name?
```

### Questions (sequential, one at a time -- skip if pre-filled)

| # | Field | Question | Validation |
|---|-------|----------|------------|
| 1 | company.name | What is your company name? | Non-empty string |
| 2 | company.slug | (Auto-generate from name, confirm) "I'll use `{slug}` as your identifier. OK?" | Lowercase, no spaces, no special chars |
| 3 | company.segment | What is your market segment? (e.g., SaaS, E-commerce, Info Product, Local Service, Agency) | Non-empty string |
| 4 | company.site | What is your main website URL? | Valid URL format |
| 5 | identity.manifesto | Does your brand have a manifesto or purpose statement? (optional — type "skip" to skip) | String or "skip" |
| 6 | identity.mission | What is your company mission? | Non-empty string |
| 7 | identity.value_proposition | What is your core value proposition in 1-2 sentences? | Non-empty string, max 200 chars |
| 8 | identity.differentiator | What separates you from competitors? | Non-empty string |
| 9 | identity.tone_of_voice | How would you describe your brand voice? (e.g., "Professional and accessible", "Bold and provocative") | Non-empty string |
| 10 | identity.keywords | List 5-10 keywords that define your brand (comma-separated) | Min 5 items |
| 11 | market.direct_competitors | Name at least 1 direct competitor (name + site). Add more with comma separation. | Min 1 entry with name + site |
| 12 | market.positioning | How do you position yourself vs the market? (e.g., "Premium with humanized support") | Non-empty string |
| 13 | ad_history.has_advertised | Have you ever run paid ads? (yes/no) | Boolean |
| 14 | ad_history.platforms | (If has_advertised=true) Which platforms? (Meta, Google, TikTok, LinkedIn, etc.) | Array, min 1 if has_advertised |
| 15 | assets (batch) | Quick asset check — do you have: product photos? videos? testimonials? logo? (yes/no for each) | 4 boolean answers |

### Phase 1 Completion

```yaml
elicit: true
prompt: |
  Phase 1 complete. Here is your business profile summary:

  {display filled business-profile.yaml fields as readable summary}

  Does this look correct? (yes / edit {field_name})
```

**On confirmation:** Save to `workspace/businesses/{slug}/ads/business-profile.yaml`

---

## Phase 2 -- Product / Offer

> Goal: Populate `product-card.yaml` (template: `squads/aiox-ads/templates/product-card.yaml`)
>
> **Context-aware rule:** If Phase 0 pre-filled any fields in this phase, SKIP those questions. Only ask fields marked `pending_elicitation`. If ALL fields are pre-filled, show the summary and confirm, then proceed to Phase 3.

```yaml
elicit: true
prompt: |
  Now let's document the product or service you want to advertise.
  One product card per offer — we can add more later.

  What is the name of the product or service?
```

### Questions (sequential, one at a time -- skip if pre-filled)

| # | Field | Question | Validation |
|---|-------|----------|------------|
| 1 | product.name | What is the product/service name? | Non-empty string |
| 2 | product.slug | (Auto-generate from name, confirm) | Lowercase, no spaces |
| 3 | product.short_description | Describe it in 1-2 sentences (this will appear in ads) | Non-empty, max 200 chars |
| 4 | product.price | What is the price? (e.g., "R$497", "R$97/month") | Non-empty string |
| 5 | product.gross_margin | What is your gross margin? (e.g., "70%", "R$350") — this helps set target CPA | Non-empty string |
| 6 | product.sales_url | What is the sales/checkout page URL? | Valid URL format |
| 7 | benefits[0] | What is the #1 benefit of your product? (strongest — will appear in headlines) | Non-empty string |
| 8 | benefits[1] | Benefit #2? | Non-empty string |
| 9 | benefits[2] | Benefit #3? | Non-empty string |
| 10 | common_objections[0] | What is the most common objection from potential buyers? | Non-empty string |
| 11 | common_objections[1] | Objection #2? | Non-empty string |
| 12 | common_objections[2] | Objection #3? | Non-empty string |
| 13 | social_proof | Do you have social proof? (ratings, total sales, testimonials count — type "skip" if none) | String or "skip" |

### Phase 2 Completion

```yaml
elicit: true
prompt: |
  Phase 2 complete. Product card summary:

  {display filled product-card.yaml fields as readable summary}

  Does this look correct? (yes / edit {field_name})
```

**On confirmation:** Save to `workspace/businesses/{slug}/ads/products/{product_slug}.yaml`

---

## Phase 3 -- ICP (Ideal Customer Profile)

> Goal: Populate `icp-profile.yaml` (template: `squads/aiox-ads/templates/icp-profile.yaml`)
>
> **Context-aware rule:** If Phase 0 pre-filled any fields in this phase, SKIP those questions. Only ask fields marked `pending_elicitation`. If ALL fields are pre-filled, show the summary and confirm, then proceed to Final Summary.

```yaml
elicit: true
prompt: |
  Final phase — let's define your ideal customer.
  This profile will drive all targeting and creative decisions.

  Give this ICP a descriptive name (e.g., "Beginner e-commerce owner"):
```

### Questions (sequential, one at a time -- skip if pre-filled)

| # | Field | Question | Validation |
|---|-------|----------|------------|
| 1 | name | Give this ICP a descriptive name | Non-empty string |
| 2 | slug | (Auto-generate from name, confirm) | Lowercase, no spaces |
| 3 | demographics.gender | Gender? (Male / Female / All) | One of 3 options |
| 4 | demographics.age_range | Age range? (e.g., "25-45") | Format: N-N |
| 5 | demographics.social_class | Social class? (e.g., "A-B", "B1-B2", "C1-C2") | Non-empty string |
| 6 | demographics.location | Location? (e.g., "Brazil - major cities", "SP + RJ", "National") | Non-empty string |
| 7 | psychographics.interests | List at least 3 interests relevant for targeting (comma-separated) | Min 3 items |
| 8 | psychographics.digital_behavior.platforms | Which platforms does this ICP spend time on? (Instagram, YouTube, LinkedIn, TikTok, etc.) | Min 1 platform |
| 9 | psychographics.digital_behavior.content_consumption | What type of content do they consume? (e.g., "Short videos, business podcasts, educational carousels") | Non-empty string |
| 10 | primary_pain | What is the #1 pain point your product solves for this person? | Non-empty string |
| 11 | desired_outcome | What does this person ultimately want to achieve? | Non-empty string |
| 12 | market_average_ticket | How much does this ICP typically spend on similar solutions? (e.g., "R$200-500/month") | Non-empty string |

### Phase 3 Completion

```yaml
elicit: true
prompt: |
  Phase 3 complete. ICP profile summary:

  {display filled icp-profile.yaml fields as readable summary}

  Does this look correct? (yes / edit {field_name})
```

**On confirmation:** Save to `workspace/businesses/{slug}/ads/icps/{icp_slug}.yaml`

---

## Final Summary

After all 3 phases are complete, display:

```yaml
elicit: true
prompt: |
  Onboarding complete! Here is what we created:

  1. Business Profile: workspace/businesses/{slug}/ads/business-profile.yaml
  2. Product Card:     workspace/businesses/{slug}/ads/products/{product_slug}.yaml
  3. ICP Profile:      workspace/businesses/{slug}/ads/icps/{icp_slug}.yaml

  Next steps:
  - Run *configure-mcp to connect your ad platforms
  - Run *run-research-protocol to generate a research brief for your first campaign

  Ready for the next step? (configure-mcp / research / done)
```

---

## Output

3 populated YAML files saved to `workspace/businesses/{slug}/ads/`:

| File | Path | Template |
|------|------|----------|
| Business Profile | `workspace/businesses/{slug}/ads/business-profile.yaml` | `squads/aiox-ads/templates/business-profile.yaml` |
| Product Card | `workspace/businesses/{slug}/ads/products/{product_slug}.yaml` | `squads/aiox-ads/templates/product-card.yaml` |
| ICP Profile | `workspace/businesses/{slug}/ads/icps/{icp_slug}.yaml` | `squads/aiox-ads/templates/icp-profile.yaml` |

---

## Validation Rules

| Rule | Enforcement |
|------|-------------|
| All required fields must be filled | BLOCK -- do not save until all required fields have values |
| Slug format validated | Must be lowercase, alphanumeric + hyphens only |
| URL format validated | Must start with http:// or https:// |
| Min items respected | keywords >= 5, direct_competitors >= 1, interests >= 3, benefits = 3, common_objections = 3 |
| Phase confirmation required | User must confirm summary before save |
| Directory auto-creation | Create `workspace/businesses/{slug}/ads/`, `products/`, `icps/` dirs if they don't exist |

---

_Task: setup-business-profile v2.0 | @ad-midas_
