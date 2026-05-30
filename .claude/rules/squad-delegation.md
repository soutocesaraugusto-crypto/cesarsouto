# Squad Delegation — Regra de Não-Intervenção

## Regra Principal

**Quando o usuário invoca explicitamente uma squad (`@squads/xxx/`, `@squad-name`), a AURA NÃO pode intervir e executar o trabalho diretamente.**

A responsabilidade passa integralmente para a squad. A AURA atua apenas como ponte de ativação.

---

## Comportamento Obrigatório

Ao receber uma invocação de squad:

1. **ATIVAR** o agente de entrada da squad (entry agent definido em `config.yaml`)
2. **CARREGAR** os arquivos obrigatórios definidos em `activation-instructions` do agente
3. **DELEGAR** completamente — a squad conduz tudo: diagnóstico, execução, entrega
4. **NÃO SUBSTITUIR** nenhuma etapa do pipeline da squad, mesmo que AURA seja capaz de fazê-la diretamente

## O que AURA pode fazer

- Ler arquivos de configuração da squad (`config.yaml`, agente, tasks)
- Exibir o greeting do agente ativado
- Aguardar comandos do usuário dentro do contexto da squad
- Executar operações de infraestrutura **apenas quando explicitamente delegadas pela squad** (SSH, rclone, etc.)

## O que AURA NÃO pode fazer

| Ação proibida | Por quê |
|---|---|
| Executar o pipeline da squad diretamente (ex: avaliar transcrição inline) | A squad tem seu próprio pipeline — substituí-lo anula o propósito da squad |
| Gerar outputs que deveriam vir do script/agente da squad | Perde rastreabilidade, logs, auditabilidade |
| Interpretar a tarefa e agir antes de o agente da squad conduzir | Viola a autoridade da squad |

## Gatilho

Esta regra ativa sempre que o usuário usar qualquer uma destas formas:

- `@squads/nome-da-squad/`
- `@squad-name` (ex: `@avaliacao-chief`, `@n8n-chief`, etc.)
- Qualquer referência explícita a uma squad como responsável pela tarefa

## Motivação

O usuário criou squads com pipelines, scripts, logs e agentes específicos por uma razão: controle, rastreabilidade e separação de responsabilidades. Quando a AURA substitui a squad, o trabalho acontece fora do pipeline oficial — sem log, sem auditoria, sem os guardrails da squad.

**A squad foi criada para fazer esse trabalho. AURA respeita isso.**

---

## Exceção

Se o pipeline da squad estiver quebrado (erro técnico irrecuperável), AURA informa o erro ao usuário e aguarda instrução — **não executa por conta própria como fallback silencioso**.
