---
task: Scale Campaign
responsavel: '@media-strategist'
responsavel_type: agent
atomic_layer: task
status: active
squad: media-buyer-squad
version: 1.0.0
Entrada: |
  - campaign_id: Campanha a escalar
  - current_budget: Budget atual
  - target_budget: Budget desejado
  - performance_data: Métricas atuais
Saida: |
  - scaling_plan: Plano de escala
  - risk_assessment: Avaliação de riscos
  - timeline: Cronograma de execução
Checklist:
  - '[ ] Validar readiness para escala'
  - '[ ] Escolher método de escala'
  - '[ ] Calcular timeline'
  - '[ ] Definir pontos de monitoramento'
  - '[ ] Executar escala'
  - '[ ] Monitorar resultados'
---

# Scale Campaign Task

## Objetivo

Escalar campanhas lucrativas de forma sustentável sem quebrar performance.

## Pré-requisitos (via @performance-analyst \*scale-check)

- [ ] ROAS consistente por 3+ dias
- [ ] CPA estável ou diminuindo
- [ ] Volume > 50 conversões/semana
- [ ] Frequência < 2
- [ ] Criativo não fadigado

## Métodos de Escala

### 1. Escala Vertical

**Quando usar:** Winner comprovado, audiência grande

**Regra:** Máximo 20% a cada 48h

```
Dia 0: R$100/dia (baseline)
Dia 2: R$120/dia (+20%)
Dia 4: R$144/dia (+20%)
Dia 6: R$173/dia (+20%)
Dia 8: R$207/dia (+20%)
...
```

**Monitorar:** Se CPA subir >20%, pausar escala

### 2. Escala Horizontal

**Quando usar:** Winner comprovado, testar novas audiências

**Processo:**

1. Duplicar adset vencedor
2. Manter mesmo criativo
3. Mudar apenas a audiência
4. Mesmo budget inicial

**Audiências para teste:**

- LAL 1% → LAL 2% → LAL 3%
- Interesses similares
- Broad (sem segmentação)

### 3. Múltiplas Estruturas

**Quando usar:** Escala agressiva (>R$10k/dia)

**Processo:**

1. Criar campanha paralela
2. Mesma oferta, mesmo criativo
3. Audiências diferentes
4. Budget separado

**Evita:** Conflito de leilão na mesma campanha

## Plano de Escala

```yaml
scaling_plan:
  current_state:
    daily_budget: R$___
    roas: ___x
    cpa: R$___

  target_state:
    daily_budget: R$___
    timeline: ___ dias
    method: vertical|horizontal|multiple

  milestones:
    - day: 2
      budget: R$___
      check: 'CPA estável?'
    - day: 4
      budget: R$___
      check: 'ROAS mantido?'
    - day: 7
      budget: R$___
      check: 'Volume escalou?'

  abort_conditions:
    - 'CPA > meta * 1.5'
    - 'ROAS < meta * 0.7'
    - 'Frequência > 3'
```

## Riscos e Mitigação

| Risco                | Indicador        | Mitigação                      |
| -------------------- | ---------------- | ------------------------------ |
| CPA dispara          | +30% em 24h      | Pausar escala, voltar budget   |
| Audiência satura     | Frequência > 2.5 | Escala horizontal              |
| Criativo fadiga      | CTR cai >20%     | @creative-analyst novo brief   |
| Learning phase reset | 0 conversões/dia | Aguardar 3 dias antes de mudar |

## Monitoramento

→ **@performance-analyst** via `*report daily`

Check diário durante escala:

- ROAS vs baseline
- CPA vs baseline
- Frequência
- Delivery (gastos vs budget)

---

_Task: Scale Campaign | @media-strategist_
