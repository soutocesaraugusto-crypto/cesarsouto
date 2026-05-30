# Tracking Audit Skill

**ID:** `tracking-audit`
**Category:** diagnostic
**Domain:** media-buyer
**Version:** 1.0.0

---

## Overview

Auditoria completa do setup de tracking incluindo Pixel, CAPI, eventos, deduplicação e match rate. Identifica problemas que afetam atribuição e otimização.

**Activation Command:** `*audit-tracking`
**Announce:** "Ativando Tracking Audit com CAPI Optimization Framework."

---

## Expert Sources

| Expert        | Framework               | Weight | Focus                 |
| ------------- | ----------------------- | ------ | --------------------- |
| Jeremy Haynes | CAPI Optimization       | 0.95   | Server-side tracking  |
| Jeremy Haynes | Pixel Funnel Validation | 0.93   | Hierarquia de eventos |
| Jeremy Haynes | Tracking Validation     | 0.92   | Discrepâncias         |

---

## Audit Checklist

### 1. Pixel Installation

```yaml
checks:
  - id: 'PIX-001'
    name: 'Base Code Present'
    check: 'Pixel base code em todas as páginas'
    severity: 'critical'

  - id: 'PIX-002'
    name: 'Single Installation'
    check: 'Apenas uma instalação do pixel'
    severity: 'high'
    common_issue: 'Duplicação via GTM + hardcode'

  - id: 'PIX-003'
    name: 'Correct Pixel ID'
    check: 'ID corresponde ao Business Manager'
    severity: 'critical'
```

### 2. Event Configuration

```yaml
event_hierarchy:
  required_events:
    - event: 'PageView'
      location: 'Todas as páginas'
      validates: 'Instalação básica'

    - event: 'ViewContent'
      location: 'Páginas de produto/vendas'
      validates: 'Interesse inicial'
      parameters: ['content_ids', 'content_type', 'value', 'currency']

    - event: 'AddToCart'
      location: 'Botão adicionar ao carrinho'
      validates: 'Intenção de compra'
      parameters: ['content_ids', 'value', 'currency']

    - event: 'InitiateCheckout'
      location: 'Início do checkout'
      validates: 'Alta intenção'
      parameters: ['value', 'currency', 'num_items']

    - event: 'Purchase'
      location: 'Página de obrigado'
      validates: 'Conversão final'
      parameters: ['value', 'currency', 'content_ids', 'order_id']
      critical: true

    - event: 'Lead'
      location: 'Formulário enviado'
      validates: 'Captura de contato'
      parameters: ['value', 'currency']

funnel_validation:
  rule: 'PageView > ViewContent > ATC > IC > Purchase'
  ratio_check:
    vc_to_pv: '> 10%'
    atc_to_vc: '> 5%'
    ic_to_atc: '> 30%'
    purchase_to_ic: '> 20%'
```

### 3. CAPI Configuration

```yaml
capi_checks:
  - id: 'CAPI-001'
    name: 'CAPI Active'
    check: 'Conversions API configurada'
    severity: 'critical'

  - id: 'CAPI-002'
    name: 'Event Match Quality'
    check: 'EMQ >= 6.0'
    severity: 'high'
    current_benchmark: 6.0

  - id: 'CAPI-003'
    name: 'Deduplication'
    check: 'event_id único por evento'
    severity: 'high'

  - id: 'CAPI-004'
    name: 'User Data Parameters'
    check: 'email, phone, name hasheados'
    severity: 'medium'

required_parameters:
  mandatory:
    - external_id: 'ou fbp/fbc'
    - client_ip_address: 'IP do usuário'
    - client_user_agent: 'User agent'

  high_priority:
    - em: 'Email hasheado SHA-256'
    - ph: 'Telefone hasheado'
    - fn: 'Primeiro nome hasheado'

  medium_priority:
    - ln: 'Sobrenome hasheado'
    - ct: 'Cidade hasheada'
    - zp: 'CEP hasheado'
```

### 4. Match Rate Analysis

```yaml
match_rate_benchmarks:
  excellent: '> 90%'
  good: '80% - 90%'
  acceptable: '60% - 80%'
  poor: '< 60%'

improvement_actions:
  - action: 'Adicionar email hasheado'
    impact: '+15-20% match rate'
  - action: 'Adicionar telefone hasheado'
    impact: '+10-15% match rate'
  - action: 'Adicionar external_id'
    impact: '+5-10% match rate'
```

