# Synkra AIOX Development Rules for Claude Code

You are working with Synkra AIOX, an AI-Orchestrated System for Full Stack Development.

<!-- AIOX-MANAGED-START: core-framework -->
## Core Framework Understanding

Synkra AIOX is a meta-framework that orchestrates AI agents to handle complex development workflows. Always recognize and work within this architecture.
<!-- AIOX-MANAGED-END: core-framework -->

<!-- AIOX-MANAGED-START: constitution -->
## Constitution

O AIOX possui uma **Constitution formal** com princípios inegociáveis e gates automáticos.

**Documento completo:** `.aiox-core/constitution.md`

**Princípios fundamentais:**

| Artigo | Princípio | Severidade |
|--------|-----------|------------|
| I | CLI First | NON-NEGOTIABLE |
| II | Agent Authority | NON-NEGOTIABLE |
| III | Story-Driven Development | MUST |
| IV | No Invention | MUST |
| V | Quality First | MUST |
| VI | Absolute Imports | SHOULD |

**Gates automáticos bloqueiam violações.** Consulte a Constitution para detalhes completos.
<!-- AIOX-MANAGED-END: constitution -->

<!-- AIOX-MANAGED-START: sistema-de-agentes -->
## Sistema de Agentes

### Ativação de Agentes
Use `@agent-name` ou `/AIOX:agents:agent-name`:

| Agente | Persona | Escopo Principal |
|--------|---------|------------------|
| `@dev` | Dex | Implementação de código |
| `@qa` | Quinn | Testes e qualidade |
| `@architect` | Aria | Arquitetura e design técnico |
| `@pm` | Morgan | Product Management |
| `@po` | Pax | Product Owner, stories/epics |
| `@sm` | River | Scrum Master |
| `@analyst` | Alex | Pesquisa e análise |
| `@data-engineer` | Dara | Database design |
| `@ux-design-expert` | Uma | UX/UI design |
| `@devops` | Gage | CI/CD, git push (EXCLUSIVO) |

### Comandos de Agentes
Use prefixo `*` para comandos:
- `*help` - Mostrar comandos disponíveis
- `*create-story` - Criar story de desenvolvimento
- `*task {name}` - Executar task específica
- `*exit` - Sair do modo agente
<!-- AIOX-MANAGED-END: sistema-de-agentes -->

<!-- AIOX-MANAGED-START: agent-system -->
## Agent System

### Agent Activation
- Agents are activated with @agent-name syntax: @dev, @qa, @architect, @pm, @po, @sm, @analyst
- The master agent is activated with @aiox-master
- Agent commands use the * prefix: *help, *create-story, *task, *exit

### Agent Context
When an agent is active:
- Follow that agent's specific persona and expertise
- Use the agent's designated workflow patterns
- Maintain the agent's perspective throughout the interaction
<!-- AIOX-MANAGED-END: agent-system -->

## Development Methodology

### Story-Driven Development
1. **Work from stories** - All development starts with a story in `docs/stories/`
2. **Update progress** - Mark checkboxes as tasks complete: [ ] → [x]
3. **Track changes** - Maintain the File List section in the story
4. **Follow criteria** - Implement exactly what the acceptance criteria specify

### Code Standards
- Write clean, self-documenting code
- Follow existing patterns in the codebase
- Include comprehensive error handling
- Add unit tests for all new functionality
- Use TypeScript/JavaScript best practices

### Testing Requirements
- Run all tests before marking tasks complete
- Ensure linting passes: `npm run lint`
- Verify type checking: `npm run typecheck`
- Add tests for new features
- Test edge cases and error scenarios

<!-- AIOX-MANAGED-START: framework-structure -->
## AIOX Framework Structure

```
aiox-core/
├── agents/         # Agent persona definitions (YAML/Markdown)
├── tasks/          # Executable task workflows
├── workflows/      # Multi-step workflow definitions
├── templates/      # Document and code templates
├── checklists/     # Validation and review checklists
└── rules/          # Framework rules and patterns

docs/
├── stories/        # Development stories (numbered)
├── prd/            # Product requirement documents
├── architecture/   # System architecture documentation
└── guides/         # User and developer guides
```
<!-- AIOX-MANAGED-END: framework-structure -->

<!-- AIOX-MANAGED-START: framework-boundary -->
## Framework vs Project Boundary

O AIOX usa um modelo de 4 camadas (L1-L4) para separar artefatos do framework e do projeto. Deny rules em `.claude/settings.json` reforçam isso deterministicamente.

