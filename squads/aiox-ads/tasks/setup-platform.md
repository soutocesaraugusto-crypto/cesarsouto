---
task_id: setup-platform
version: 1.0
category: ads_setup
squad: aiox-ads
agent: ads-traffic-chief
elicit: true
---

# Setup Platform — First-Time Configuration

## Process

1. **Select platform** -- Ask user which platform(s) to configure
   - Meta, Google, LinkedIn, TikTok, Microsoft, YouTube, Apple
2. **Collect credentials** -- Request API keys, tokens, or account IDs
   - Store in environment variables (never hardcode)
3. **Verify pixel/tag** -- Confirm tracking pixel is installed and firing
   - Meta: Pixel + CAPI status
   - Google: Google Tag + Enhanced Conversions
   - LinkedIn: Insight Tag
   - TikTok: TikTok Pixel + Events API
   - Microsoft: UET Tag
4. **Check CAPI** -- Verify server-side tracking if available
   - Meta CAPI: event_id deduplication, EMQ score
   - Google Enhanced Conversions: consent mode
5. **Validate events** -- Confirm conversion events are firing correctly
   - Use Test Events (Meta) or Tag Assistant (Google)
6. **Generate status report** -- Summary of configured vs missing items

## Output

Write `platform-setup-status.yaml` with per-platform configuration status.
