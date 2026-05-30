# CLAUDE.md — Mastermind AIOX

## 1. Framework

Este repositório usa o **Synkra AIOX** (versão gratuita).

Consulte `.claude/CLAUDE.md` para as regras completas do framework.

---

## 2. Agentes disponíveis

Ative agentes com `@nome-do-agente`:

| Agente | Escopo |
|--------|--------|
| `@dev` | Implementação de código |
| `@qa` | Testes e qualidade |
| `@architect` | Arquitetura e design técnico |
| `@pm` | Product Management |
| `@po` | Product Owner |
| `@sm` | Scrum Master |
| `@analyst` | Pesquisa e análise |
| `@devops` | CI/CD, git push |

---

## 3. Squads disponíveis

| Squad | Ativação |
|-------|---------|
| `squads/aiox-workspace/` | Workspace e estrutura de negócio |
| `squads/aiox-ads/` | Tráfego pago (Meta Ads, Google Ads) |

---

## 4. Configuração inicial

Antes de usar, configure seu perfil de negócio:

```bash
# Crie sua pasta de negócio
mkdir -p workspace/businesses/{sua-empresa}

# Configure o perfil de tráfego
# Siga o onboarding: @ad-midas *setup
```

---

## 5. Git

- Commits convencionais: `feat:`, `fix:`, `chore:`, etc.
- Use `@devops` para push e criação de PRs.
