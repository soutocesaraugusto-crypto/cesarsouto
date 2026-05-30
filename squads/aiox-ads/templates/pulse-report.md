# Pulse Report Template

## Metadata

| Campo | Valor |
|-------|-------|
| **Tipo** | Pulse (Diario) |
| **Gerado por** | @performance-analyst, @ad-midas |
| **Tier** | Auto (generate-pulse-report) |
| **Tempo de leitura** | 15 segundos |
| **Frequencia** | Diario (automatico) |

---

## Formato

```
# Pulse -- {campaign_name} -- {date}
Spend: R${spend} | CPA: R${cpa} ({trend} vs 7d avg) | ROAS: {roas}
Top Winner: {best_ad_name} (CTR {ctr}%)
Alert: {alert_or_none}
Action: {auto_action_taken_or_none} | Tier: {Auto/HITL/Human}
```

---

## Regras de Preenchimento

### Campos obrigatorios

| Campo | Fonte | Formato |
|-------|-------|---------|
| `campaign_name` | campaign-state.yaml | Nome da campanha ativa principal |
| `date` | Timestamp de geracao | DD/MMM (ex: 17/mar) |
| `spend` | API: collect-campaign-metrics | Valor em reais, sem centavos se > R$10 |
| `cpa` | API: collect-campaign-metrics | Valor em reais com centavos |
| `trend` | Calculo local: CPA hoje vs media 7d | Formato: "+12%" ou "-5%" ou "=" |
| `roas` | API: collect-campaign-metrics | Formato: "3.2x" |
| `best_ad_name` | API: collect-ad-metrics | Ad com melhor CTR no dia |
| `ctr` | API: collect-ad-metrics | Percentual com 1 casa decimal |
| `alert` | Deteccao de anomalia local | Texto curto ou "Nenhum" |
| `auto_action_taken` | WAL + action-ledger | Acao executada ou "Nenhuma" |
| `tier` | autonomy-tiers.yaml | Auto, HITL, ou Human |

### Logica de trend

```
Se CPA < media_7d * 0.95 → trend = "-X%" (bom)
Se CPA > media_7d * 1.05 → trend = "+X%" (atencao)
Se CPA entre 0.95x e 1.05x → trend = "=" (estavel)
```

### Logica de alert

| Condicao | Alert |
|----------|-------|
| CPA > 2x target por 6h+ | "CPA {cpa} acima de 2x target -- avaliar kill" |
| Spend > 130% do budget diario | "Spend {spend} ultrapassou budget diario" |
| Conversoes = 0 por 6h+ | "Zero conversoes nas ultimas 6h -- verificar tracking" |
| Creative frequency > 3 | "Fadiga: {creative_name} com freq {freq}" |
| Token expira em < 7 dias | "Token expira em {dias} dias -- renovar" |
| Nenhuma anomalia | "Nenhum" |

Se multiplos alerts: mostrar o de maior severidade. Demais ficam no digest semanal.

### Logica de action

| Condicao | Action |
|----------|--------|
| Acao Auto executada no dia | "{descricao_da_acao}" |
| Acao HITL pendente | "Pendente: {descricao} -- aguarda aprovacao" |
| Acao Human recomendada | "Recomendacao: {descricao}" |
| Nenhuma acao no dia | "Nenhuma" |

---

## Exemplos Concretos

### Dia normal (sem alertas)

```
# Pulse -- Promo Verao -- 17/mar
Spend: R$480 | CPA: R$38 (-5% vs 7d avg) | ROAS: 3.2x
Top Winner: Video Curto v2 (CTR 2.8%)
Alert: Nenhum
Action: Nenhuma | Tier: Auto
```

### Dia com alerta de CPA

```
# Pulse -- Lancamento Curso -- 17/mar
Spend: R$320 | CPA: R$95 (+42% vs 7d avg) | ROAS: 1.1x
Top Winner: Carrossel Depoimentos (CTR 1.9%)
Alert: CPA R$95 acima de 2x target -- avaliar kill
Action: Pendente: pausar adset "INT Broad" -- aguarda aprovacao | Tier: HITL
```

### Dia com acao automatica

```
# Pulse -- Trafego Blog -- 17/mar
Spend: R$150 | CPA: R$12 (= vs 7d avg) | ROAS: 4.5x
Top Winner: Static CTA v3 (CTR 3.1%)
Alert: Fadiga: Banner Original com freq 3.8
Action: Detectada fadiga criativa -- swap recomendado | Tier: HITL
```

---

## Integracao

| Sistema | Conexao |
|---------|---------|
| autonomy-tiers.yaml | `generate-pulse-report` (Auto tier) |
| campaign-state.yaml | Fonte de dados primaria (metricas coletadas) |
| action-ledger | Fonte de acoes executadas no dia |
| safety-rules.yaml | Thresholds de alerta (budget, CPA) |
| digest-report.md | Pulses da semana alimentam o digest semanal |

---

## Restricoes

- Maximo 5 linhas. Sem excecao. Se nao cabe em 5 linhas, nao e um Pulse
- Sem emojis. Erros sao serios, numeros sao claros
- Sem tabelas. Pulse e texto corrido com pipe separators
- Uma campanha por pulse. Se multiplas campanhas ativas, gerar um pulse por campanha
- Linguagem direta. "CPA acima de 2x target" e nao "o custo por aquisicao apresentou elevacao significativa"

---

_Template: Pulse Report | @performance-analyst | Auto tier_
