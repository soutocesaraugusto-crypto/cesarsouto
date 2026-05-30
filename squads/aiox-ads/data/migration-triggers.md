# Migration Triggers: YAML to Database

> **Propósito:** Tornar a decisão de migrar de YAML flat files para database (Supabase PostgreSQL + RLS) uma decisão **data-driven**, não opinion-driven. Agentes e operadores consultam este documento quando preocupações de escala surgirem.
>
> **Status atual:** YAML é a camada de persistência correta para o estágio v5 da squad. Nenhum trigger ativo.
>
> **Fonte:** Roundtable Data Engineer Analysis (`outputs/enhance/aiox-ads-optimization/03b-roundtable-data.md`, Seção 1.3)
>
> **Story:** SAIOX-ADS-V5-2.3
> **Criado em:** 2026-03-17

---

## Como usar este documento

1. Quando um agente ou operador perceber sintomas de escala (lentidão, contexto estourando, conflitos de escrita), consultar os triggers abaixo
2. Se **qualquer** trigger atingir seu threshold, iniciar planejamento de migração para o artefato afetado
3. A migração é **por artefato** -- não é tudo ou nada. campaign-state pode migrar antes do ledger, por exemplo
4. A stack recomendada é consistente: Supabase PostgreSQL + RLS em todos os cenários

---

## Trigger 1: Volume de Campanhas Ativas

**Descrição:** Mais de 20 campanhas ativas simultaneamente por business. O pattern de "fan-out read" (Glob + Read N arquivos) começa a consumir contexto demais para agregação cross-campaign. Com 20 campanhas a 3 KB cada, são 60 KB (~15.000 tokens) por operação de agregação -- funcional, mas no limite. Acima disso, a janela de contexto do agente fica comprometida para a tarefa principal.

| Campo | Valor |
|-------|-------|
| **Métrica de monitoramento** | Contagem de arquivos `campaign-state.yaml` com `status.lifecycle: active` por business |
| **Como medir** | `Glob workspace/businesses/{business}/ads/campaigns/meta/*/campaign-state.yaml` + contar onde `lifecycle: active` |
| **Threshold** | > 20 campanhas ativas simultâneas por business |
| **Ação recomendada** | Migrar `campaign-state.yaml` para tabela `campaign_states` no Supabase PostgreSQL |
| **Stack sugerida** | Supabase PostgreSQL + RLS (row-level security por business, policy: `business_slug = auth.jwt()->>'business'`) |
| **Schema da tabela** | Colunas espelhando a estrutura do YAML: `campaign_id` (PK), `business_slug`, `lifecycle`, `autonomy_tier`, `health`, `budget_daily`, `perf_7d` (JSONB), `perf_30d` (JSONB), `memory` (JSONB), `targeting` (JSONB), `creatives` (JSONB), `updated_at` |
| **Benefício pós-migração** | `SELECT * FROM campaign_states WHERE business_slug = 'bilhon' AND lifecycle = 'active'` -- 1 query substitui N file reads |

---

## Trigger 2: Tamanho do Action Ledger

**Descrição:** Action ledger excede 1000 entradas por campanha. Mesmo com rotação mensal, campanhas intensivas (10 ações/dia) atingem ~300 entradas/mês. Se a rotação falhar ou o período de análise exigir múltiplos meses, o volume de dados para uma única campanha se torna pesado para Read tool + filtragem em memória. Acima de 1000 entradas, queries como "todas as ações de budget change nos últimos 90 dias" se tornam impraticáveis com YAML.

| Campo | Valor |
|-------|-------|
| **Métrica de monitoramento** | Campo `summary.total_entries` no header do `action-ledger.yaml` |
| **Como medir** | Read `action-ledger.yaml` e verificar `meta.summary.total_entries` (ou contar entries se summary não existir) |
| **Threshold** | > 1000 entradas por campanha (incluindo arquivos em `_archive/`) |
| **Ação recomendada** | Migrar ledger para tabela `action_logs` no Supabase PostgreSQL |
| **Stack sugerida** | Supabase PostgreSQL + RLS (policy por `business_slug`), particionamento por `created_at` (mensal) |
| **Schema da tabela** | `id` (PK, serial), `campaign_id` (FK), `business_slug`, `timestamp`, `agent`, `action`, `tier`, `approval`, `params` (JSONB), `result` (JSONB), `context` (TEXT), índices em `campaign_id`, `agent`, `timestamp` |
| **Benefício pós-migração** | `SELECT * FROM action_logs WHERE campaign_id = $1 AND agent = 'ad-midas' AND timestamp >= now() - interval '7 days'` -- filtragem nativa sem carregar todo o ledger |

---

## Trigger 3: Queries Cross-Campaign em Tempo Real

**Descrição:** Necessidade de queries cross-campaign em tempo real para JOINs, agregações e dashboards. Com YAML, consultar "qual o CPA médio de todas as campanhas ativas de um business" requer: Glob para encontrar os arquivos, Read de cada um, agregação manual em memória. Isso é O(N) em file reads. Com database, é uma query SQL trivial com GROUP BY. Quando essa necessidade surgir como requisito operacional (não eventual), database é obrigatório.

| Campo | Valor |
|-------|-------|
| **Métrica de monitoramento** | Frequência de requests por cross-campaign analytics (reports, dashboards, comparativos) |
| **Como medir** | Contar quantas vezes por semana um agente ou operador precisa agregar dados de múltiplas campanhas |
| **Threshold** | Necessidade recorrente (> 3x/semana) de JOINs cross-campaign ou cross-business |
| **Ação recomendada** | Migrar campaign-state e action-logs para database. Criar views materializadas para agregações comuns |
| **Stack sugerida** | Supabase PostgreSQL + RLS. Views: `v_business_performance_7d`, `v_campaign_comparison`, `v_agent_activity_summary`. Opcional: Supabase Realtime para dashboards live |
| **Schema adicional** | View `v_business_performance_7d`: JOIN `campaign_states` com `action_logs`, agrupado por `business_slug`, com métricas calculadas (total_spend, avg_cpa, avg_roas, active_count) |
| **Benefício pós-migração** | De N file reads + agregação manual para 1 `SELECT * FROM v_business_performance_7d WHERE business_slug = $1` |

