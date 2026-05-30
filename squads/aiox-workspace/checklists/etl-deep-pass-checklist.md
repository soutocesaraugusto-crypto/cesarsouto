# ETL Deep Pass Quality Gate Checklist

> **Owner:** COO (workspace-chief)
> **Squad:** AIOX Workspace
> **Applies to:** Each business after full ETL Deep Pass execution
> **Reference:** etl-deep-pass-pipeline.yaml

---

## 1. Source Coverage (Fontes Processadas)

- [ ] `perfil` processado (obrigatorio)
- [ ] `formulario` processado ou documentado como `missing`
- [ ] `call_vendas` processado ou documentado como `missing`
- [ ] `instalacao` processado ou documentado como `missing`
- [ ] `source-registry.yaml` lista todas as fontes com status (`processed`, `skipped`, `missing`)

## 2. Company Templates — Layer 1

- [ ] `company-profile.yaml` >= 80% completude
- [ ] `founder-dna.yaml` >= 70% completude
- [ ] `icp.yaml` >= 60% completude
- [ ] `brand.yaml` >= 60% completude
- [ ] `credentials.yaml` >= 50% completude
- [ ] `offerbook.yaml` indice presente e valido
- [ ] `pricing-strategy.yaml` ao menos 1 plano documentado
- [ ] `team-structure.yaml` ao menos fundador registrado

## 3. Web Scraping — Layer 2

- [ ] Website scrapeado OU `SKIPPED_NO_URL` documentado no envelope
- [ ] Se scrapeado: ao menos 2 hex colors extraidos
- [ ] Se scrapeado: font family identificada
- [ ] Se scrapeado: meta tags (title, description) extraidos
- [ ] Skip documentado com razao se Layer 2 pulada

## 4. Web Research — Layer 3

- [ ] Ao menos 3 pesquisas executadas (midia, social, app/UGC)
- [ ] Todas as claims possuem source URL verificavel
- [ ] Confianca tagueada (ALTA/MEDIA/BAIXA) em cada claim
- [ ] Nenhum dado fabricado (compliance zero-invention)
- [ ] Ao menos 1 fonte verificada encontrada

## 5. Generated Artifacts — Layer 4

- [ ] `brandbook.yaml` gerado com identidade consolidada
- [ ] `strategic-positioning.yaml` gerado com posicionamento
- [ ] `proof.yaml` atualizado com evidencias consolidadas
- [ ] `testimonials.yaml` atualizado (se UGC encontrado)
- [ ] `narrative.yaml` gerado com historia do fundador
- [ ] `movement.yaml` gerado com movimento/causa

## 6. Evidence & Tracking

- [ ] `completeness-manifest.yaml` atualizado com metricas finais
- [ ] `source-registry.yaml` consolidado com todas as fontes
- [ ] `etl-run-envelope.yaml` contem registro de cada layer
- [ ] Delta de completude >= 25pp (ou justificativa se abaixo)

## 7. Structural Integrity

- [ ] Nenhum placeholder `TODO`, `TBD`, `FIXME` nos YAMLs gerados
- [ ] `offerbook.yaml` indice aponta para produtos existentes
- [ ] Todos os arquivos YAML parseiam sem erro de sintaxe
- [ ] Nenhuma credencial ou dado sensivel exposto

---

## Scoring

| Secao | Peso | Score |
|-------|------|-------|
| 1. Source Coverage | 15% | __/100 |
| 2. Company Templates (L1) | 25% | __/100 |
| 3. Web Scraping (L2) | 10% | __/100 |
| 4. Web Research (L3) | 15% | __/100 |
| 5. Generated Artifacts (L4) | 20% | __/100 |
| 6. Evidence & Tracking | 10% | __/100 |
| 7. Structural Integrity | 5% | __/100 |

**Total Score:** __/100

**Gate Decision:**
- >= 75: PASS
- 50-74: CONCERNS (revisar gaps antes de prosseguir)
- < 50: FAIL (reprocessar layers com falha)

---

*Checklist do Squad AIOX Workspace - COO Orchestrator*
