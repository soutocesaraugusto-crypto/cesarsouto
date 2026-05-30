# Competitive Intel Skill

**ID:** `competitive-intel`
**Category:** strategic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Analise profunda de anuncios de concorrentes via Facebook Ad Library e pesquisa web. Extrai padroes de formatos, hooks, frequencia, tempo de atividade e copy patterns para identificar oportunidades e ameacas no cenario competitivo.

**Activation Command:** `*spy-ads {competitor_name}`
**Announce:** "Ativando Competitive Intel -- analise de anuncios do concorrente via Ad Library."
**Agent:** @ad-midas
**Tier:** Auto (read-only, no API writes)

---

## Expert Sources

| Expert         | Framework                    | Weight | Focus                              |
| -------------- | ---------------------------- | ------ | ---------------------------------- |
| Brian Moncada  | Competitive Ad Analysis      | 0.94   | Ad Library reverse engineering     |
| Jeremy Haynes  | Spy Framework                | 0.91   | Competitor funnel deconstruction   |
| Alex Hormozi   | Market Positioning           | 0.88   | Differentiation from competitors   |
| Russell Brunson | Funnel Hacking              | 0.85   | Competitor funnel modeling         |

---

## Ad Library Analysis Protocol

### Step 1 -- Access Ad Library

```yaml
name: 'Fetch Facebook Ad Library'
tool: 'WebFetch'

url_template: 'https://www.facebook.com/ads/library/?active_status=active&ad_type=all&country=BR&q={competitor_name}'

parameters:
  active_status: 'active'  # Focus on currently running ads
  ad_type: 'all'           # All ad types
  country: 'BR'            # Default Brazil, override via --country flag
  query: '{competitor_name}'

fallback:
  if_blocked: 'Use WebSearch with query "facebook ad library {competitor_name} ads"'
  if_no_results: 'Try alternative names, page URL, or broader search terms'
```

### Step 2 -- Extract Ad Data

```yaml
name: 'Analyze Active Ads'

extract_per_ad:
  format:
    type: 'video / image / carousel / collection'
    aspect_ratio: '1:1 / 4:5 / 9:16 / 16:9'
    duration: 'video length if applicable'

  creative:
    hook_line: 'First line of primary text or first 3 seconds of video'
    main_angle: 'pain / result / authority / social-proof / urgency / curiosity'
    cta_button: 'Shop Now / Learn More / Sign Up / etc.'
    landing_destination: 'Website / Lead Form / Instant Experience / WhatsApp'

  timing:
    start_date: 'When ad started running'
    days_active: 'Calculated from start date'
    status: 'active'

  copy_patterns:
    primary_text_length: 'short (<100 chars) / medium (100-300) / long (300+)'
    headline: 'Ad headline text'
    description: 'Ad description text'
    emoji_usage: 'none / light / heavy'
    language_style: 'formal / informal / conversational / aggressive'

  platforms:
    placements: 'Facebook / Instagram / Messenger / Audience Network'

max_ads_to_analyze: 20  # Focus on most recent / longest running
```

### Step 3 -- Pattern Analysis

