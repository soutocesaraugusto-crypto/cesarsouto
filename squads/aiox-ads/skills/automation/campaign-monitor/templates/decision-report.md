# Relatório de Decisões Autônomas

**Período:** {{start_date}} - {{end_date}}
**Gerado em:** {{generated_at}}
**Monitor Version:** 1.0.0

---

## Resumo Executivo

| Métrica              | Valor                      |
| -------------------- | -------------------------- |
| Total de Decisões    | {{summary.totalDecisions}} |
| Ações Executadas     | {{summary.executed}}       |
| Aguardando Aprovação | {{summary.pending}}        |
| Falhas               | {{summary.failed}}         |
| Rollbacks            | {{summary.rolledBack}}     |

### Performance por Expert

| Expert | Decisões | % do Total |
| ------ | -------- | ---------- |

{{#each summary.byExpert}}
| {{@key}} | {{this}} | {{percentage}}% |
{{/each}}

### Triggers Mais Frequentes

| #   | Regra | Ocorrências | Expert |
| --- | ----- | ----------- | ------ |

{{#each summary.topTriggers}}
| {{add @index 1}} | {{ruleId}} | {{count}} | {{expert}} |
{{/each}}

---

## Decisões Detalhadas

{{#each decisions}}

### {{id}}: {{trigger.rule_name}}

**Horário:** {{timestamp}}
**Urgência:** {{urgency}}
**Confiança:** {{decision.confidence}}%

#### Trigger

```yaml
Tipo: { { trigger.type } }
Métrica: { { trigger.metric } }
Valor Atual: { { trigger.current_value } }
Threshold: { { trigger.threshold } }
```

#### Decisão

```yaml
Ação: { { decision.type } }
Target: { { decision.target } }
```

#### Expert Source

```yaml
Nome: { { expert_source.name } }
Framework: { { expert_source.framework } }
Peso: { { expert_source.weight } }
```

#### Raciocínio

> {{decision.reasoning}}

#### Execução

```yaml
Status: {{execution.status}}
{{#if execution.result}}
Resultado: {{execution.result}}
{{/if}}
{{#if execution.error}}
Erro: {{execution.error}}
{{/if}}
```

{{#if agents_notified.length}}

#### Agentes Notificados

{{#each agents_notified}}

- {{this}}
  {{/each}}
  {{/if}}

---

{{/each}}

## Análise de Padrões

### Decisões por Urgência

```
CRITICAL: {{summary.byUrgency.critical}} ████████████████████
HIGH:     {{summary.byUrgency.high}}     ████████████████
MEDIUM:   {{summary.byUrgency.medium}}   ████████████
LOW:      {{summary.byUrgency.low}}      ████████
```

### Distribuição por Categoria

| Categoria      | Count                   | %                           |
| -------------- | ----------------------- | --------------------------- |
| Kill Rules     | {{categories.kill}}     | {{categories.killPct}}%     |
| Scale Rules    | {{categories.scale}}    | {{categories.scalePct}}%    |
| Creative Rules | {{categories.creative}} | {{categories.creativePct}}% |
| Alert Rules    | {{categories.alert}}    | {{categories.alertPct}}%    |
| Outros         | {{categories.other}}    | {{categories.otherPct}}%    |

---

## Impacto Financeiro

### Economia Estimada

| Ação                | Count             | Impacto Estimado                      |
| ------------------- | ----------------- | ------------------------------------- |
| Pausas Preventivas  | {{impact.pauses}} | R$ {{impact.pausesSaved}} economizado |
| Escalas Controladas | {{impact.scales}} | +{{impact.scalesGrowth}}% ROAS        |
| Alertas Respondidos | {{impact.alerts}} | Risco mitigado                        |

### ROI do Monitor

```
Investimento em Ads no Período: R$ {{roi.adSpend}}
Economia por Decisões Autônomas: R$ {{roi.savings}}
Crescimento por Escalas: R$ {{roi.growth}}

ROI do Sistema: {{roi.percentage}}%
```

---

## Recomendações

{{#if recommendations.length}}
{{#each recommendations}}

### {{add @index 1}}. {{title}}

**Baseado em:** {{pattern}}
**Expert:** {{expert}}

{{description}}

**Ação Sugerida:** {{action}}

{{/each}}
{{else}}
Nenhuma recomendação adicional no momento. Campanhas operando dentro dos parâmetros esperados.
{{/if}}

---

## Pendências

{{#if pendingApprovals.length}}

### Decisões Aguardando Aprovação

| ID  | Regra | Target | Queued At | Ação |
| --- | ----- | ------ | --------- | ---- |

{{#each pendingApprovals}}
| {{decision.id}} | {{decision.rule.name}} | {{decision.target}} | {{queuedAt}} | {{decision.rule.action.type}} |
{{/each}}

**Ação Necessária:** Revisar e aprovar/rejeitar decisões pendentes.
{{else}}
Nenhuma decisão pendente de aprovação.
{{/if}}

---

## Configuração Ativa

```yaml
Check Interval: {{config.checkIntervalMs}} ms
Active Hours: {{config.activeHours.start}}:00 - {{config.activeHours.end}}:00
Max Budget Change: {{config.maxBudgetChangePercent}}%
Approval Required Above: {{config.requireApprovalAbovePercent}}%
Cooldown Period: {{config.cooldownMs}} ms
Max Daily Actions: {{config.maxDailyActions}}
```

---

## Logs Técnicos

### Últimas Verificações

| Horário | Campanhas | Triggers | Ações | Status |
| ------- | --------- | -------- | ----- | ------ |

{{#each lastChecks}}
| {{timestamp}} | {{campaigns}} | {{triggers}} | {{actions}} | {{status}} |
{{/each}}

### Erros Registrados

{{#if errors.length}}

```
{{#each errors}}
[{{timestamp}}] {{message}}
{{/each}}
```

{{else}}
Nenhum erro registrado no período.
{{/if}}

---

## Glossário de Regras

| ID  | Nome | Expert | Descrição |
| --- | ---- | ------ | --------- |

{{#each rulesUsed}}
| {{id}} | {{name}} | {{expert}} | {{explanation}} |
{{/each}}

---

_Relatório gerado automaticamente pelo Campaign Monitor v1.0.0_
_Media Buyer Squad - AIOS Synkra_