| Camada | Mutabilidade | Paths | Notas |
|--------|-------------|-------|-------|
| **L1** Framework Core | NEVER modify | `.aiox-core/core/`, `.aiox-core/constitution.md`, `bin/aiox.js`, `bin/aiox-init.js` | Protegido por deny rules |
| **L2** Framework Templates | NEVER modify | `.aiox-core/development/tasks/`, `.aiox-core/development/templates/`, `.aiox-core/development/checklists/`, `.aiox-core/development/workflows/`, `.aiox-core/infrastructure/` | Extend-only |
| **L3** Project Config | Mutable (exceptions) | `.aiox-core/data/`, `agents/*/MEMORY.md`, `core-config.yaml` | Allow rules permitem |
| **L4** Project Runtime | ALWAYS modify | `docs/stories/`, `packages/`, `squads/`, `tests/` | Trabalho do projeto |

**Toggle:** `core-config.yaml` → `boundary.frameworkProtection: true/false` controla se deny rules são ativas (default: true para projetos, false para contribuidores do framework).

> **Referência formal:** `.claude/settings.json` (deny/allow rules), `.claude/rules/agent-authority.md`
<!-- AIOX-MANAGED-END: framework-boundary -->

<!-- AIOX-MANAGED-START: rules-system -->
## Rules System

O AIOX carrega regras contextuais de `.claude/rules/` automaticamente. Regras com frontmatter `paths:` só carregam quando arquivos correspondentes são editados.

| Rule File | Description |
|-----------|-------------|
| `agent-authority.md` | Agent delegation matrix and exclusive operations |
| `agent-handoff.md` | Agent switch compaction protocol for context optimization |
| `agent-memory-imports.md` | Agent memory lifecycle and CLAUDE.md ownership |
| `coderabbit-integration.md` | Automated code review integration rules |
| `ids-principles.md` | Incremental Development System principles |
| `mcp-usage.md` | MCP server usage rules and tool selection priority |
| `story-lifecycle.md` | Story status transitions and quality gates |
| `workflow-execution.md` | 4 primary workflows (SDC, QA Loop, Spec Pipeline, Brownfield) |

> **Diretório:** `.claude/rules/` — rules são carregadas automaticamente pelo Claude Code quando relevantes.
<!-- AIOX-MANAGED-END: rules-system -->

<!-- AIOX-MANAGED-START: code-intelligence -->
## Code Intelligence

O AIOX possui um sistema de code intelligence opcional que enriquece operações com dados de análise de código.

| Status | Descrição | Comportamento |
|--------|-----------|---------------|
| **Configured** | Provider ativo e funcional | Enrichment completo disponível |
| **Fallback** | Provider indisponível | Sistema opera normalmente sem enrichment — graceful degradation |
| **Disabled** | Nenhum provider configurado | Funcionalidade de code-intel ignorada silenciosamente |

**Graceful Fallback:** Code intelligence é sempre opcional. `isCodeIntelAvailable()` verifica disponibilidade antes de qualquer operação. Se indisponível, o sistema retorna o resultado base sem modificação — nunca falha.

**Diagnóstico:** `aiox doctor` inclui check de code-intel provider status.

> **Referência:** `.aiox-core/core/code-intel/` — provider interface, enricher, client
<!-- AIOX-MANAGED-END: code-intelligence -->

<!-- AIOX-MANAGED-START: graph-dashboard -->
## Graph Dashboard

O CLI `aiox graph` visualiza dependências, estatísticas de entidades e status de providers.

### Comandos

```bash
aiox graph --deps                        # Dependency tree (ASCII)
aiox graph --deps --format=json          # Output como JSON
aiox graph --deps --format=html          # Interactive HTML (abre browser)
aiox graph --deps --format=mermaid       # Mermaid diagram
aiox graph --deps --format=dot           # DOT format (Graphviz)
aiox graph --deps --watch                # Live mode com auto-refresh
aiox graph --deps --watch --interval=10  # Refresh a cada 10 segundos
aiox graph --stats                       # Entity stats e cache metrics
```

**Formatos de saída:** ascii (default), json, dot, mermaid, html

> **Referência:** `.aiox-core/core/graph-dashboard/` — CLI, renderers, data sources
<!-- AIOX-MANAGED-END: graph-dashboard -->

## Workflow Execution

### Task Execution Pattern
1. Read the complete task/workflow definition
2. Understand all elicitation points
3. Execute steps sequentially
4. Handle errors gracefully
5. Provide clear feedback