```yaml
name: 'Identify Patterns Across Ads'

analysis_dimensions:
  format_distribution:
    description: 'Percentage breakdown of ad formats'
    output: |
      video: X%
      image: Y%
      carousel: Z%

  hook_categories:
    description: 'Classify hooks into categories'
    categories:
      - 'Pain point (addresses a problem)'
      - 'Result showcase (shows outcome)'
      - 'Authority (credentials, numbers)'
      - 'Social proof (testimonials, reviews)'
      - 'Urgency/scarcity (limited time/quantity)'
      - 'Curiosity (open loop, question)'
      - 'Contrarian (challenges belief)'

  ad_lifespan_analysis:
    description: 'Identify long-running ads (likely winners)'
    tiers:
      winner: '> 30 days active (high confidence performer)'
      testing: '7-30 days (being evaluated)'
      new: '< 7 days (recently launched)'
    insight: 'Long-running ads indicate proven creative -- study these closely'

  copy_patterns:
    description: 'Recurring copy structures and formulas'
    detect:
      - 'PAS (Problem-Agitate-Solve)'
      - 'AIDA (Attention-Interest-Desire-Action)'
      - 'Before/After framework'
      - 'Listicle format (3 reasons, 5 steps)'
      - 'Testimonial-led'
      - 'Question-led'

  spend_estimation:
    description: 'Estimate relative spend from ad volume and longevity'
    method: |
      High volume (20+ active ads) + long-running = significant budget
      Low volume (1-5 active ads) + short duration = testing phase
      Many variations of same creative = active A/B testing
    note: 'Estimates only -- Meta does not disclose actual spend'
```

### Step 4 -- Competitive Assessment

```yaml
name: 'Synthesize Intelligence'

deliverables:
  top_performing_formats:
    description: 'Formats most frequently used and longest running'
    max_items: 3

  common_hooks_by_category:
    description: 'Most used hook types with examples'
    format: |
      1. {hook_category}: {example_from_ad} (X ads using this)
      2. {hook_category}: {example_from_ad} (X ads using this)

  estimated_spend_pattern:
    description: 'Relative budget allocation inference'
    indicators:
      - 'Number of active ads'
      - 'Ad longevity distribution'
      - 'Creative variation count'
      - 'Platform coverage breadth'

  creative_gaps:
    description: 'What the competitor is NOT doing'
    check:
      - 'Missing video content?'
      - 'No UGC-style creative?'
      - 'No carousel showcasing features?'
      - 'No retargeting-specific messaging?'
      - 'No seasonal/event-based creative?'

  vulnerability_assessment:
    description: 'Where competitor ads are weak'
    check:
      - 'Repetitive hooks (audience fatigue risk)'
      - 'No social proof in ads'
      - 'Weak CTAs'
      - 'Low-quality creative production'
      - 'Inconsistent brand messaging'
```

---

## Multi-Competitor Comparison

```yaml
name: 'Cross-Competitor Matrix'
trigger: 'When analyzing 2+ competitors'

matrix_format: |
  | Dimension          | Competitor A | Competitor B | Competitor C | OUR BUSINESS |
  |--------------------|-------------|-------------|-------------|--------------|
  | Active ads count   |             |             |             |              |
  | Top format         |             |             |             |              |
  | Primary hook type  |             |             |             |              |
  | Avg ad lifespan    |             |             |             |              |
  | CTA preference     |             |             |             |              |
  | Copy length        |             |             |             |              |
  | Video usage        |             |             |             |              |
  | UGC presence       |             |             |             |              |
  | Carousel usage     |             |             |             |              |
  | Landing type       |             |             |             |              |

synthesis:
  - 'Identify what ALL competitors do (table stakes -- must match)'
  - 'Identify what NO competitor does (blue ocean opportunity)'
  - 'Identify what only 1 competitor does well (differentiation source)'
```

---

## Output Format

