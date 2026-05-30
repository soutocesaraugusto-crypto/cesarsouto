# Digest Report Template

## Metadata

| Campo | Valor |
|-------|-------|
| **Tipo** | Digest (Semanal) |
| **Gerado por** | @performance-analyst, @ad-midas |
| **Tier** | Auto (generate-digest-report) |
| **Tempo de leitura** | 3 minutos |
| **Frequencia** | Semanal (automatico, segunda-feira) |

---

## Formato

```markdown
# Digest -- Semana {week_number} -- {campaign_name}

## Performance (7 dias)

| Dia | Spend | CPA | ROAS | CTR | Conversoes |
|-----|-------|-----|------|-----|------------|
| Seg | R$X   | R$X | X.Xx | X.X%| X          |
| Ter | R$X   | R$X | X.Xx | X.X%| X          |
| Qua | R$X   | R$X | X.Xx | X.X%| X          |
| Qui | R$X   | R$X | X.Xx | X.X%| X          |
| Sex | R$X   | R$X | X.Xx | X.X%| X          |
| Sab | R$X   | R$X | X.Xx | X.X%| X          |
| Dom | R$X   | R$X | X.Xx | X.X%| X          |
| **Total** | **R$X** | **R$X** | **X.Xx** | **X.X%** | **X** |

## Top 3 Insights

1. **{insight_title}** -- {data_evidence}
2. **{insight_title}** -- {data_evidence}
3. **{insight_title}** -- {data_evidence}

## Recomendacoes

- [ ] {recomendacao_1} [Tier: {Auto/HITL/Human}]
- [ ] {recomendacao_2} [Tier: {Auto/HITL/Human}]
- [x] {recomendacao_ja_executada} [Tier: Auto -- executado {data}]

## Decision Log (semana)

| Data | Decisao | Tier | Resultado |
|------|---------|------|-----------|
| {date} | {decision} | {Auto/HITL/Human} | {outcome} |

## Creative Fatigue Status

| Criativo | Frequency | CTR Trend | Hook Rate | Status |
|----------|-----------|-----------|-----------|--------|
| {name}   | {freq}    | {trend}   | {rate}    | {OK/FADIGA/CRITICO} |

## Prioridades Proxima Semana

1. {prioridade_1}
2. {prioridade_2}
3. {prioridade_3}
```

---

## Regras de Preenchimento

### Secao: Performance (7 dias)

| Campo | Fonte | Notas |
|-------|-------|-------|
| Spend | campaign-state.yaml (daily snapshots) | Soma diaria de todas as campanhas ativas |
| CPA | campaign-state.yaml | Media ponderada por spend do dia |
| ROAS | campaign-state.yaml | Receita total / Spend total do dia |
| CTR | campaign-state.yaml | Clicks / Impressions do dia |
| Conversoes | campaign-state.yaml | Total de conversoes do dia |

Linha **Total** usa: soma para Spend e Conversoes, media ponderada para CPA/ROAS/CTR.

### Secao: Top 3 Insights

Insights DEVEM ser data-backed. Cada insight segue o formato:

```
**{O que aconteceu}** -- {numero(s) que comprovam}
```

**Exemplos validos:**
- **Criativo #4 (video curto) teve CTR 2.3x acima da media** -- 3.1% vs 1.4% media do adset
- **Audiencia LAL 1% esgotou** -- frequency 4.2, CTR caiu 35% em 3 dias
- **CPA de quinta-feira 40% acima** -- R$56 vs R$40 media; possivel concorrencia sazonal

**Exemplos invalidos (sem dados):**
- "A campanha foi bem essa semana" (vago, sem numero)
- "Recomendo escalar" (acao, nao insight)

Regra de selecao: priorizar insights ACTIONABLE (que levam a uma decisao) sobre insights descritivos.

### Secao: Recomendacoes

Cada recomendacao DEVE incluir:
1. Descricao clara da acao
2. Tag de tier entre colchetes: `[Tier: Auto]`, `[Tier: HITL]`, `[Tier: Human]`
3. Se ja executada (Auto), usar checkbox marcado `[x]` e indicar data

Fonte de tiers: `autonomy-tiers.yaml`. Agente consulta o action_id correspondente para determinar o tier correto.

**Exemplos:**
```
- [ ] Escalar criativo #4 (+20% budget no adset) [Tier: HITL]
- [ ] Criar audiencia LAL 3% a partir da LAL 1% saturada [Tier: HITL]
- [x] Pausar adset "INT Fashion" (CPA 3.2x target por 48h) [Tier: Auto -- executado 15/mar]
- [ ] Definir estrategia de criativos para proxima quinzena [Tier: Human]
```

### Secao: Decision Log

Fonte primaria: `action-ledger` (workspace/businesses/{business}/ads/meta/audit/).

Incluir TODAS as decisoes da semana, independente do tier. Formato:

| Campo | Regra |
|-------|-------|
| Data | Data da decisao (DD/MMM) |
| Decisao | Descricao curta da acao tomada |
| Tier | Auto, HITL, ou Human |
| Resultado | "OK", "Revertido", "Pendente", ou resultado mensuravel |

### Secao: Creative Fatigue Status

