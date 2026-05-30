# Pixel Setup Skill

**ID:** `pixel-setup`
**Category:** operational
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Instalação e configuração completa de pixel, CAPI e eventos para Meta, Google e YouTube. Diferente do `tracking-audit` (que audita tracking existente), esta skill CRIA tracking do zero.

**Activation Command:** `*setup-pixel`
**Announce:** "Ativando Pixel Setup — configuração completa de tracking."

---

## Expert Sources

| Expert        | Framework                | Weight | Focus                              |
| ------------- | ------------------------ | ------ | ---------------------------------- |
| Jeremy Haynes | CAPI Priority Framework  | 0.95   | Server-side tracking obrigatório   |
| Jeremy Haynes | Event Hierarchy Standard | 0.92   | Funil de eventos padronizado       |
| Jeremy Haynes | Match Rate Optimization  | 0.88   | Parâmetros para EMQ > 80%         |

---

## Setup Framework

### Event Hierarchy (Obrigatório)

```
PageView (todas as páginas) ← OBRIGATÓRIO
    ↓
ViewContent (product/sales pages) + [content_ids, content_type, value, currency]
    ↓
AddToCart (cart/intent) + [content_ids, value, currency]
    ↓
InitiateCheckout (checkout start) + [value, currency, num_items]
    ↓
Purchase (conversion) + [value, currency, content_ids, order_id] ← CRÍTICO
    ↓
Lead (form submission) + [value, currency] ← ALTERNATIVO a Purchase
```

### CAPI Configuration

```yaml
capi_mandatory:
  - external_id      # ou fbp/fbc
  - client_ip_address
  - client_user_agent

capi_high_priority:
  - em               # email (SHA-256)
  - ph               # phone (SHA-256)
  - fn               # first name (SHA-256)

capi_recommended:
  - ln               # last name
  - ct               # city
  - st               # state
  - zp               # zip code
  - country

match_rate_targets:
  excellent: "> 90%"
  good: "80-90%"
  acceptable: "60-80%"
  poor: "< 60% — ação imediata"
```

---

## Setup Process

### Step 1: Platform Detection

```yaml
detect:
  - platform: meta | google | youtube | tiktok
  - stack: wordpress | shopify | next.js | custom
  - goal: ecommerce | lead_gen | webinar | app_install
```

### Step 2: Pixel Installation

```yaml
installation:
  meta:
    - Criar pixel no Events Manager (se não existe)
    - Instalar via partner integration (Shopify/WP) ou tag manual
    - Verificar PageView disparando em todas as páginas
    - Confirmar pixel ID correto (sem duplicatas)
  google:
    - Criar tag de conversão no Google Ads
    - Instalar via Google Tag Manager ou gtag.js
    - Configurar enhanced conversions
    - Verificar no Tag Assistant
  youtube:
    - Usar mesma tag Google Ads
    - Configurar conversion linker
    - Definir janela de atribuição (30-day view-through)
```

### Step 3: Event Configuration

- Mapear funil do negócio para event hierarchy
- Configurar cada evento com parâmetros obrigatórios
- Testar cada evento individualmente (Meta Test Events / Google Tag Assistant)

### Step 4: CAPI Setup

- Configurar server-side tracking (Conversions API)
- Adicionar parâmetros obrigatórios + high priority
- Implementar event_id para deduplicação (browser + server)
- Testar com Meta CAPI Gateway ou custom implementation

### Step 5: Validation

- Confirmar todos os eventos disparando (PageView → Purchase)
- Verificar EMQ (Event Match Quality) > 80%
- Testar deduplicação (evento deve aparecer 1x, não 2x)
- Cross-browser test (Chrome, Safari, Firefox, incógnito)

---

## SE/ENTÃO Rules

```yaml
rules:
  - condition: "SE plataforma = Meta E sem CAPI"
    action: "BLOCK — CAPI é obrigatório pós-iOS14"
    severity: critical

  - condition: "SE EMQ < 60%"
    action: "Adicionar mais parâmetros (em, ph, fn)"
    severity: high

  - condition: "SE evento duplicado detectado"
    action: "Implementar event_id para deduplicação"
    severity: high

  - condition: "SE PageView não dispara em todas páginas"
    action: "Corrigir instalação base antes de configurar eventos"
    severity: critical

  - condition: "SE stack = Shopify"
    action: "Usar Shopify native pixel integration + CAPI gateway"
    severity: info

  - condition: "SE stack = custom (Next.js, React)"
    action: "Implementar via code (não tag manager) para CAPI server-side"
    severity: info
```

---

## Output Format

```yaml
pixel_setup_report:
  platform: "meta"
  pixel_id: "123456789"
  status: "CONFIGURED"

  installation:
    method: "partner_integration"
    pageview_firing: true
    all_pages_covered: true

  events_configured:
    - event: "PageView"
      status: "active"
      params: ["url"]
    - event: "ViewContent"
      status: "active"
      params: ["content_ids", "content_type", "value", "currency"]
    - event: "Purchase"
      status: "active"
      params: ["value", "currency", "content_ids", "order_id"]

  capi:
    status: "active"
    method: "gateway"
    dedup_enabled: true
    emq_score: 8.2

  validation:
    cross_browser: "PASS"
    dedup_test: "PASS"
    event_funnel: "PASS (5/5 events firing)"

  next_steps:
    - "Adicionar fn e ln para melhorar EMQ de 8.2 para 9+"
    - "Monitorar EMQ diariamente por 7 dias"
```

---

## Integration

### Dispatches To

- `tracking-audit` — após setup, rodar audit para confirmar qualidade
- `ad-compliance-gate` — pixel configurado libera gate de tracking

### Receives From

- User command — `*setup-pixel`
- `youtube-campaign-launcher` — pré-requisito de tracking YouTube
- `google-campaign-architect` — pré-requisito de tracking Google

### Agent Assignment

- **Primary:** @pixel-specialist (Track)
- **Reports to:** @ad-midas

---

## Usage Examples

### Command Line

```
*setup-pixel meta shopify ecommerce

*setup-pixel google next.js lead_gen

*setup-pixel --platform meta --validate-only
```

### Sample Output

```
📍 PIXEL SETUP REPORT — Meta Pixel
═══════════════════════════════════════════════════════

✅ Pixel ID: 123456789 — INSTALADO
✅ PageView: disparando em 100% das páginas
✅ Eventos: 5/5 configurados (PV → VC → ATC → IC → Purchase)
✅ CAPI: Ativo via Gateway — Dedup ON
⚠️  EMQ: 8.2/10 (bom, mas pode melhorar com fn/ln)

╔══════════════════════════════════════════════════╗
║ STATUS: CONFIGURED — Pronto para campanhas       ║
╚══════════════════════════════════════════════════╝

Próximos passos:
  1. Adicionar fn + ln para EMQ 9+
  2. Monitorar por 7 dias
  3. Rodar *audit para validação completa
```

---

_Pixel Setup Skill v1.0.0_
_AIOX Ads Squad_