---

## Trigger 4: Escrita Concorrente

**Descrição:** Múltiplos usuários ou agentes editando o mesmo `campaign-state.yaml` simultaneamente. No modo conversacional padrão do Claude Code, isso não ocorre (1 agente por vez). Porém, cenários como: dois terminais Claude Code no mesmo repo, cron via n8n triggering agente enquanto outro roda, ou sub-agentes via agent tool, criam risco real de race condition. O soft lock com TTL (campo `_lock`) é uma solução paliativa -- não substitui transações ACID.

| Campo | Valor |
|-------|-------|
| **Métrica de monitoramento** | Ocorrências de conflito de lock (agente encontra `_lock.owner != null` ao tentar escrever) |
| **Como medir** | Grep nos action-ledgers por entries com `action: lock_conflict` ou mensagens de erro de escrita concorrente |
| **Threshold** | Qualquer ocorrência de conflito de escrita simultânea confirmada |
| **Ação recomendada** | Migrar campaign-state para database com transações ACID e row-level locking |
| **Stack sugerida** | Supabase PostgreSQL + RLS + `SELECT ... FOR UPDATE` para locking row-level. Eliminar o campo `_lock` do YAML |
| **Schema da tabela** | Mesmo schema do Trigger 1, com adição de `locked_by` (TEXT, nullable) e `locked_at` (TIMESTAMPTZ, nullable) como colunas para lock explícito se necessário, embora `FOR UPDATE` já resolva a maioria dos cenários |
| **Benefício pós-migração** | Garantia ACID: read-then-write atômico, sem race conditions, sem locks órfãos. Suporta N agentes/terminais concorrentes |

---

## Trigger 5: Histórico Longo com Granularidade Diária

**Descrição:** Necessidade de histórico superior a 12 meses com granularidade diária para análise de tendências, sazonalidade e benchmarking interno. O design atual do `campaign-state.yaml` usa rolling window (7d/30d) -- **intencionalmente** não armazena histórico diário. Se a operação evoluir para precisar de queries como "qual era o CPA dia a dia durante a Black Friday 2025 vs 2026", os dados simplesmente não existem no YAML (foram sobrescritos pelo rolling window). Database com time-series é o único caminho.

| Campo | Valor |
|-------|-------|
| **Métrica de monitoramento** | Requests por dados históricos que não existem no rolling window (dados mais antigos que 30 dias com granularidade diária) |
| **Como medir** | Contar quantas vezes um agente ou operador solicita análise de tendência que requer dados diários > 30 dias |
| **Threshold** | Necessidade de histórico > 12 meses com granularidade diária |
| **Ação recomendada** | Criar tabela `daily_metrics` como time-series para armazenar snapshot diário de cada campanha |
| **Stack sugerida** | Supabase PostgreSQL + RLS. Opcional: extensão `pg_partman` para particionamento automático por mês. Alternativa avançada: TimescaleDB se disponível no Supabase |
| **Schema da tabela** | `id` (PK), `campaign_id` (FK), `business_slug`, `date` (DATE), `impressions`, `clicks`, `conversions`, `spend`, `cpc`, `ctr`, `cpa`, `roas`, `created_at`. PK composta: (`campaign_id`, `date`). Particionamento mensal por `date` |
| **Benefício pós-migração** | `SELECT date, cpa FROM daily_metrics WHERE campaign_id = $1 AND date BETWEEN '2025-11-01' AND '2026-11-30' ORDER BY date` -- análise de sazonalidade, YoY comparison, trend detection com window functions |

---

## Resumo dos Triggers

| # | Trigger | Threshold | Artefato afetado | Tabela destino |
|---|---------|-----------|------------------|----------------|
| 1 | Campanhas ativas > 20 | > 20 simultâneas/business | `campaign-state.yaml` | `campaign_states` |
| 2 | Ledger > 1000 entradas | > 1000 por campanha | `action-ledger.yaml` | `action_logs` |
| 3 | Queries cross-campaign recorrentes | > 3x/semana | Ambos | `campaign_states` + `action_logs` + views |
| 4 | Escrita concorrente detectada | Qualquer ocorrência | `campaign-state.yaml` | `campaign_states` (ACID) |
| 5 | Histórico > 12 meses diário | Necessidade confirmada | Novo artefato | `daily_metrics` (time-series) |

---

## Notas de Implementação

**Princípios da migração:**
- A migração é **incremental** -- migre apenas o artefato cujo trigger foi atingido
- Os YAML files podem coexistir com database durante transição (dual-write temporário)
- RLS garante isolamento por business desde o dia 1 -- não postergar configuração de segurança
- Manter o `schema_version` nos YAML files facilita a migração (parser sabe qual estrutura esperar)

**O que NÃO é trigger:**
- "Seria legal ter um dashboard" -- dashboards podem ser construídos com fan-out read para volumes baixos
- "Database é mais profissional" -- a decisão é técnica, não estética
- "Todo mundo usa banco" -- YAML flat files versionados por git são a escolha correta enquanto os triggers não forem atingidos

**Revisão periódica:** Avaliar estes triggers a cada **sprint review** ou quando um novo business for onboardado. O onboarding de um business com 30+ campanhas existentes pode ativar o Trigger 1 imediatamente.
