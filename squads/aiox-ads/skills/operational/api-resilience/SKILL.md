# API Resilience Skill

**ID:** `api-resilience`
**Category:** operational
**Domain:** aiox-ads
**Version:** 1.0.0

---

## Overview

Sistema de resiliencia embarcado em todos os agentes que fazem chamadas API. Implementa circuit breaker, backoff exponencial, monitoramento de quota, protecao contra token expirado, checagem de status da plataforma e idempotencia em operacoes de criacao. Este skill NAO e ativado manualmente -- e carregado automaticamente por qualquer agente que executa operacoes API.

**Activation Command:** Automatico (embedded em todos os agentes com API access)
**Announce:** N/A -- skill silencioso, opera como camada de protecao

---

## Agent Assignment

- **Primary:** system (embedded em todos os agentes que chamam API)
- **Tier:** Auto (todas as protecoes operam autonomamente)
- **Reports to:** @ad-midas (alertas escalam via concierge)

---

## References

| Arquivo | Finalidade |
|---------|-----------|
| `data/rate-limits.yaml` | Thresholds de rate limit por tier, circuit breaker, custos por operacao |
| `config/safety-rules.yaml` | Regras de seguranca, WAL, idempotencia, protecao de outage |

---

## Core Capabilities

### 1. Circuit Breaker -- HTTP 429 (Rate Limit Exceeded)

Quando a API retorna HTTP 429, TODA automacao para imediatamente e aplica exponential backoff.

**Referencia canonica:** `data/rate-limits.yaml` > `circuit_breaker.http_429`

```yaml
strategy: exponential_backoff
backoff_sequence:
  - attempt: 1 | delay: 1s
  - attempt: 2 | delay: 2s
  - attempt: 3 | delay: 4s
  - attempt: 4 | delay: 8s
  - attempt: 5 | delay: 16s
  - attempt: 6 | delay: 32s
  - attempt: 7 | delay: 60s  # max -- nunca excede 60s
max_delay_seconds: 60
max_retries: 7
jitter: true  # +/- 20% random para evitar thundering herd
```

**Apos max retries (7 tentativas sem sucesso):**

```
1. HALT todas as operacoes de API
2. Registrar no WAL com status "rate_limited"
3. Alertar humano: "Rate limit persistente. Quota provavelmente zerada."
4. Aguardar block_duration do tier:
   - Development: 300s (5 min)
   - Standard: 60s (1 min)
5. Apos block_duration: tentar 1 request de teste (GET status)
6. Se sucesso: retomar com cadencia reduzida (50% da normal)
7. Se falha: HALT definitivo e escalar para humano
```

### 2. Circuit Breaker -- HTTP 5xx (Server Error)

Respostas HTTP 5xx indicam problema no lado da plataforma. Nao e culpa do agente, mas DEVE parar para evitar acoes duplicadas.

**Referencia canonica:** `data/rate-limits.yaml` > `circuit_breaker.http_5xx`

```yaml
strategy: halt_after_threshold
consecutive_threshold: 3
```

**Protocolo apos 3 erros 5xx consecutivos:**

```
1. HALT todas as operacoes de write (reads podem continuar com cautela)
2. Registrar no WAL: "platform_outage_suspected"
3. Verificar metastatus.com para confirmar outage
4. Se outage confirmado:
   - Pausar ALL API operations
   - Armazenar ultimo estado conhecido localmente
   - Alertar humano: "Outage Meta confirmado. Operacoes pausadas."
   - NAO executar retry automatico durante outage
5. Se metastatus OK (falso positivo):
   - Aguardar 60s
   - Tentar 1 request de teste
   - Se sucesso: retomar com cautela
```

**Recuperacao pos-outage:**

```
1. Reconciliacao: comparar state local vs API
2. Identificar operacoes pendentes do WAL
3. Executar operacoes pendentes uma a uma (NAO batch)
4. Validar cada resultado antes de prosseguir
```

### 3. Quota Monitoring

Monitoramento continuo do consumo de quota API contra os thresholds definidos em `data/rate-limits.yaml`.

**Referencia canonica:** `data/rate-limits.yaml` > `quota_monitoring`

```yaml
alert_threshold_pct: 80

behavior_at_80pct:
  1. Reduzir cadencia de requests para 50% do normal
  2. Priorizar operacoes criticas (reads de metricas)
  3. Adiar creates/updates nao-urgentes para proximo ciclo de quota
  4. Alertar humano: "Quota API > 80%. Cadencia reduzida automaticamente."

recovery_after_reset:
  1. Retomar cadencia gradualmente (NAO burst)
  2. Primeira hora apos recovery: 75% da cadencia normal
  3. Se sem 429 por 1 hora: retomar 100%
```

**Cadencia maxima por tier (de `data/rate-limits.yaml`):**

