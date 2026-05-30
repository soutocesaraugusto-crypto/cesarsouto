# Task: Bootstrap

```yaml
task:
  id: bootstrap
  name: Bootstrap do Workspace
  agent: workspace-chief
  elicit: true
  required: true
  order: 1
```

## Descrição

Primeira task obrigatória do Squad AIOX Workspace. Cria os 3 arquivos raiz do workspace e a estrutura de diretórios.

**IMPORTANTE:** Esta task deve ser executada ANTES de qualquer outra task do squad.

## Workflow

### Fase 1: Verificar se workspace já existe

```bash
ls workspace/ 2>/dev/null
```

Se existir, perguntar se quer reinicializar ou apenas atualizar.

### Fase 2: Coleta de Informações do Usuário

```yaml
elicitation:
  questions:
    - id: name
      text: "Qual é o seu nome completo?"
      required: true
    - id: preferred_name
      text: "Como você prefere ser chamado?"
      required: true
    - id: role
      text: "Qual é o seu papel? (founder, funcionário, freelancer)"
      required: true
    - id: area
      text: "Qual é sua área de atuação principal?"
      required: true
    - id: communication_tone
      text: "Prefere comunicação formal ou casual?"
      required: false
      default: "casual"
    - id: language
      text: "Idioma preferido?"
      required: false
      default: "pt-BR"
```

### Fase 3: Criação da Estrutura

1. Criar diretório `workspace/` se não existir
2. Criar subdiretórios:
   - `workspace/businesses/`
   - `workspace/_templates/`
3. Criar os 3 arquivos raiz:
   - `workspace/user.yaml`
   - `workspace/config.yaml`
   - `workspace/canonical-sources.yaml`

### Fase 4: Output - user.yaml

```yaml
# User Profile
# Referenciado por todos os agentes para personalizar interações
# Criado: {date} | Atualizado: {date}

identity:
  name: "{name}"
  call_me: "{preferred_name}"

professional_context:
  area: "{area}"
  role: "{role}"

preferences:
  tone: "{communication_tone}"
  language: "{language}"
```

### Fase 5: Output - config.yaml

```yaml
# Workspace Configuration
# Gerenciado pelo COO - Squad AIOX Workspace
# Atualizado: {date}

businesses: []
# Use *add-business {slug} para adicionar negócios

global_preferences:
  language: "{language}"
  date_format: "DD/MM/YYYY"
  timezone: "America/Sao_Paulo"
```

### Fase 6: Output - canonical-sources.yaml

```yaml
# CANONICAL-SOURCES.YAML — AIOX Workspace Ontology Registry
# Registro central de quem é DONO de cada tipo de dado no workspace.
# Quando um dado aparece em mais de um lugar, este arquivo diz qual vence.
#
# REGRAS INVIOLÁVEIS:
#   1. Todo dado tem UM dono. Sem exceções.
#   2. Entidades nunca duplicam dados de outras entidades.
#   3. Se um path muda, atualizar AQUI primeiro.

schema_version: "0.1"
last_updated: "{date}"

decisions: {}

eliminated_files: []

entities: {}
# Será populado conforme businesses e produtos forem adicionados

field_rules: {}
# Será populado conforme conflitos de dados forem resolvidos
```

## Estrutura Final

```
workspace/
├── user.yaml               # Perfil do usuário (COO cria no bootstrap)
├── config.yaml             # Lista de businesses e preferências (COO mantém)
├── canonical-sources.yaml  # Ontologia: quem é dono de cada dado (COO mantém)
├── _templates/             # Templates canônicos para scaffold
└── businesses/             # Múltiplos negócios (vazio até *add-business)
```

## Validação

- [ ] Diretório `workspace/` existe
- [ ] Arquivo `workspace/user.yaml` criado com nome do usuário
- [ ] Arquivo `workspace/config.yaml` criado
- [ ] Arquivo `workspace/canonical-sources.yaml` criado
- [ ] Diretório `workspace/businesses/` existe
- [ ] Diretório `workspace/_templates/` existe

## Próximos Passos

Após bootstrap, sugerir:
1. `*add-business {slug}` - Adicionar primeiro negócio
2. `*setup-workspace` - Rodar elicitação completa (após add-business)

---

*Task do Squad AIOX Workspace - COO Orchestrator*
