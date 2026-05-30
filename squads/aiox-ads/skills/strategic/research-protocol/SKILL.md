# Research Protocol Skill

**ID:** `research-protocol`
**Category:** strategic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Complete 5-phase research protocol executed BEFORE any campaign. Collects intelligence about the business, competitors, differentiators and benchmarks to inform all campaign decisions. This is the mandatory ENTRY POINT for the ads flow -- no campaign should start without a complete research-brief.

**Activation Command:** `*research {business_slug}`
**Announce:** "Activating Research Protocol -- 5 phases of intelligence before any campaign."
**Agent:** @ad-midas
**Tier:** Auto (read-only, no API writes)

---

## Expert Sources

| Expert         | Framework                 | Weight | Focus                          |
| -------------- | ------------------------- | ------ | ------------------------------ |
| Jeremy Haynes  | Client Research Protocol  | 0.93   | Pre-campaign intelligence      |
| Brian Moncada  | Competitive Analysis      | 0.90   | Ad Library reverse engineering |
| Alex Hormozi   | Market Research           | 0.88   | Differentiation and positioning|
| Russell Brunson| Funnel Hacking            | 0.85   | Competitor funnel analysis     |

---

## 5-Phase Protocol

### Phase 1 -- Load Strategic Context

```yaml
name: 'Load STRATEGY.md + business-profile.yaml'
type: 'context-loading'
tools: ['Read']

steps:
  - action: 'Load STRATEGY.md'
    path: 'workspace/businesses/{slug}/ads/STRATEGY.md'
    on_missing: 'Create skeleton from template squads/aiox-ads/templates/strategy.md'
    note: 'Initialize with default CONSTRAINTS from safety-rules.yaml'

  - action: 'Load business-profile.yaml'
    path: 'workspace/businesses/{slug}/ads/briefing/business-profile.yaml'
    on_missing: 'Create skeleton from template squads/aiox-ads/templates/business-profile.yaml'
    note: 'Mark status: incomplete, log warning, continue with available data'

  - action: 'Load product-card.yaml (if exists)'
    path: 'workspace/businesses/{slug}/ads/briefing/product-card.yaml'
    on_missing: 'Skip -- will be populated from Phase 2 crawl'

  - action: 'Load icp-profile.yaml (if exists)'
    path: 'workspace/businesses/{slug}/ads/briefing/icp-profile.yaml'
    on_missing: 'Skip -- will be inferred from Phase 2 crawl'

output:
  context_loaded:
    strategy_exists: true/false
    business_profile_exists: true/false
    product_card_exists: true/false
    icp_profile_exists: true/false
```

### Phase 2 -- Brand Website Crawl

```yaml
name: 'Crawl Brand Website'
type: 'web-intelligence'
tools: ['WebFetch']

steps:
  - action: 'Fetch homepage'
    url: '{business_profile.digital_presence.site_url}'
    extract:
      - 'Main value proposition (headline, subheadline)'
      - 'Products / services listed'
      - 'Pricing (if visible)'
      - 'Primary CTAs (buttons, forms)'
      - 'Trust signals (testimonials, logos, ratings, certifications)'
      - 'Tracking (Pixel, GTM, CAPI indicators)'

  - action: 'Fetch key pages (up to 5)'
    pages:
      - '/pricing or /planos'
      - '/about or /sobre'
      - '/products or /servicos'
      - '/contact or /contato'
      - '/checkout or /carrinho (if public)'
    extract_per_page:
      - 'Page purpose and CTA'
      - 'Unique content not on homepage'
      - 'Conversion friction points'

  - action: 'Identify gaps'
    checklist:
      - 'Missing testimonials or social proof?'
      - 'No visible pricing (opacity risk)?'
      - 'Weak or missing CTA?'
      - 'No urgency/scarcity elements?'
      - 'Missing Pixel/CAPI implementation signals?'
      - 'Slow load time indicators?'
      - 'No mobile optimization signals?'

output:
  populates: 'research-brief.md Section 1 (Brand Analysis)'
  fields:
    - site_url
    - products_found
    - main_cta
    - value_prop
    - trust_signals
    - gaps
```

### Phase 3 -- Competitive Research

