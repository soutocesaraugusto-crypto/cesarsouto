---
task_id: load-workspace-context
version: 1.0
category: ads_onboarding
squad: aiox-ads
agent: ad-midas
elicit: false
---

# Load Workspace Context -- Pre-fill Business Profile from Canonical Sources

> **Type:** Preflight task (elicit: false)
> **Version:** 1.0.0
> **Agent:** @ad-midas (concierge)
> **Output:** Context object with pre-filled fields + list of remaining questions

---

## Overview

This task reads canonical workspace YAMLs for a given business and maps their fields to the aiox-ads business profile, product card, and ICP profile structures. The goal is to eliminate redundant questions during `setup-business-profile` by reusing data the C-Level squad already elicited.

**Result:** Of the 40 onboarding questions, approximately 30 are answered from workspace data. Only the remaining 10 (ads-specific) questions need to be asked.

---

## Prerequisites

- A `{business_slug}` must be provided or selected
- The workspace directory `workspace/businesses/{slug}/` must exist
- No MCP or platform connection required

---

## Workflow

### Phase 1: Resolve Business Slug

If `{slug}` is not provided, check `workspace/businesses/` for available businesses.
If only one business exists, auto-select it.
If multiple exist, present a numbered list and let the user choose.

### Phase 2: Resolve Product Selection

Before reading product-level sources, resolve which product to load:

1. List all directories under `workspace/businesses/{slug}/products/`
2. If **zero products** exist: skip all product-level sources, mark product fields as `pending_elicitation`
3. If **one product** exists: auto-select it
4. If **multiple products** exist: present a numbered list and let the user choose

```yaml
elicit: true  # only when multiple products
prompt: |
  I found {count} products in your workspace:

  {numbered list of product slugs}

  Which product do you want to advertise? (number or slug)
```

Store the selected product slug as `{product}` for all subsequent reads.

### Phase 3: Read Canonical Sources

Read the following files (all paths relative to `workspace/businesses/{slug}/`). Each file is optional -- if it does not exist, skip gracefully and mark those fields as `pending_elicitation`.

**Company-level sources:**

| Source File | Required | Fields Extracted |
|-------------|----------|------------------|
| `company/company-profile.yaml` | recommended | company.name, company.segment, identity.mission, demographics.location |
| `brand/brandbook.yaml` | recommended | identity.manifesto, identity.differentiator, identity.tone_of_voice, identity.keywords, market.positioning |
| `brand/domain-decision.yaml` | optional | company.site |
| `company/brand.yaml` | optional | identity.value_proposition (path: `promises.marketing_promise`) |
| `company/icp.yaml` | recommended | ICP: name, demographics (gender, age_range, social_class), psychographics.interests, primary_pain, desired_outcome |
| `operations/pricing-strategy.yaml` | optional | product.price, market_average_ticket |

**Product-level sources** (use `{product}` resolved in Phase 2):

| Source File | Required | Fields Extracted |
|-------------|----------|------------------|
| `products/{product}/offerbook.yaml` | recommended | product.name, product.short_description, benefits[0-2] |
| `products/{product}/proof.yaml` | optional | social_proof |
| `products/{product}/testimonials.yaml` | optional | social_proof (enrichment) |
| `products/{product}/narrative/objection-destroyers.yaml` | optional | common_objections[0-2] |

### Phase 4: Map Fields

Apply the following mapping from workspace sources to aiox-ads profile fields.

#### Business Profile (Phase 1 of setup-business-profile)

| # | aiox-ads Field | Source | Path in Source | Fallback |
|---|----------------|--------|----------------|----------|
| 1 | company.name | company-profile.yaml | company_essence.trade_name | pending_elicitation |
| 2 | company.slug | derived | kebab-case of business slug | pending_elicitation |
| 3 | company.segment | company-profile.yaml | company_essence (inferred from sector/vertical) | pending_elicitation |
| 4 | company.site | domain-decision.yaml | chosen_domain or primary_url | pending_elicitation |
| 5 | identity.manifesto | brandbook.yaml | core.purpose | pending_elicitation |
| 6 | identity.mission | company-profile.yaml | mission.statement | pending_elicitation |
| 7 | identity.value_proposition | company/brand.yaml | promises.marketing_promise | pending_elicitation |
| 8 | identity.differentiator | brandbook.yaml | positioning.value_claim | pending_elicitation |
| 9 | identity.tone_of_voice | brandbook.yaml | archetype_mix (formatted as descriptive string) | pending_elicitation |
| 10 | identity.keywords | brandbook.yaml | core.owned_word + positioning keywords | pending_elicitation |
| 11 | market.direct_competitors | -- | NOT available in workspace | pending_elicitation |
| 12 | market.positioning | brandbook.yaml | positioning | pending_elicitation |
| 13 | ad_history.has_advertised | -- | NOT available in workspace (ads-specific) | pending_elicitation |
| 14 | ad_history.platforms | -- | NOT available in workspace (ads-specific) | pending_elicitation |
| 15 | assets | testimonials.yaml | partial (testimonials exist = yes) | pending_elicitation |

