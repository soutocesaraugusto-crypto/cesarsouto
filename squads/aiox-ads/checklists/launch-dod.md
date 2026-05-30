# Launch Definition of Done (DoD) Checklist

> **Enforced by:** @fiscal (Safety Officer)
> **Type:** Hard Gate -- TODOS os 8 checks devem passar antes de ativacao
> **References:** `config/safety-rules.yaml`, `config/autonomy-tiers.yaml`
> **Story:** SAIOX-ADS-V5-1.6

Este checklist e o gate FINAL antes de ativar qualquer campanha.
TODOS os 8 checks sao BLOCK -- falha em qualquer um impede ativacao.
Adaptado do ads-mcp Definition of Done pattern para contexto AIOX.

---

## Gate 1 -- Campaign Status == PAUSED

- **Descricao:** Campanha DEVE estar com status PAUSED no momento da revisao. Se campanha foi criada como ACTIVE (erro), este gate falha imediatamente.
- **Verificacao:** Executar `get_campaigns` via API (acao Auto: `check-campaign-status` no `autonomy-tiers.yaml`). Confirmar que campo `status` == `PAUSED` para a campanha em questao. Read-back obrigatorio -- nao confiar apenas no state local.
- **Severidade:** BLOCK
- **Remediacao:** Se status != PAUSED, executar `pause-campaign` (HITL) imediatamente. Investigar por que campanha nao foi criada como PAUSED (violacao de `safety-rules.yaml` -- `paused_by_default: true`). Registrar incidente no WAL.
- **Referencia:** `safety-rules.yaml` -- `paused_by_default: true`; `autonomy-tiers.yaml` -- `create-campaign-api` constraints: "status: PAUSED (nunca ACTIVE na criacao)"

---

## Gate 2 -- Pixel/CAPI validado e disparando

- **Descricao:** Tracking deve estar 100% funcional antes de gastar dinheiro. Pixel instalado, CAPI ativo, eventos disparando, match rate aceitavel. Sem tracking, nao ha otimizacao possivel -- budget e desperdicado.
- **Verificacao:** Executar skill `tracking-audit` (acao Auto: `collect-pixel-events` + `detect-tracking-issues` no `autonomy-tiers.yaml`). Validar: (1) PageView disparando, (2) Eventos de conversao configurados (VC, ATC, IC, Purchase/Lead), (3) CAPI ativo e recebendo events, (4) Match rate >= 60% (ideal > 80%).
- **Severidade:** BLOCK
- **Remediacao:** Se pixel nao dispara: verificar instalacao no codigo da pagina. Se CAPI inativo: configurar server-side tracking. Se match rate < 60%: melhorar parametros de matching (email, phone, external_id). Se eventos nao configurados: adicionar via Events Manager ou codigo.
- **Referencia:** `safety-rules.yaml` -- `additional_rules.learning_phase` (tracking broken = abort condition); `autonomy-tiers.yaml` -- `collect-pixel-events` (Auto), `detect-tracking-issues` (Auto)

---

## Gate 3 -- Landing Page EMQ Score >= 6.0

- **Descricao:** Experience Media Quality (EMQ) score avalia qualidade da landing page. Score < 6.0 indica problemas que afetam conversao E quality score do ad (Meta penaliza ads com landing pages ruins). Score baixo = CPC mais alto + menor delivery.
- **Verificacao:** Executar skill `page-analyzer` para gerar EMQ score. Avaliar: (1) Velocidade de carregamento < 3s, (2) Mobile responsive, (3) Conteudo relevante ao ad, (4) Sem erros de console, (5) Checkout funcional, (6) SSL ativo. Score final deve ser >= 6.0 / 10.0.
- **Severidade:** BLOCK
- **Remediacao:** Se score < 6.0: identificar itens com nota mais baixa. Priorizar: velocidade (compressao de imagens, CDN), mobile (responsive design), erros (fix console errors). Re-testar apos correcoes. Nao lancar com score < 6.0 -- budget sera desperdicado.
- **Referencia:** `autonomy-tiers.yaml` -- `audit-campaign-pre-launch` (Auto) inclui verificacao de landing page

---

## Gate 4 -- Budget dentro dos limites de safety-rules.yaml

- **Descricao:** Budget configurado na campanha deve respeitar TODOS os limites definidos em `safety-rules.yaml`: max diario por tier de conta, rampagem se aplicavel, acumulo semanal.
- **Verificacao:** Comparar budget da campanha com limites aplicaveis: (1) Se conta < 90 dias: max R$50/dia (`budget_thresholds.new_account_max_daily`), (2) Se aumento sobre baseline: max +20%/dia (`budget_thresholds.max_daily_increase_pct`), (3) Se acumulo semanal: max +50% (`budget_thresholds.max_weekly_increase_pct`), (4) Se primeira campanha em rampagem: Day 1 = 25% do target (`rampagem.day1_pct`).
- **Severidade:** BLOCK
- **Remediacao:** Ajustar budget para dentro dos limites. Se budget desejado excede limites, criar plano de rampagem (Day 1/3/7) e registrar no WAL com aprovacao HITL. Nunca bypassar limites -- eles existem para prevenir ban.
- **Referencia:** `safety-rules.yaml` -- `budget_thresholds` (todas as sub-keys); `safety-rules.yaml` -- `rampagem`

---

## Gate 5 -- Audience exclusions configuradas