---

## Audit Process

### Step 1: Data Collection

```javascript
const auditData = {
  // From Events Manager
  pixelEvents: await getPixelEvents(),
  capiEvents: await getCAPIEvents(),
  eventMatchQuality: await getEMQ(),

  // From website
  pixelInstallation: await checkPixelInstallation(),
  eventFiring: await testEventFiring(),

  // From backend
  capiLogs: await getCAPILogs(),
  deduplicationCheck: await checkDeduplication(),
};
```

### Step 2: Validation

```javascript
const validations = [
  validatePixelInstallation(auditData),
  validateEventHierarchy(auditData),
  validateCAPISetup(auditData),
  validateDeduplication(auditData),
  validateMatchRate(auditData),
];
```

### Step 3: Issue Identification

```javascript
const issues = validations
  .filter((v) => !v.passed)
  .map((v) => ({
    id: v.checkId,
    severity: v.severity,
    description: v.issue,
    recommendation: v.fix,
    expert: v.expert,
  }));
```

---

## Output Format

```yaml
tracking_audit:
  audit_date: '2026-02-01'
  domain: 'example.com'
  pixel_id: '123456789'

  overall_health: 'needs_attention' # healthy, needs_attention, critical
  score: 72 # 0-100

  checks:
    pixel_installation:
      status: 'passed'
      details: 'Pixel instalado corretamente'

    event_configuration:
      status: 'warning'
      details: 'ViewContent sem parâmetros value/currency'
      fix: "Adicionar fbq('track', 'ViewContent', {value: X, currency: 'BRL'})"

    capi:
      status: 'critical'
      details: 'CAPI não configurada'
      impact: '~40% perda de atribuição iOS'
      fix: 'Implementar CAPI via integração nativa ou GTM Server'

    deduplication:
      status: 'warning'
      details: 'event_id não encontrado'
      impact: 'Possível duplicação de eventos'

    match_rate:
      current: 58
      benchmark: 80
      status: 'poor'
      missing_params: ['em', 'ph']

  issues:
    critical: 1
    high: 2
    medium: 1

  recommendations:
    - priority: 1
      action: 'Implementar CAPI'
      impact: '+40% atribuição'
      expert: 'Jeremy Haynes'

    - priority: 2
      action: 'Adicionar event_id para deduplicação'
      impact: 'Dados mais precisos'
      expert: 'Jeremy Haynes'

    - priority: 3
      action: 'Enviar email e telefone hasheados'
      impact: '+25% match rate'
      expert: 'Jeremy Haynes'
```

---

## Integration

### Triggers

```yaml
triggers:
  - condition: 'conversions == 0 AND clicks > 100'
    action: 'run_tracking_audit'
    urgency: 'critical'

  - condition: 'event_match_quality < 5'
    action: 'run_tracking_audit'
    urgency: 'high'

  - condition: 'platform_conversions != backend_conversions > 30%'
    action: 'run_tracking_audit'
    urgency: 'critical'
```

### Dispatches To

- `metric-diagnosis` - após corrigir tracking
- `campaign-monitor` - para reavaliação

### Agent Assignment

- **Primary:** @pixel-specialist
- **Reports to:** @media-strategist

---

## Usage Examples

```
*audit-tracking

*audit-tracking --domain example.com

*audit-tracking --focus capi --detailed
```

### Sample Output

```
📍 AUDITORIA DE TRACKING

╔══════════════════════════════════════════════════════╗
║ DOMÍNIO: example.com                                 ║
║ PIXEL ID: 123456789                                  ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║ HEALTH SCORE: 72/100 - NEEDS ATTENTION              ║
║                                                      ║
║ ✅ Pixel Installation: OK                            ║
║ ⚠️  Event Configuration: Warning                     ║
║ 🔴 CAPI: Not Configured                             ║
║ ⚠️  Deduplication: Missing event_id                 ║
║ 🔴 Match Rate: 58% (benchmark: 80%)                 ║
║                                                      ║
╠══════════════════════════════════════════════════════╣
║ AÇÃO PRIORITÁRIA: Implementar CAPI                   ║
║ IMPACTO: +40% atribuição (Jeremy Haynes)            ║
╚══════════════════════════════════════════════════════╝
```

---

_Tracking Audit Skill v1.0.0_
_Media Buyer Squad - AIOS Synkra_