| Tier | Max Points/Hora | Campaign Monitor Cycle | Guidance |
|------|----------------|----------------------|----------|
| Development | 60 | NAO rodar loop | Max 1 req/min, priorizar reads |
| Standard | 9.000 | Max 1 cycle / 15 min (4/h) | Batch API, alertar > 80% quota |
| Advanced | Varia por app | Max 1 cycle / 5 min (12/h) | Batch recomendado mesmo com quota maior |

**Custos estimados por operacao (de `data/rate-limits.yaml`):**

| Operacao | Pontos | Nota |
|----------|--------|------|
| Read (campaign/adset/ad) | 1 | Baixo custo |
| Read insights | 2-5 | Varia por breakdown e time range |
| Create/Update (campaign/adset/ad) | 3-5 | Medio custo |
| Read audience insights | 5-10 | Alto custo |
| Create custom audience | 10-20 | Muito alto |
| Audience refresh | 40 | Escala MAL -- limitar frequencia |

### 4. Token Expiry Alert

Monitoramento proativo de expiracao de tokens OAuth para evitar interrupcoes totais.

**Referencia canonica:** `data/rate-limits.yaml` > `token_management`

```yaml
monitoring:
  alert_days_before: 7
  check_frequency: daily  # Parte do campaign-monitor cycle
  token_lifecycle: 60 days  # Ciclo padrao Pipeboard OAuth

alert_format: |
  "[ALERTA TOKEN] Access token para {platform} expira em {days} dias.
   Token: {masked_token_last_4}
   Acao necessaria: renovar token manualmente (Human Only action).
   Consultar: squads/aiox-ads/mcp/setup-guide.md"

token_rotation_rule: |
  Pipeboard token: META_ADS_ACCESS_TOKEN (primary)
  ads-mcp token: META_ADS_ACCESS_TOKEN_SECONDARY (fallback)
  REGRA: NUNCA usar o mesmo token para ambos os MCPs simultaneamente
```

**Acao:** Human Only -- `manage-api-credentials` (conforme `config/autonomy-tiers.yaml`)

### 5. Metastatus Check (Pre-Write Gate)

ANTES de qualquer operacao de write (create/update/activate/pause), verificar status da plataforma.

**Referencia canonica:** `data/rate-limits.yaml` > `platform_status`

```yaml
url: "https://metastatus.com"
check_before_writes: true

relevant_services:
  - "Facebook Ads Manager"
  - "Ad Creation and Editing"
  - "Ad Delivery"
  - "Marketing API"

logic: |
  SE algum servico relevante esta "Disrupted" ou "Degraded":
    → HALT todas as operacoes de write
    → Reads podem continuar
    → Alertar humano sobre degradacao
  SE todos OK:
    → Prosseguir normalmente
```

### 6. Idempotency (Duplicate Prevention)

Toda operacao de criacao DEVE incluir identificador unico para evitar duplicatas em caso de timeout/retry.

**Referencia canonica:** `config/safety-rules.yaml` > `additional_rules.idempotency`

```yaml
implementation:
  1. campaign-manager gera UUID ANTES de cada create operation
  2. UUID registrado no WAL junto com a operacao
  3. Se API timeout durante create:
     a. Verificar se entidade com mesmo UUID ja existe (GET)
     b. Se existe: operacao ja foi executada, NAO retry
     c. Se NAO existe: retry seguro com mesmo UUID
  4. UUID propagado como external_id ou deduplication_key na API

format: "{entity_type}-{campaign_slug}-{timestamp}-{random_4}"
example: "campaign-launch-meta-cold-20260318T1430-a7b2"
```

---

## SE/ENTAO Rules

```yaml
rules:
  - condition: "SE HTTP 429 recebido"
    action: "HALT + exponential backoff (1s, 2s, 4s, 8s, 16s, 32s, max 60s)"
    severity: critical
    ref: "data/rate-limits.yaml > circuit_breaker.http_429"

  - condition: "SE 3 erros HTTP 5xx consecutivos"
    action: "HALT writes + verificar metastatus.com + alertar humano"
    severity: critical
    ref: "data/rate-limits.yaml > circuit_breaker.http_5xx"

  - condition: "SE quota API > 80%"
    action: "Reduzir cadencia para 50% + priorizar reads + adiar writes"
    severity: high
    ref: "data/rate-limits.yaml > quota_monitoring"

  - condition: "SE token expira em < 7 dias"
    action: "Alertar humano com formato padrao + path para setup-guide.md"
    severity: high
    ref: "data/rate-limits.yaml > token_management"

  - condition: "SE metastatus.com mostra servico 'Disrupted' ou 'Degraded'"
    action: "HALT todas as operacoes de write ate normalizacao"
    severity: critical
    ref: "data/rate-limits.yaml > platform_status"

  - condition: "SE timeout em operacao de create"
    action: "Verificar existencia via UUID antes de retry (idempotency)"
    severity: high
    ref: "config/safety-rules.yaml > additional_rules.idempotency"

  - condition: "SE tier = Development (60 points/hora)"
    action: "NAO rodar campaign-monitor loop. Max 1 req/min"
    severity: high
    ref: "data/rate-limits.yaml > api_tiers.development"

  - condition: "SE token Pipeboard E ads-mcp apontam para mesmo valor"
    action: "WARN: tokens NAO devem ser compartilhados entre MCPs"
    severity: medium
    ref: "data/rate-limits.yaml > token_management.token_rotation"
```

