# Setup Collaborator Forks

> Task ID: devops-setup-collaborator-forks
> Agent: @devops (Gage)
> Version: 2.0.0

---

## Description

Configura o sistema de fork e colaboração para um mentorado. O mentorado informa seus colaboradores e o @devops executa o `setup-fork.sh` que já existe no repo, garantindo que tudo funcione.

O sistema é composto por 3 arquivos (já presentes no repo):
- **`setup-fork.sh`** — Script que roda UMA vez: cria fork, adiciona colaboradores como admin, registra no upstream
- **`.github/workflows/sync-forks.yml`** — GitHub Action de sync bidirecional (push upstream→forks no push, pull forks→upstream a cada 15min via PR)
- **`collaborators.yml`** — Registro de forks (alimentado automaticamente pelo setup-fork.sh)

## Prerequisites

- `gh` CLI autenticado (mentorado precisa ter rodado `gh auth login`)
- Acesso write ao repo upstream (AIOXsquad/{repo})
- Secret `AIOXSQUAD_PAT` setado no repo upstream

## Workflow

### Interactive Elicitation

**elicit: true — HALT obrigatório. Usar AskUserQuestion tool e aguardar resposta antes de prosseguir.**

**Pergunta única ao mentorado:**

> Quais são os usernames do GitHub dos seus colaboradores?
> (separados por espaço — ex: `amigo1 amigo2 amigo3`)
> Pode deixar vazio se quiser só o fork sem colaboradores.

**CRITICAL:** Use a tool `AskUserQuestion` para fazer esta pergunta. NÃO prossiga para os Steps sem ter recebido a resposta do usuário. O agente DEVE parar aqui e esperar o input.

**Após receber resposta:** armazene os usernames em `$COLLABORATORS` e prossiga para Step 1.

### Steps

1. **Verificar pré-requisitos**
   ```bash
   # gh autenticado?
   gh auth status
   # Repo tem os 3 arquivos?
   ls setup-fork.sh .github/workflows/sync-forks.yml collaborators.yml
   ```
   - Se `gh` não autenticado → instruir: `gh auth login`
   - Se arquivos faltando → reportar erro, repo pode não ter sido propagado

2. **Executar setup-fork.sh com os colaboradores informados**
   ```bash
   chmod +x setup-fork.sh
   ./setup-fork.sh colaborador1 colaborador2 colaborador3
   ```
   O script faz tudo automaticamente:
   - Detecta upstream (AIOXsquad/{repo})
   - Cria fork no GitHub do mentorado
   - Adiciona colaboradores com permissão push
   - Registra o fork no `collaborators.yml` do upstream

3. **Verificar resultado**
   - Fork existe? `gh api repos/{user}/{repo}`
   - Colaboradores adicionados? Checar output do script
   - Registrado no upstream? `collaborators.yml` atualizado

## Output

O próprio `setup-fork.sh` já exibe o resultado formatado:

```
════════════════════════════════════════
  ✅ PRONTO!

  Seu fork: https://github.com/{user}/{repo}

  Colaboradores convidados:
    • amigo1 (vai receber email do GitHub)
    • amigo2 (vai receber email do GitHub)

  Seus colaboradores só precisam:
    git clone https://github.com/{user}/{repo}

  Atualizações do AIOX chegam automaticamente.
════════════════════════════════════════
```

## Success Criteria

- [ ] Fork criado no GitHub do mentorado
- [ ] Colaboradores adicionados com permissão push
- [ ] Fork registrado no `collaborators.yml` do upstream
- [ ] Sync automático funcional (push do upstream chega no fork)

## Error Handling

- **`gh: command not found`**: Instruir instalação do GitHub CLI
- **`gh: not logged in`**: Instruir `gh auth login`
- **Fork já existe**: Script detecta e pula — OK
- **Colaborador não encontrado**: Script reporta warning, continua com os demais
- **Sem permissão no upstream**: Mentorado precisa de write access ao repo AIOXsquad

## Security Considerations

- `setup-fork.sh` usa `gh api` autenticado — não expõe tokens
- Colaboradores recebem permissão `push` (não admin) no fork
- O registro no upstream é feito via commit direto (mentorado tem write access)

## Examples

### Example 1: Mentorado com 2 colaboradores
```bash
./setup-fork.sh joao maria
# → Fork criado, joao e maria convidados, registrado no upstream
```

### Example 2: Mentorado sem colaboradores (só fork)
```bash
./setup-fork.sh
# → Fork criado, registrado no upstream, sem colaboradores
```

### Example 3: Colaborador clonando o fork
```bash
# Depois que o mentorado rodou o setup, o colaborador só faz:
git clone https://github.com/{mentorado}/{repo}
# Pronto. Atualizações do AIOX chegam automaticamente via sync-forks.yml
```

## Notes

- Testado e validado com o Ítalo — fluxo completo funcionando
- O `collaborators.yml` é alimentado automaticamente — não precisa editar manualmente
- A Action `sync-forks.yml` roda a cada 15min (pull) e em cada push to main (push)
- Para propagação batch (admin), ver sessão anterior no ~/dash-aiox