### Interactive Workflows
- Workflows with `elicit: true` require user input
- Present options clearly
- Validate user responses
- Provide helpful defaults

## Arquitetura Frontend — Regras Inegociáveis

### Princípio: Frontend captura intenções, backend controla tudo

O frontend **NUNCA** controla lógica de negócio, autenticação, autorização ou fluxo de dados. Ele apenas:
1. **Captura intenções** do usuário (cliques, formulários, inputs)
2. **Envia** essas intenções ao backend via API
3. **Reage** ao resultado que o backend retorna (sucesso, erro, dados)

### NUNCA faça no frontend:
- Lógica de autenticação ou validação de acesso
- Chamadas diretas a serviços externos (OpenAI, Stripe, banco de dados, etc.)
- Decisões de negócio ("se o usuário pode ver X")
- Processamento de dados sensíveis

### JAMAIS coloque no frontend:
- Chaves de API (`OPENAI_API_KEY`, `STRIPE_SECRET_KEY`, etc.)
- Senhas, tokens de serviço ou secrets de qualquer natureza
- Credenciais de banco de dados
- Qualquer variável de ambiente sensível — mesmo prefixada com `NEXT_PUBLIC_` ou `VITE_`

> **Regra de ouro:** Se vazar para o browser, vaza para o mundo. Chaves ficam exclusivamente no backend/servidor.

### Padrão correto:
```
Usuário clica → Frontend envia intent ao backend → Backend valida, processa e responde → Frontend exibe resultado
```

### Padrão proibido:
```
Frontend chama API externa diretamente com chave hardcoded ou exposta ← BLOQUEADO
```

## Best Practices

### When implementing features:
- Check existing patterns first
- Reuse components and utilities
- Follow naming conventions
- Keep functions focused and testable
- Document complex logic

### When working with agents:
- Respect agent boundaries
- Use appropriate agent for each task
- Follow agent communication patterns
- Maintain agent context

### When handling errors:
```javascript
try {
  // Operation
} catch (error) {
  console.error(`Error in ${operation}:`, error);
  // Provide helpful error message
  throw new Error(`Failed to ${operation}: ${error.message}`);
}
```

## Git & GitHub Integration

### Commit Conventions
- Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, etc.
- Reference story ID: `feat: implement IDE detection [Story 2.1]`
- Keep commits atomic and focused

### GitHub CLI Usage
- Ensure authenticated: `gh auth status`
- Use for PR creation: `gh pr create`
- Check org access: `gh api user/memberships`

<!-- AIOX-MANAGED-START: aiox-patterns -->
## AIOX-Specific Patterns

### Working with Templates
```javascript
const template = await loadTemplate('template-name');
const rendered = await renderTemplate(template, context);
```

### Agent Command Handling
```javascript
if (command.startsWith('*')) {
  const agentCommand = command.substring(1);
  await executeAgentCommand(agentCommand, args);
}
```

### Story Updates
```javascript
// Update story progress
const story = await loadStory(storyId);
story.updateTask(taskId, { status: 'completed' });
await story.save();
```
<!-- AIOX-MANAGED-END: aiox-patterns -->

## Environment Setup

### Required Tools
- Node.js 18+
- GitHub CLI
- Git
- Your preferred package manager (npm/yarn/pnpm)

### Configuration Files
- `.aiox/config.yaml` - Framework configuration
- `.env` - Environment variables
- `aiox.config.js` - Project-specific settings

<!-- AIOX-MANAGED-START: common-commands -->
## Common Commands

### AIOX Master Commands
- `*help` - Show available commands
- `*create-story` - Create new story
- `*task {name}` - Execute specific task
- `*workflow {name}` - Run workflow

### Development Commands
- `npm run dev` - Start development
- `npm test` - Run tests
- `npm run lint` - Check code style
- `npm run build` - Build project
<!-- AIOX-MANAGED-END: common-commands -->

## Debugging

### Enable Debug Mode
```bash
export AIOX_DEBUG=true
```

### View Agent Logs
```bash
tail -f .aiox/logs/agent.log
```

### Trace Workflow Execution
```bash
npm run trace -- workflow-name
```

## Claude Code Specific Configuration

### Performance Optimization
- Prefer batched tool calls when possible for better performance
- Use parallel execution for independent operations
- Cache frequently accessed data in memory during sessions

### Tool Usage Guidelines
- Always use the Grep tool for searching, never `grep` or `rg` in bash
- Use the Task tool for complex multi-step operations
- Batch file reads/writes when processing multiple files
- Prefer editing existing files over creating new ones