```yaml
name: 'Research 3-5 Competitors'
type: 'competitive-intelligence'
tools: ['WebSearch', 'WebFetch']
minimum_competitors: 2
target_competitors: 3-5

steps:
  - action: 'Identify competitors'
    method: 'WebSearch'
    queries:
      - '{product_category} + {location/market}'
      - '{main_keyword} concorrentes'
      - '{business_name} alternativas'
      - 'Best {product_type} in {market}'
    selection_criteria:
      - 'Direct competitors (same product/price range)'
      - 'Aspirational competitors (larger, same niche)'
      - 'Indirect competitors (different product, same audience)'

  - action: 'Crawl each competitor site'
    tool: 'WebFetch'
    extract_per_competitor:
      - 'Name and URL'
      - 'Pricing model and price range'
      - 'Core messaging and positioning'
      - 'Unique selling propositions'
      - 'Trust signals and social proof'
      - 'Funnel structure (direct, lead magnet, webinar, etc.)'

  - action: 'Check Facebook Ad Library'
    tool: 'WebFetch'
    url: 'https://www.facebook.com/ads/library/?active_status=active&ad_type=all&country=BR&q={competitor_name}'
    extract_per_competitor:
      - 'Active ads count'
      - 'Ad formats used (video, image, carousel)'
      - 'Main hooks and angles'
      - 'Estimated time ads have been running'

  - action: 'Synthesize competitive insights'
    analysis:
      - 'Most common ad format across competitors'
      - 'Average ad lifespan patterns'
      - 'Dominant messaging patterns (pain/result/authority)'
      - 'Pricing positioning relative to business'

validation:
  min_competitors: 2
  on_below_minimum: 'Log warning but do NOT halt -- proceed with available data'

output:
  populates: 'research-brief.md Section 2 (Competitive Landscape)'
  fields:
    - competitors_table (name, pricing, messaging, ad_library_summary)
    - competitor_insights (common_format, avg_lifespan, dominant_platform, messaging_patterns)
```

### Phase 4 -- Differentiation Mapping

```yaml
name: 'Map Differentiation'
type: 'strategic-analysis'
tools: ['Read'] # Analyzes data from Phase 2 + Phase 3

steps:
  - action: 'Identify unique value'
    question: 'What does this business offer that competitors do NOT?'
    sources:
      - 'Phase 2 brand crawl (products, features, messaging)'
      - 'Phase 3 competitor data (gaps in their offering)'
    output_field: 'unique_to_this_business'

  - action: 'Identify underserved audiences'
    question: 'Which audience segments are competitors ignoring or serving poorly?'
    sources:
      - 'Phase 3 competitor targeting patterns'
      - 'ICP profile (if exists)'
      - 'Industry template audience data'
    output_field: 'underserved_audience'

  - action: 'Identify unexplored angles'
    question: 'What creative or messaging angles are absent from competitor ads?'
    sources:
      - 'Phase 3 Ad Library data (hooks, formats, angles)'
      - 'Phase 2 brand strengths not being communicated'
    output_field: 'unexplored_angles'

  - action: 'Rank opportunities'
    criteria:
      - 'Low competition + high demand = Priority 1'
      - 'Unique capability + market gap = Priority 2'
      - 'Competitor weakness + business strength = Priority 3'

output:
  populates: 'research-brief.md Section 3 (Differentiation Map)'
  fields:
    - unique_to_this_business
    - underserved_audience
    - unexplored_angles
```

### Phase 5 -- Ad Intelligence

```yaml
name: 'Pull Ad Intelligence'
type: 'performance-data'
tools: ['Read', 'MCP (conditional)']

paths:
  path_a:
    condition: 'business_profile.ad_history.has_advertised == true AND MCP available'
    name: 'Existing Advertiser Path'
    steps:
      - action: 'Pull campaign insights via MCP get_insights'
        data:
          - 'Total campaigns analyzed'
          - 'Best performing campaign (name, CPA, ROAS)'
          - 'Worst performing campaign (name, reason)'
          - 'Winning creatives (description of top performers)'
          - 'Failed creatives (description of what did not work)'
          - 'Key learnings from historical data'
        note: 'If MCP unavailable, fall back to Path B'

  path_b:
    condition: 'business_profile.ad_history.has_advertised == false OR MCP unavailable'
    name: 'New Advertiser Path'
    steps:
      - action: 'Load industry template'
        path: 'squads/aiox-ads/data/industry-templates/{industry}.yaml'
        fallback: 'squads/aiox-ads/data/industry-templates/generic.yaml'
      - action: 'Extract benchmark data'
        metrics:
          - 'CPA range'
          - 'ROAS range'
          - 'CTR range'
          - 'CPM range'
          - 'Conversion Rate range'
        source_attribution: 'Industry template ({industry}.yaml)'

output:
  populates: 'research-brief.md Section 4 (Ad Intelligence)'
  conditional:
    existing_advertiser: 'Campaigns Summary table'
    new_advertiser: 'Industry Benchmark table'
```

---

## Final Assembly