Fonte: `detect-creative-fatigue` (Auto tier em autonomy-tiers.yaml).

| Status | Criterio |
|--------|----------|
| OK | Frequency < 2.5 E CTR estavel E Hook Rate > 20% |
| FADIGA | Frequency 2.5-3.5 OU CTR drop 20-30% OU Hook Rate 15-20% |
| CRITICO | Frequency > 3.5 OU CTR drop > 30% OU Hook Rate < 15% |

Se NENHUM criativo ativo: mostrar "Nenhum criativo ativo no periodo".

Se TODOS OK: mostrar tabela com nota "Todos os criativos dentro dos parametros".

### Secao: Prioridades Proxima Semana

Maximo 3 prioridades. Derivadas de:
1. Recomendacoes pendentes (nao executadas) desta semana
2. Acoes de rampagem programadas (safety-rules.yaml)
3. Testes A/B em andamento que precisam de decisao
4. Criativos com status FADIGA/CRITICO que precisam de swap

---

## Exemplo Concreto Completo

```markdown
# Digest -- Semana 11 -- Promo Verao

## Performance (7 dias)

| Dia | Spend | CPA | ROAS | CTR | Conversoes |
|-----|-------|-----|------|-----|------------|
| Seg | R$460 | R$36 | 3.5x | 2.1% | 13 |
| Ter | R$485 | R$34 | 3.6x | 2.3% | 14 |
| Qua | R$470 | R$39 | 3.2x | 2.0% | 12 |
| Qui | R$510 | R$56 | 2.3x | 1.8% | 9 |
| Sex | R$480 | R$38 | 3.3x | 2.2% | 13 |
| Sab | R$490 | R$35 | 3.6x | 2.4% | 14 |
| Dom | R$465 | R$33 | 3.8x | 2.5% | 14 |
| **Total** | **R$3.360** | **R$38** | **3.3x** | **2.2%** | **89** |

## Top 3 Insights

1. **Criativo #4 (video curto) teve CTR 2.3x acima da media** -- 3.1% vs 1.4% media do adset; responsavel por 40% das conversoes
2. **Audiencia LAL 1% esgotou** -- frequency atingiu 4.2, CTR caiu 35% em 3 dias consecutivos (seg-qua)
3. **CPA de quinta-feira 40% acima** -- R$56 vs R$40 media; correlacao com Black Friday antecipada de concorrentes

## Recomendacoes

- [ ] Escalar criativo #4 (+20% budget no adset) [Tier: HITL]
- [ ] Criar audiencia LAL 3% a partir da LAL 1% saturada [Tier: HITL]
- [x] Pausar adset "INT Fashion" (CPA 3.2x target por 48h) [Tier: Auto -- executado 14/mar]
- [ ] Investigar spike de quinta-feira (analise de auction insights) [Tier: Auto]

## Decision Log (semana)

| Data | Decisao | Tier | Resultado |
|------|---------|------|-----------|
| 11/mar | Coletar metricas diarias (rotina) | Auto | OK |
| 13/mar | Detectar fadiga LAL 1% | Auto | Alerta gerado |
| 14/mar | Pausar adset "INT Fashion" | Auto | CPA voltou para target |
| 14/mar | Recomendar swap criativo Banner v1 | HITL | Pendente |

## Creative Fatigue Status

| Criativo | Frequency | CTR Trend | Hook Rate | Status |
|----------|-----------|-----------|-----------|--------|
| Video Curto v2 | 1.8 | +12% | 28% | OK |
| Carrossel Depoimentos | 2.3 | = | 22% | OK |
| Banner Original | 3.8 | -35% | 12% | CRITICO |
| Static CTA v3 | 2.1 | +5% | 25% | OK |

## Prioridades Proxima Semana

1. Resolver fadiga do Banner Original (swap ou refresh de criativo)
2. Executar scale do Video Curto v2 apos aprovacao HITL
3. Criar e testar audiencia LAL 3% para substituir LAL 1% saturada
```

---

## Integracao

| Sistema | Conexao |
|---------|---------|
| autonomy-tiers.yaml | `generate-digest-report` (Auto tier) |
| campaign-state.yaml | Fonte de dados primaria (daily snapshots) |
| action-ledger | Fonte do Decision Log |
| pulse-report.md | Pulses diarios alimentam a tabela de performance |
| safety-rules.yaml | Thresholds de fadiga, budget, CPA |
| performance-report.md | Deep Dive sob demanda usa mesmos dados com analise estendida |

---

## Restricoes

- Maximo 6 secoes (as listadas acima). Sem secoes extras
- Top 3 insights: exatamente 3. Nem mais, nem menos. Se semana foi tranquila, os 3 insights podem ser confirmacoes positivas ("ROAS manteve acima do target por 7 dias consecutivos")
- Recomendacoes: maximo 5. Priorizar por impacto
- Decision Log: incluir TODAS as decisoes, mesmo as Auto que foram silenciosas
- Prioridades: maximo 3. Focadas e actionable
- Sem emojis. Dados falam por si
- Uma campanha por digest. Se multiplas campanhas, gerar um digest por campanha ou um consolidado com tabela por campanha

---

_Template: Digest Report | @performance-analyst | Auto tier_