- **Descricao:** Campanhas cold DEVEM excluir compradores recentes (30 dias) para evitar gastar budget mostrando ads a quem ja comprou. Alem disso, evitar overlap excessivo entre audiences de campanhas ativas (canibalismo).
- **Verificacao:** Verificar na configuracao da campanha: (1) Custom audience de compradores 30d esta na lista de exclusoes de campanhas cold, (2) Overlap entre audiences de campanhas ativas < 60% (consultar `detect-audience-saturation`), (3) Audiences tem tamanho adequado (nao muito pequenas para delivery eficiente).
- **Severidade:** BLOCK
- **Remediacao:** Adicionar exclusao de compradores 30d nas campanhas cold. Se overlap > 60%, reestruturar audiences ou consolidar campanhas. Se audience muito pequena (< 100k para cold), expandir interesses ou usar LALs mais amplos.
- **Referencia:** `autonomy-tiers.yaml` -- `detect-audience-saturation` (Auto); `autonomy-tiers.yaml` -- `change-targeting` (HITL para alteracoes)

---

## Gate 6 -- Creatives passaram compliance check

- **Descricao:** TODOS os criativos (copy + imagem/video) devem passar pelo compliance gate antes de publicacao. Criativos rejeitados pela Meta podem flag a conta inteira. Compliance inclui: policies da Meta, claims verificaveis, disclaimers quando necessarios.
- **Verificacao:** Executar skill `ad-compliance-gate` (acao Auto: `audit-ad-compliance` no `autonomy-tiers.yaml`) para cada criativo da campanha. Verificar: (1) Texto nao viola policies (sem claims absolutos, sem before/after proibido), (2) Imagem/video dentro das guidelines (sem conteudo restrito), (3) Disclaimers presentes quando necessarios, (4) Landing page consistente com promessa do ad.
- **Severidade:** BLOCK
- **Remediacao:** Corrigir criativos que falharam. Claims nao verificaveis: remover ou adicionar disclaimer. Imagens proibidas: substituir. Inconsistencia com landing page: alinhar mensagem. Re-executar compliance check apos correcoes.
- **Referencia:** `autonomy-tiers.yaml` -- `audit-ad-compliance` (Auto, pre-requisito de `create-ad-api`); `autonomy-tiers.yaml` -- `approve-compliance-legal` (Human Only para aprovacao final)

---

## Gate 7 -- Action ledger completamente registrado

- **Descricao:** TODAS as acoes de criacao (campaign, adsets, ads) devem estar registradas no Write-Ahead Log (WAL) e no audit trail. O ledger e evidencia critica para appeals e auditoria. Gaps no ledger sao inaceitaveis.
- **Verificacao:** Consultar WAL em `workspace/businesses/{business}/ads/meta/wal/` para o mes atual. Verificar que cada entidade criada tem entry correspondente com: timestamp, action_id, agent, entity_type, entity_id, operation, params, approval, status. Confirmar que nao ha gaps nos timestamps.
- **Severidade:** BLOCK
- **Remediacao:** Se entries estao faltando, reconstruir a partir de logs do MCP e campaign state. Adicionar entries retroativamente com nota "[RECONSTRUCTED]". Se impossivel reconstruir, documentar gap com explicacao. Nao ativar campanha com ledger incompleto.
- **Referencia:** `safety-rules.yaml` -- `write_ahead_log: required`; `safety-rules.yaml` -- `additional_rules.audit_trail`

---

## Gate 8 -- Campaign state YAML atualizado

- **Descricao:** O arquivo de state local da campanha deve refletir EXATAMENTE o estado atual na plataforma. Inclui todos os IDs (campaign_id, adset_ids, ad_ids), configuracao inicial (budget, targeting, criativos), e timestamps de criacao.
- **Verificacao:** Ler campaign state YAML em `workspace/businesses/{business}/ads/meta/campaigns/`. Confirmar que contem: (1) campaign_id (retornado pela API), (2) Todos os adset_ids, (3) Todos os ad_ids, (4) Budget configurado, (5) Targeting snapshot, (6) Creative IDs, (7) Timestamp de criacao, (8) Status atual (PAUSED).
- **Severidade:** BLOCK
- **Remediacao:** Se state YAML esta incompleto, executar GET via API para obter dados faltantes. Atualizar state file com dados reais da plataforma. Se discrepancia entre state local e plataforma, plataforma e source of truth -- atualizar local.
- **Referencia:** `autonomy-tiers.yaml` -- `update-campaign-state` (Auto); `autonomy-tiers.yaml` -- `read-campaign-state` (Auto)

---

## Resumo do Gate

| # | Gate | Verificacao Principal | Severidade |
|---|------|----------------------|------------|
| 1 | Campaign PAUSED | API read-back via `get_campaigns` | BLOCK |
| 2 | Pixel/CAPI OK | Skill `tracking-audit` | BLOCK |
| 3 | EMQ >= 6.0 | Skill `page-analyzer` | BLOCK |
| 4 | Budget limits | Comparar com `safety-rules.yaml` | BLOCK |
| 5 | Audience exclusions | Exclusao compradores 30d + overlap < 60% | BLOCK |
| 6 | Compliance check | Skill `ad-compliance-gate` | BLOCK |
| 7 | Action ledger | WAL completo sem gaps | BLOCK |
| 8 | State YAML | Todos IDs + config registrados | BLOCK |

**Resultado:** TODOS 8 gates devem ser BLOCK-free para prosseguir com ativacao.
- 8/8 PASS: @fiscal libera para ativacao (HITL: `activate-campaign`)
- Qualquer FAIL: @fiscal BLOQUEIA ativacao e reporta items falhados

---

_Checklist: Launch Definition of Done | @aiox-ads | Enforced by @fiscal_
_Adapted from: ads-mcp DoD pattern | Enhanced with safety-rules.yaml integration_
