---
name: aiox-workspace
description: |
  Squad executivo de gestão de workspace, businesses, diagnósticos e operações.
  Ativa o workspace-chief (Operations, COO orquestrador), que coordena os executivos
  do squad (CTO, CIO, CMO, CAIO, vision) para estruturar o workspace, organizar
  empresas/produtos, conduzir elicitação profunda e rodar diagnósticos executivos
  (autoridade, negócio, funil, oferta, operações, retenção, movimento). Suporta
  múltiplos businesses dentro de um único workspace.
user-invocable: true
version: "1.1.0"
---

# /aiox-workspace — Squad Executivo de Workspace (workspace-chief)

## Propósito

Estruturar e operar o `workspace`: organizar businesses e produtos, conduzir elicitação
profunda, gerar documentos de referência e rodar diagnósticos executivos. O ponto de
entrada é o **workspace-chief** (COO / Operations), orquestrador do squad.

## Como ativar

Esta skill ativa a squad `squads/aiox-workspace/` (`entry_agent: workspace-chief`).
Ao ser invocada:

1. **Leia integralmente** `squads/aiox-workspace/agents/workspace-chief.md` e **adote a
   persona** do `workspace-chief` (Operations / COO). Toda a configuração está nesse arquivo.
2. **Siga as `activation-instructions`** desse agente, incluindo o preflight de workspace
   (bootstrap/essentials) antes de qualquer elicitação, e o greeting determinístico via
   `scripts/generate-aiox-workspace-greeting.cjs` (com fallback inline se o script falhar).
   Em seguida **PARE**, aguardando o pedido do usuário.
3. O chief coordena os executivos do squad: CTO, CIO, CMO, CAIO e os agentes de visão
   (`vision-chief`, `vision-strategist`).
4. Comandos principais (prefixo `*`): `*bootstrap`, `*workspace-preflight`,
   `*workspace-context`, `*add-business`, `*setup-workspace`, `*status`, `*help`.

## Regras

- **Workspace-first:** valide bootstrap, templates e contexto canônico em `workspace/`
  antes de elicitar. Read/write paths definidos em `squads/aiox-workspace/squad.yaml`.
- **Multi-business:** tudo é organizado por `workspace/businesses/{slug}/`; nunca
  assuma um negócio específico.
- **Sem invenção:** campo sem resposta confirmada deve ser marcado para preencher depois,
  nunca chutado.

## Arquivos da squad

```
squads/aiox-workspace/
├── agents/            # workspace-chief (entry) + executivos (cto, cio, cmo, caio, vision)
├── manifests/         # diagnose-* e exec-* (manifest-router.yaml)
├── tasks/ workflows/ checklists/ data/ examples/ specs/ outputs/ scripts/
└── squad.yaml         # metadados (entry_agent: workspace-chief)
```
