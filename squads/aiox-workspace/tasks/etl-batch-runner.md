# Task: ETL Deep Pass Batch Runner

```yaml
task:
  id: etl-batch-runner
  name: ETL Deep Pass Batch Runner
  agent: workspace-chief
  elicit: false
  output_format: yaml
```

## Descricao

Executor em lote do ETL Deep Pass para multiplos businesses. Itera sobre o mapa de negocios, executa `*etl-deep-pass` para cada um, e gera relatorio consolidado. Suporta filtro por slugs, concorrencia configuravel, e resume de execucao interrompida.

## Prerequisites

- `squads/aiox-workspace/data/imersao-business-map.yaml` populado.
- Ao menos 1 business com workspace criado.
- Bootstrap e scaffold executados para cada business a ser processado.

## Usage

```
*etl-batch-run                                          # todos os pendentes
*etl-batch-run --slugs "andre_franco,bruno_kosminsky"   # subset especifico
*etl-batch-run --concurrency 3                          # limite de paralelismo
*etl-batch-run --resume                                 # retomar de batch-status.yaml
*etl-batch-run --force                                  # reprocessar mesmo >= 90%
```

## Execution Flow

### Fase 1: Carregar e filtrar businesses

1. Ler `squads/aiox-workspace/data/imersao-business-map.yaml`.
2. Aplicar filtro `--slugs` se fornecido (CSV de slugs).
3. Para cada business, ler `evidence/completeness-manifest.yaml` se existir.
4. Pular businesses com completude >= 90% (a menos que `--force` ativo).
5. Gerar lista final de execucao ordenada por completude (menor primeiro).

### Fase 2: Criar batch status

1. Criar/atualizar `workspace/businesses/_batch/etl-deep-pass-batch-status.yaml`:
   ```yaml
   batch:
     id: "batch-{timestamp}"
     started_at: "{ISO timestamp}"
     concurrency: 1
     total: 0
     businesses:
       - slug: "example_slug"
         status: PENDING  # PENDING | IN_PROGRESS | COMPLETE | FAILED | SKIPPED
         baseline: 0
         final: 0
         delta: 0
         error: null
   ```
2. Se `--resume`: ler batch-status existente, filtrar PENDING e FAILED, continuar.

### Fase 3: Executar pipeline por business

1. Para cada business na lista:
   - Atualizar status para `IN_PROGRESS`.
   - Executar `*etl-deep-pass {slug}`.
   - Em caso de sucesso: atualizar status para `COMPLETE`, registrar `final` e `delta`.
   - Em caso de falha: atualizar status para `FAILED`, registrar `error`, continuar com proximo.
2. Atualizar `batch-status.yaml` apos cada execucao.

### Fase 4: Paralelismo (quando concurrency > 1)

1. Usar subagents para execucao paralela.
2. Limite maximo definido por `--concurrency` (default: 1 = sequencial).
3. Cada subagent executa `*etl-deep-pass` independente.
4. Resultados consolidados no batch-status apos conclusao de cada subagent.

### Fase 5: Batch report

1. Ler batch-status final.
2. Calcular metricas agregadas:
   - Total processados / pulados / falhados.
   - Delta medio de completude.
   - Tempo total de execucao.
3. Exibir report formatado:
   - Tabela com slug, status, baseline, final, delta.
   - Businesses que falharam com motivo.
   - Recomendacao para reprocessar falhados com `--resume`.

## Acceptance Criteria

1. Todos os businesses filtrados processados ou marcados com status final.
2. `batch-status.yaml` preciso com status de cada business.
3. Falha em 1 business nao interrompe o batch (isolamento de erros).
4. `--resume` retoma corretamente de onde parou.
5. Businesses >= 90% pulados por default (respeitando `--force`).
6. Report final exibido com metricas agregadas.

## Outputs

| Arquivo | Descricao |
|---------|-----------|
| `_batch/etl-deep-pass-batch-status.yaml` | Status de cada business no batch |
| Outputs de `*etl-deep-pass` por business | Conforme task etl-deep-pass |

---

*Task do Squad AIOX Workspace - COO Orchestrator*