```yaml
competitive_intel:
  competitor: 'Concorrente X'
  analysis_date: '2026-03-18'
  agent: '@ad-midas'
  ad_library_country: 'BR'

  summary:
    active_ads_count: 23
    longest_running_ad: '45 days'
    dominant_format: 'video (52%)'
    dominant_hook: 'result-showcase'
    estimated_budget_level: 'high (20+ ads, multiple long-running)'

  format_breakdown:
    video: 52
    image: 30
    carousel: 13
    collection: 5

  top_hooks:
    - category: 'result-showcase'
      example: 'Como faturei R$100k em 30 dias usando...'
      frequency: 8
    - category: 'pain-point'
      example: 'Cansado de gastar em anuncios que nao convertem?'
      frequency: 6
    - category: 'authority'
      example: 'Mais de 500 clientes atendidos desde 2020'
      frequency: 5

  copy_patterns:
    avg_primary_text_length: 'medium (150-250 chars)'
    common_structure: 'PAS (Problem-Agitate-Solve)'
    emoji_usage: 'light'
    language_style: 'conversational'

  winner_ads:
    - description: 'Video 30s -- depoimento de cliente mostrando resultado'
      days_active: 45
      hook: 'Eu estava falido ate descobrir...'
      format: 'video 4:5'
      cta: 'Learn More'

  creative_gaps:
    - 'No carousel ads showcasing features'
    - 'No UGC-style content'
    - 'No retargeting-specific messaging detected'

  vulnerabilities:
    - 'Repetitive hooks -- 6 ads with same pain-point angle'
    - 'No video ads shorter than 30s (missing Reels format)'
    - 'All ads lead to same landing page (no funnel segmentation)'

  opportunities_for_us:
    - 'UGC-style video ads (competitor gap)'
    - 'Short-form Reels creative (untapped format)'
    - 'Carousel with feature comparison (competitive positioning)'

  output_file: 'workspace/businesses/{slug}/ads/research/research-brief-{campaign_slug}.md'
  section_updated: 'Section 2 -- Competitive Landscape'
```

---

## Safety and Constraints

```yaml
tier: 'Auto'
rationale: 'Competitive intelligence is entirely read-only -- accesses public Ad Library data and public websites only'

constraints:
  - 'ONLY access publicly available data (Facebook Ad Library is public)'
  - 'NEVER attempt to access private ad accounts or business managers'
  - 'NEVER scrape personal data from ads (phone numbers, emails)'
  - 'Max 20 ads analyzed per competitor per execution'
  - 'Max 5 competitors per single execution'
  - 'WebFetch: max 10 page loads per competitor (Ad Library + site pages)'
  - 'Results are intelligence for internal strategy only -- never publish raw competitive data'

error_handling:
  ad_library_blocked: 'Fall back to WebSearch for cached Ad Library data or competitor ad screenshots'
  competitor_not_found: 'Try alternative spellings, page URL direct, or broader search'
  no_active_ads: 'Report "no active ads detected" -- competitor may be pausing or using different pages'
  rate_limited: 'Wait 30s and retry once, then log and proceed with partial data'
```

---

## Integration

### Triggered By

- `research-protocol` Phase 3 -- como parte do fluxo de pesquisa completo
- User command -- `*spy-ads {competitor_name}` (standalone deep-dive)
- Periodic competitive monitoring (manual trigger)

### Dispatches To

- `research-protocol` -- contribui para Section 2 do research-brief
- `creative-brief` -- insights de formato e hook alimentam briefing criativo
- `hook-generator` -- hooks dos concorrentes como anti-referencia (fazer diferente)
- `angle-generator` -- gaps criativos como input para novos angulos

### Agent Assignment

- **Primary:** @ad-midas (concierge model)
- **Input from:** @creative-analyst (creative pattern interpretation)

---

## Dependencies

| Type | Resource | Path |
|------|----------|------|
| Template | research-brief.md | `squads/aiox-ads/templates/research-brief.md` |
| Tools | WebFetch | Ad Library access and competitor site crawling |
| Tools | WebSearch | Competitor identification and fallback |
| Knowledge | Industry templates | `squads/aiox-ads/data/industry-templates/{industry}.yaml` (for benchmark comparison) |

---

## Usage Examples

```
*spy-ads "Hotmart"
  --> Full Ad Library analysis for Hotmart's active ads

*spy-ads "Kiwify" --country US
  --> Analyze Kiwify ads targeting US market

*spy-ads "Competitor A, Competitor B, Competitor C" --compare
  --> Multi-competitor comparison matrix

*spy-ads "Empresa X" --format video --min-days 14
  --> Filter: only video ads running 14+ days (likely winners)
```

---

_Competitive Intel Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