```yaml
name: 'Compile Research Brief'
type: 'output-generation'

steps:
  - action: 'Populate research-brief.md from template'
    template: 'squads/aiox-ads/templates/research-brief.md'
    fill_sections:
      - 'Section 1: Brand Analysis (Phase 2)'
      - 'Section 2: Competitive Landscape (Phase 3)'
      - 'Section 3: Differentiation Map (Phase 4)'
      - 'Section 4: Ad Intelligence (Phase 5)'
      - 'Section 5: Research Summary and Recommendations'

  - action: 'Generate Section 5 (Summary)'
    synthesize:
      top_3_opportunities:
        - 'From differentiation map + brand gaps'
        - 'From competitive weakness'
        - 'From underserved audience'
      top_3_risks:
        - 'From brand analysis gaps'
        - 'From competitive strength'
        - 'From tracking/compliance issues'
      recommended_first_campaign:
        objective: 'Based on business stage and goals'
        funnel: 'Based on product type and ticket'
        primary_angle: 'Based on differentiation map'
        budget_recommendation: 'Based on benchmarks and margin'

  - action: 'Update STRATEGY.md initial directives'
    condition: 'STRATEGY.md was created new in Phase 1'
    populate:
      prefer: 'Top performing formats/angles from research'
      avoid: 'Patterns that failed for competitors'
      constraint: 'Default safety constraints from safety-rules.yaml'

  - action: 'Save research-brief.md'
    path: 'workspace/businesses/{slug}/ads/research/research-brief-{campaign_slug}.md'
    note: 'If no campaign_slug yet, use research-brief-initial.md'

  - action: 'Mark status complete'
    field: 'status: complete'
    in_file: 'research-brief header'
```

---

## Output Format

```yaml
research_protocol:
  business: 'example-business'
  execution_date: '2026-03-18'
  agent: '@ad-midas'
  status: 'complete'

  phases_completed:
    phase_1_context: true
    phase_2_brand_crawl: true
    phase_3_competitive: true
    phase_4_differentiation: true
    phase_5_ad_intelligence: true

  artifacts_generated:
    research_brief: 'workspace/businesses/example-business/ads/research/research-brief-initial.md'
    strategy_md: 'workspace/businesses/example-business/ads/STRATEGY.md'
    business_profile: 'workspace/businesses/example-business/ads/briefing/business-profile.yaml'

  key_findings:
    opportunities:
      - 'Competitors not using video ads -- opportunity for video-first approach'
      - 'No competitor addresses {specific pain point}'
      - 'Market gap in {audience segment}'
    risks:
      - 'No Pixel/CAPI detected on brand site'
      - 'Competitor {name} dominates Ad Library with 50+ active ads'
      - 'Pricing higher than market average without clear differentiation'

  recommended_next:
    skill: 'funnel-selection'
    command: '*select-funnel'
    reason: 'Research complete, select funnel type before campaign-briefing'
```

---

## Safety and Constraints

```yaml
tier: 'Auto'
rationale: 'Research protocol is entirely read-only -- no API writes, no budget changes, no campaign modifications'

constraints:
  - 'WebFetch: max 10 pages total per execution (5 brand + 5 competitor)'
  - 'WebSearch: max 5 queries per competitor identification'
  - 'MCP get_insights: read-only, no write operations'
  - 'Never publish or share competitive data externally'
  - 'Minimum 2 competitors required for valid analysis (warn if below, do not halt)'
  - 'If brand site is unreachable, log error and proceed with available data'

error_handling:
  site_unreachable: 'Log warning, skip Phase 2 brand crawl, note gap in research-brief'
  no_competitors_found: 'Use industry template competitors as fallback reference'
  mcp_unavailable: 'Fall back to Path B (industry benchmarks) in Phase 5'
  ad_library_blocked: 'Note limitation in research-brief, proceed with WebSearch data only'
```

---

## Integration

### Triggered By

- Start of new campaign (mandatory first action)
- `setup-business-profile` -- after collecting business data
- User command -- `*research {business_slug}`

### Dispatches To

- `funnel-selection` -- to select funnel type post-research
- `competitive-intel` -- can be called standalone for deep-dive on a specific competitor
- `unit-economics` -- when research identifies pricing/margin data
- `campaign-briefing` -- research-brief feeds Phase 2 of briefing

### Agent Assignment

- **Primary:** @ad-midas (concierge model)
- **Execution:** @ad-midas orchestrates all 5 phases
- **Input from:** @performance-analyst (if historical data exists)

---

## Dependencies

| Type | Resource | Path |
|------|----------|------|
| Template | STRATEGY.md | `squads/aiox-ads/templates/strategy.md` |
| Template | research-brief.md | `squads/aiox-ads/templates/research-brief.md` |
| Template | business-profile.yaml | `squads/aiox-ads/templates/business-profile.yaml` |
| Template | product-card.yaml | `squads/aiox-ads/templates/product-card.yaml` |
| Template | icp-profile.yaml | `squads/aiox-ads/templates/icp-profile.yaml` |
| Knowledge | Industry templates | `squads/aiox-ads/data/industry-templates/{industry}.yaml` |
| Config | Safety rules | `squads/aiox-ads/config/safety-rules.yaml` |
| Tools | WebFetch | Brand and competitor crawling |
| Tools | WebSearch | Competitor identification |
| Tools | MCP (meta-ads) | Historical ad performance (conditional) |

---

## Usage Examples

```
*research aiox
  --> Executes full 5-phase protocol for business slug "aiox"

*research bilhon --skip-phase5
  --> Executes phases 1-4 only (new business, no ad history)

*research empresa-exemplo --competitors "Competitor A, Competitor B"
  --> Skips competitor identification, goes straight to analysis
```

---

_Research Protocol Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
