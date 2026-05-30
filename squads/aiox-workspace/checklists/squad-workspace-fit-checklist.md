# Squad Workspace Fit Checklist

> **Owner:** COO (workspace-chief)
> **Purpose:** Decidir se um squad deve integrar com `workspace/` ou permanecer fora dele

---

## 1. Dependência estrutural

- [ ] O squad depende de artefato canônico de business?
- [ ] O squad depende de artefato canônico de produto?
- [ ] O squad depende de design system canônico?
- [ ] O squad consegue operar com qualidade sem `workspace/`?

## 2. Ownership de output

- [ ] O output primário do squad precisa viver canonicamente em `workspace/`?
- [ ] Existe namespace claro em `workspace/businesses/*` para esse output?
- [ ] O squad é owner legítimo desse namespace?
- [ ] Não há outro squad já canônico para o mesmo namespace?

## 3. Tipo de integração

- [ ] Se escreve artefato canônico, a classificação proposta é `workspace_first`.
- [ ] Se só consome contexto canônico sob gate do COO, a classificação proposta é `controlled_runtime_consumer`.
- [ ] Se só faz leitura para seeding/scaffolding/discovery, a classificação proposta é `read_only`.
- [ ] Se é ferramental/self-contained/genérico, a classificação proposta é `none`.

## 4. Governança do COO

- [ ] A decisão foi tomada pelo `COO`, não pelo squad consumidor.
- [ ] `workspace_first` e `controlled_runtime_consumer` foram marcados como consulting-only.
- [ ] A presença de `squads/aiox-workspace/` foi validada antes de aprovar níveis avançados.
- [ ] Não existe `read_write` residual.

## 5. Rollout

- [ ] A decisão final foi marcada como `approved`, `defer`, `reject` ou `consolidate`.
- [ ] O próximo passo foi definido.
- [ ] Se aprovado, há plano de bootstrap/validator/runtime.
- [ ] Se consolidado, o owner canônico foi registrado.

## 6. Shared Artifacts

- [ ] Foi avaliado se o artefato é compartilhado com outros squads.
- [ ] Artefatos compartilhados não ficaram presos em `squads/{slug}/templates/`.
- [ ] Quando compartilhado, o template foi direcionado para `workspace/_templates/`.
- [ ] O owner do artefato compartilhado ficou explícito no contrato do `COO`.
- [ ] O path de instância ficou classificado como `company/`, `products/{product}/narrative/` ou `franchise/narrative/`.

---

*Checklist do Squad AIOX Workspace - COO Orchestrator*