### Session Management
- Track story progress throughout the session
- Update checkboxes immediately after completing tasks
- Maintain context of the current story being worked on
- Save important state before long-running operations

### Error Recovery
- Always provide recovery suggestions for failures
- Include error context in messages to user
- Suggest rollback procedures when appropriate
- Document any manual fixes required

### Testing Strategy
- Run tests incrementally during development
- Always verify lint and typecheck before marking complete
- Test edge cases for each new feature
- Document test scenarios in story files

### Documentation
- Update relevant docs when changing functionality
- Include code examples in documentation
- Keep README synchronized with actual behavior
- Document breaking changes prominently

---
*Synkra AIOX Claude Code Configuration v2.0*

<!-- BEGIN onboard-aliado:contexto-do-negocio -->
## Contexto do Negócio (gerado pelo onboard-aliado)

Este repositório tem o contexto do negócio **Dra. Lauriane Silva** salvo em
`workspace/businesses/lauriane_silva/`. **REGRA OBRIGATÓRIA para qualquer sessão:**

1. **Antes de construir QUALQUER coisa personalizada** (copy, landing page, anúncio,
   e-mail, post, design, proposta, roteiro, etc.), **leia primeiro** estes arquivos:
   - `workspace/businesses/lauriane_silva/company/company-profile.yaml` — quem é, missão, posicionamento
   - `workspace/businesses/lauriane_silva/company/founder-dna.yaml` — história e voz do fundador
   - `workspace/businesses/lauriane_silva/brand/brand-foundation.yaml` — manifesto, valores, crenças, voz, posicionamento
   - `workspace/businesses/lauriane_silva/company/icp.yaml` — cliente ideal (dor, desejo, objeções)
   - `workspace/businesses/lauriane_silva/products/` — ofertas e produtos
   - `workspace/businesses/lauriane_silva/market/research.yaml` — concorrentes, preços, voz do cliente
   - `workspace/businesses/lauriane_silva/design-system/` — cores, tipografia, identidade visual
     > **Cores exatas da marca (HEX):** Red Jam `#3F1817` · Red Wine `#562120` · Cream `#DDD7CA`
     > Fontes: **Cormorant Garamond** (display/títulos) + **Inter** (corpo/UI)
2. **NUNCA pergunte ao usuário** algo que já esteja nesses arquivos. Use o que está salvo.
3. Se um campo estiver como `FILL_LATER`, aí sim pergunte — e **salve a resposta** no
   arquivo correspondente, para não perguntar de novo no futuro.
4. Todo material criado deve respeitar o **design system** e a **voz** definidos acima.
5. Mapa rápido dos arquivos: veja `workspace/businesses/lauriane_silva/INDEX.md`.
<!-- END onboard-aliado:contexto-do-negocio -->

<!-- BEGIN inself-assessment-app -->
## App — Perfil Comportamental Inself

### Descrição
Assessment de perfil comportamental completo em arquivo HTML único, sem backend.
**Produto:** Perfil Comportamental Inself® — por Dra. Lauriane Silva · Mentoria & Performance

### URLs
| Ambiente | URL |
|----------|-----|
| **App (produção)** | `https://perfil.dralaurianesilva.com.br` |
| **Admin (gerar links)** | `https://perfil.dralaurianesilva.com.br/admin.html` |
| **Repositório** | `https://github.com/Dralaurianesilva/mastermind-dralaurianesilva-` |
| **GitHub Pages (fallback)** | `https://dralaurianesilva.github.io/mastermind-dralaurianesilva-/` |

### Arquivos do App
```
docs/
├── index.html       ← App principal (~1350 linhas)
├── admin.html       ← Gerador de links únicos (senha: inself2024)
├── logo-white.png   ← Logo Inself versão branca (fundo escuro)
├── logo-wine.png    ← Logo Inself versão vinho (fundo claro)
└── CNAME            ← Domínio customizado: perfil.dralaurianesilva.com.br
```

### Stack Técnica
- **HTML/CSS/JS puro** — zero backend, zero dependências locais
- **CDNs:** Google Fonts (Cormorant Garamond + Inter) · Chart.js 4 · EmailJS browser v4
- **Deploy:** GitHub Pages (branch `master`, pasta `/docs`)
- **Dados:** EmailJS → envio automático para `lauriane20@gmail.com` ao concluir

### EmailJS — Credenciais Configuradas
```javascript
serviceId:        'service_agommze'
templateId:       'template_ni3nh2s'   // relatório completo
ratingTemplateId: 'template_g3pc2tc'   // avaliações com estrelas
publicKey:        'w5Pje4POkIn5zzHPD'
```

