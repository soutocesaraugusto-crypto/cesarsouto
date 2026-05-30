# Task: Progress Check

```yaml
task:
  id: progress-check
  name: Verificação de Progresso
  agent: workspace-chief
  trigger: manual
  elicit: false
  commands:
    - "*progress-check {slug}"
  depends_on:
    - diagnose-business
```

## Descrição

Task derivada que compara o diagnóstico atual com o diagnóstico anterior do mesmo business. Mostra delta numérico por dimensão sem opinião: o que subiu, o que caiu, o que estagnou.

**Guardian:** COO (Chief Operating Officer)
**Input:** Diagnósticos em `docs/diagnostics/`
**Output:** `docs/diagnostics/YYYY-MM-DD-{slug}-progress.md`

## Workflow

### Passo 1: Encontrar Diagnósticos

```bash
# Buscar diagnósticos anteriores deste business
ls docs/diagnostics/*-{slug}-diagnostic.md | sort -r
```

Se apenas 1 diagnóstico existe: executar `diagnose-business` para gerar o atual, e comparar com o único existente.
Se 0 diagnósticos existem: abortar com "Execute *diagnose-business {slug} primeiro."

### Passo 2: Extrair Scores

Do diagnóstico mais recente e do anterior, extrair a tabela de resumo executivo:

```yaml
current:
  date: "2026-03-18"
  global_score: 72
  dimensions:
    customer: 68
    brand: 85
    offer: 62
    # ...

previous:
  date: "2026-03-04"
  global_score: 58
  dimensions:
    customer: 45
    brand: 80
    offer: 55
    # ...
```

### Passo 3: Calcular Deltas

```yaml
deltas:
  global: +14  # 72 - 58
  dimensions:
    customer: +23  # 68 - 45
    brand: +5      # 85 - 80
    offer: +7      # 62 - 55
    # ...
```

### Passo 4: Classificar Mudanças

| Delta | Classificação |
|-------|--------------|
| >= +15 | SALTO (melhoria significativa) |
| +5 a +14 | PROGRESSO |
| -4 a +4 | ESTÁVEL |
| -5 a -14 | REGRESSÃO |
| <= -15 | ALERTA (piora significativa) |

### Passo 5: Gerar Relatório

```markdown
# Progresso: {business_name}

**Período:** {data_anterior} → {data_atual} ({N} dias)
**Score Global:** {anterior} → {atual} ({delta})

---

## Delta por Dimensão

| Dimensão | Anterior | Atual | Delta | Status |
|----------|----------|-------|-------|--------|
| Customer | 45 | 68 | +23 | SALTO |
| Brand | 80 | 85 | +5 | PROGRESSO |
| Offer | 55 | 62 | +7 | PROGRESSO |
| ... | | | | |
| **Global** | **58** | **72** | **+14** | **PROGRESSO** |

---

## Destaques

**Maior melhoria:** {dimensão} (+{delta})
**Maior regressão:** {dimensão} ({delta}) *(ou "Nenhuma regressão")*
**Estagnado:** {dimensões sem mudança}

---

## Dimensões que Cruzaram Thresholds

| Dimensão | De | Para | Significado |
|----------|----|------|-------------|
| Customer | CRÍTICO (45) | ATENÇÃO (68) | Progrediu mas ainda não desbloqueia copy/traffic |
| Brand | ADEQUADO (80) | ADEQUADO (85) | Manteve nível |

---

*Gerado por COO (workspace-chief)*
```

## Regras

1. **Zero opinião.** Só números e classificação determinística.
2. **Sem "parabéns".** Delta positivo = PROGRESSO/SALTO. Sem celebração.
3. **Sem "preocupante".** Delta negativo = REGRESSÃO/ALERTA. Sem drama.
4. **Threshold crossing é fato.** "Passou de CRÍTICO para ATENÇÃO" = afirmação factual.

## Validação

- [ ] Pelo menos 2 diagnósticos disponíveis para comparação
- [ ] Deltas calculados corretamente
- [ ] Classificação seguindo tabela determinística
- [ ] Relatório gerado no path correto

---

*Task do Squad AIOX Workspace - COO Orchestrator*
*Versão: 1.0.0*