#### Product Card (Phase 2 of setup-business-profile)

| # | aiox-ads Field | Source | Path in Source | Fallback |
|---|----------------|--------|----------------|----------|
| 1 | product.name | offerbook.yaml | posicionamento.oferta.name | pending_elicitation |
| 2 | product.slug | derived | kebab-case of product slug | pending_elicitation |
| 3 | product.short_description | offerbook.yaml | posicionamento.oferta.description | pending_elicitation |
| 4 | product.price | pricing-strategy.yaml | product price (if available) | pending_elicitation |
| 5 | product.gross_margin | -- | NOT available in workspace | pending_elicitation |
| 6 | product.sales_url | -- | NOT available in workspace | pending_elicitation |
| 7-9 | benefits[0-2] | offerbook.yaml | posicionamento.oferta.promise (top 3) | pending_elicitation |
| 10-12 | common_objections[0-2] | objection-destroyers.yaml | top 3 objections | pending_elicitation |
| 13 | social_proof | proof.yaml | summary metrics | pending_elicitation |

#### ICP Profile (Phase 3 of setup-business-profile)

| # | aiox-ads Field | Source | Path in Source | Fallback |
|---|----------------|--------|----------------|----------|
| 1 | name | icp.yaml | core_icp.icp_name | pending_elicitation |
| 2 | slug | derived | kebab-case of ICP name | pending_elicitation |
| 3 | demographics.gender | icp.yaml | demographics.gender | pending_elicitation |
| 4 | demographics.age_range | icp.yaml | demographics_age.primary_range | pending_elicitation |
| 5 | demographics.social_class | icp.yaml | demographics.social_class | pending_elicitation |
| 6 | demographics.location | company-profile.yaml | company_essence.headquarters | pending_elicitation |
| 7 | psychographics.interests | icp.yaml | psychographic.interests | pending_elicitation |
| 8 | psychographics.digital_behavior.platforms | icp.yaml | psychographic.digital_behavior (partial) | pending_elicitation |
| 9 | psychographics.digital_behavior.content_consumption | icp.yaml | psychographic.content_consumption (partial) | pending_elicitation |
| 10 | primary_pain | icp.yaml | pain_stack.primary | pending_elicitation |
| 11 | desired_outcome | icp.yaml | desired_state | pending_elicitation |
| 12 | market_average_ticket | pricing-strategy.yaml | market average (if available) | pending_elicitation |

### Phase 5: Build Context Object

Produce a structured result with two sections:

```yaml
workspace_context:
  generated_at: "YYYY-MM-DDTHH:mm:ssZ"
  business_slug: "{slug}"
  product_slug: "{product}"
  source_files_found: []    # list of files that were successfully read
  source_files_missing: []  # list of files that were not found

  pre_filled:
    business_profile:
      # fields with values extracted from workspace
    product_card:
      # fields with values extracted from workspace
    icp_profile:
      # fields with values extracted from workspace

  pending_elicitation:
    business_profile:
      # field names that still need to be asked
    product_card:
      # field names that still need to be asked
    icp_profile:
      # field names that still need to be asked

  summary:
    total_fields: 40
    pre_filled_count: 0   # actual count
    pending_count: 0      # actual count
    coverage_pct: "0%"    # pre_filled / total
```

### Phase 6: Report to User

Display a summary showing:
1. How many fields were pre-filled from workspace (with source file for each)
2. How many fields still need to be asked
3. Coverage percentage
4. Ask: "Proceed to setup-business-profile with pre-filled data? (yes/no)"

---

## Fallback Behavior

If the workspace directory does not exist for the given slug, or if zero canonical files are found:

1. Report: "No workspace data found for business `{slug}`. Running full onboarding (40 questions)."
2. Return an empty context object with all fields marked as `pending_elicitation`.
3. The `setup-business-profile` task proceeds normally with all 40 questions.

This ensures the onboarding experience is never broken, only enhanced when workspace data is available.

---

## Veto Conditions

- NEVER write to workspace files from this task (read-only)
- NEVER invent data that is not present in the source files
- NEVER skip a field mapping -- if the source path does not resolve, mark as `pending_elicitation`
- NEVER modify the canonical YAML files

---

## Validation

- [ ] Business slug resolved (auto or user-selected)
- [ ] Product slug resolved (auto or user-selected)
- [ ] All available canonical sources read without errors
- [ ] Field mapping applied correctly (no invented values)
- [ ] Context object produced with accurate counts
- [ ] Summary displayed to user before proceeding

---

_Task: load-workspace-context v1.0 | @ad-midas_