---

## Decision Flow

```
┌─────────────────────────────────────────────────────────┐
│               API RESILIENCE DECISION FLOW              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌──────────┐                                         │
│   │ API CALL │                                         │
│   │ INITIATED│                                         │
│   └────┬─────┘                                         │
│        │                                               │
│        ▼                                               │
│   ┌──────────┐   NO    ┌──────────┐                   │
│   │ IS WRITE │────────▶│ CHECK    │                   │
│   │ OPERATION│         │ QUOTA    │                   │
│   └────┬─────┘         └────┬─────┘                   │
│    YES │                    │                          │
│        ▼                    ▼                          │
│   ┌──────────┐        ┌──────────┐                    │
│   │ CHECK    │        │ > 80%?   │── YES ──▶ REDUCE   │
│   │METASTATUS│        │          │          CADENCE    │
│   └────┬─────┘        └────┬─────┘                    │
│        │                   │ NO                        │
│   ┌────┴─────┐             │                          │
│   │ GREEN?   │── NO ──▶ HALT WRITES                   │
│   └────┬─────┘                                        │
│    YES │                                              │
│        ▼                                              │
│   ┌──────────┐                                        │
│   │ GENERATE │                                        │
│   │ UUID     │ (if create)                            │
│   └────┬─────┘                                        │
│        │                                              │
│        ▼                                              │
│   ┌──────────┐                                        │
│   │ REGISTER │                                        │
│   │ IN WAL   │                                        │
│   └────┬─────┘                                        │
│        │                                              │
│        ▼                                              │
│   ┌──────────┐                                        │
│   │ EXECUTE  │                                        │
│   │ API CALL │                                        │
│   └────┬─────┘                                        │
│        │                                              │
│   ┌────┴──────────────────────────────┐               │
│   │           RESPONSE?               │               │
│   ├────────┬────────┬────────┬────────┤               │
│   │ 2xx    │ 429    │ 5xx    │TIMEOUT │               │
│   │SUCCESS │RATE LIM│SERVER  │        │               │
│   ├────────┼────────┼────────┼────────┤               │
│   │ Update │Backoff │Counter │Check   │               │
│   │ WAL:   │1s→2s→  │+1     │UUID    │               │
│   │executed│4s→8s→  │       │exists? │               │
│   │        │16s→32s→│       │        │               │
│   │ DONE   │60s max │>=3?   │Y:DONE  │               │
│   │        │        │HALT + │N:RETRY │               │
│   │        │7x fail?│ALERT  │        │               │
│   │        │HALT    │       │        │               │
│   └────────┴────────┴────────┴────────┘               │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## Integration

| Sistema | Conexao |
|---------|---------|
| `data/rate-limits.yaml` | Fonte de TODOS os thresholds (tiers, backoff, quota, token, metastatus) |
| `config/safety-rules.yaml` | Regras de WAL, idempotencia, validacao pos-create, outage protection |
| `config/autonomy-tiers.yaml` | Define quais acoes sao Auto/HITL/Human (check-rate-limit-status: Auto) |
| `templates/action-ledger.yaml` | Registra acoes executadas apos recovery |
| `mcp/mcp-config.json` | Routing rules para separacao Pipeboard vs ads-mcp |

---

## Cross-Platform Support

As mesmas regras de resiliencia se aplicam a plataformas non-Meta via ads-mcp, com thresholds ajustados:

| Plataforma | Rate Limit | Nota |
|-----------|-----------|------|
| Google Ads | 10.000 ops/dia, 1 QPS/customer | Mutate consome mais quota |
| LinkedIn Ads | 100.000 req/dia, 10 RPS | Targeting restrito |
| TikTok Ads | 600 req/min | Docs menos maduros -- monitorar de perto |
| Instagram DM | 200/hora (hard limit) | Exceder = conta restrita |

**Regra universal:** Aplicar mesmos principios de circuit breaker (429 -> backoff, 5xx -> halt) independente da plataforma.

---

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Esta documentacao |

---

## Dependencies

```yaml
requires:
  data:
    - data/rate-limits.yaml        # Thresholds canonicos
    - config/safety-rules.yaml     # Regras de seguranca

  integrations:
    - metastatus.com               # Pre-write platform check
    - WAL (Write-Ahead Log)        # Registro de operacoes

  agents:
    - ALL API-calling agents       # Skill embarcado em todos
```

---

_API Resilience Skill v1.0.0_
_AIOX Ads Squad_