**Template relatório** (`template_ni3nh2s`) — variáveis:
`name`, `email`, `respondent_name`, `respondent_email`, `respondent_phone`, `assessment_date`, `disc_profile`, `disc_d`, `disc_i`, `disc_s`, `disc_c`, `mbti_type`, `mbti_name`, `mbti_details`, `top_value`, `all_values`, `leadership`, `all_leadership`, `identity_score`, `capacity_score`, `abundance_score`

**Template avaliação** (`template_g3pc2tc`) — variáveis:
`name`, `email`, `respondent_name`, `respondent_email`, `respondent_phone`, `assessment_date`, `rating_stars`, `rating_message`

### Contatos da Mentora no App
```javascript
mentorWhatsApp: '5547988571458'
mentorEmail:    'lauriane20@gmail.com'
instagramUrl:   'https://www.instagram.com/dralauriane/'
```

### 8 Dimensões Avaliadas
1. **DISC** (William M. Marston) — 16 grupos, ranking 1→4 por toque
2. **MBTI Myers-Briggs** — 16 questões, 4 dimensões (E/I, N/S, T/F, J/P), 16 tipos
3. **Hierarquia de Valores** (Eduard Spranger) — 12 questões Likert 1-5
4. **Estilo de Liderança** — 10 situações, 4 estilos (Executivo/Motivador/Orientador/Sistemático)
5. **Crenças de Identidade** — 8 questões Likert (algumas reversas)
6. **Crenças de Capacidade** — 8 questões Likert (algumas reversas)
7. **Merecimento de Abundância** — 10 questões Likert (algumas reversas)
8. **Plano de Ação Inself** — gerado automaticamente pelo perfil

### Sistema de Link Único (Token)
- **Sem token na URL** → app abre normalmente
- **Token válido** (`?t=TOKEN`) → abre e marca como usado ao concluir
- **Token inválido/expirado/usado** → tela "Acesso Restrito" com botão WhatsApp
- **Gerar tokens:** acessar `admin.html`, senha `inself2024`
- **Formato do token:** `[8chars_random]_[expiry_base36]`

### Diagnóstico Financeiro (Crenças)
Score combinado `(abund×0.5 + ident×0.25 + capac×0.25)`:
- **≥ 80** → Mentalidade Financeira Alinhada (verde)
- **65–79** → Em Desenvolvimento — Zona de Atenção (âmbar)
- **< 65** → Bloqueio Financeiro — Reprogramação Necessária (vinho)

### LocalStorage Keys
- `inself_assessment_v1` — estado do assessment em progresso
- `inself_used_tokens` — tokens já utilizados (evita reuso)
- `inself_admin_log` — histórico de links gerados (admin.html)

### Como Atualizar e Publicar
1. Editar `docs/index.html` ou `docs/admin.html`
2. `git add docs/ && git commit -m "..."` 
3. `git push origin master`
4. GitHub Pages atualiza automaticamente em ~30 segundos

### Design System Aplicado
- **Cores:** Red Jam `#3F1817` · Red Wine `#562120` · Cream `#DDD7CA` · BG `#FAFAF8` · Surface `#F2EDE4`
- **Fontes:** Cormorant Garamond (títulos/display) + Inter (corpo/UI)
- **Seções numeradas:** I, II, III... (sem emojis — design profissional)
- **Logo:** arquivos PNG reais em `docs/logo-white.png` e `docs/logo-wine.png`

### Funcionalidades Ativas
- Relatório completo enviado automaticamente por email ao concluir assessment
- Avaliação com estrelas (1-5) + comentário enviada por email separado
- Sistema de link único com token (admin.html, senha: `inself2024`)
- Diagnóstico financeiro de crenças com 3 níveis de alerta
- Plano de ação personalizado baseado no perfil
- Botão "Salvar PDF" com nome do respondente no título
- Auto-save em localStorage — retoma de onde parou
- Domínio customizado com HTTPS (via GitHub Pages + Registro.br)

### Domínio
- **Registrado em:** Registro.br
- **CNAME configurado:** `perfil` → `dralaurianesilva.github.io.`
- **Custom domain no GitHub Pages:** `perfil.dralaurianesilva.com.br`
- **HTTPS:** sendo emitido automaticamente pelo GitHub (Let's Encrypt)
<!-- END inself-assessment-app -->
<!-- END onboard-aliado:contexto-do-negocio -->
