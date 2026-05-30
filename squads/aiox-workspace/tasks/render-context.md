# Task: Render Context

```yaml
task:
  id: render-context
  name: Renderizar Contexto de Pesquisa
  agent: workspace-chief
  trigger: internal
  elicit: false
  commands: []  # Não é invocado diretamente pelo usuário
```

## Descrição

Task interna que lê um context manifest e extrai as variáveis especificadas do workspace de um business, gerando um documento tokenizado (research-context) pronto para consumo por tasks de diagnóstico.

**Conceito:** Inspirado no briefing tokenizado (46 variáveis fixas determinadas por engenharia reversa). Em vez de a IA ler 20 arquivos e decidir o que importa, o manifest define exatamente quais campos extrair. A IA recebe UM documento com contexto preciso.

**Guardian:** COO (Chief Operating Officer)

## Input

```yaml
input:
  manifest_path: "manifests/{manifest-id}.manifest.yaml"  # qual manifest usar
  slug: "{business-slug}"                                   # qual business
  product: "{product-slug}"                                 # opcional, para manifests product-level
```

## Workflow

### Passo 1: Carregar Manifest

```yaml
load_manifest:
  action: "Ler manifests/{manifest-id}.manifest.yaml"
  output: "Lista de variáveis com source, field, type"
```

### Passo 2: Resolver Paths

Para cada variável no manifest, resolver o path real:
- Substituir `{slug}` pelo business slug
- Substituir `{product}` pelo product slug (se aplicável)
- Resolver wildcards `products/*` listando diretórios reais
- Base path: `workspace/businesses/{slug}/`

```yaml
resolve_paths:
  base: "workspace/businesses/{slug}/"
  substitutions:
    "{product}": "valor do parâmetro product"
  wildcards:
    "products/*": "listar ls workspace/businesses/{slug}/products/"
```

### Passo 3: Extrair Variáveis

Para cada variável, extrair o valor do arquivo YAML:

```yaml
extraction_rules:
  _exists:
    description: "Arquivo existe no filesystem?"
    method: "ls {path} 2>/dev/null && echo true || echo false"
    output: boolean

  _exists_any:
    description: "Pelo menos 1 arquivo matching o glob existe?"
    method: "Verificar se pelo menos 1 match de products/*/file.yaml existe"
    output: boolean

  _dir_count:
    description: "Quantos subdiretórios existem?"
    method: "ls -d {path}*/ 2>/dev/null | wc -l"
    output: integer

  _count:
    description: "Quantos arquivos matching existem?"
    method: "ls {glob} 2>/dev/null | wc -l"
    output: integer

  _completeness:
    description: "% de campos preenchidos no arquivo"
    method: |
      Ler YAML, contar campos totais vs campos com valor real
      Excluir: null, FILL_THIS, TBD, TODO, ~, [], "", INCOMPLETE
      Calcular: preenchidos / total * 100
    output: percentage

  field.path:
    description: "Valor de um campo específico no YAML"
    method: "Ler YAML, navegar até field path, retornar valor"
    output: "conforme type definido"

  array_length:
    description: "Tamanho de um array no YAML"
    method: "Ler YAML, contar elementos do array"
    output: integer

  array_length_sum:
    description: "Soma de tamanhos de arrays em múltiplos arquivos (wildcard)"
    method: "Para cada arquivo matching, contar array length, somar"
    output: integer

  score_block:
    description: "Bloco de scoring embutido no template (4 dimensões 1-10)"
    method: "Ler as 4 dimensões do _strength_score, retornar objeto"
    output: object

  completeness:
    description: "% de sub-campos preenchidos dentro de uma seção"
    method: "Contar sub-campos preenchidos vs total na seção"
    output: percentage
```

### Passo 4: Classificar Valores

Para cada variável extraída, classificar:

```yaml
classification:
  present: "Valor existe e é real (não placeholder)"
  placeholder: "Valor é FILL_THIS, TBD, TODO, null, ~, INCOMPLETE"
  missing: "Arquivo não existe ou campo não encontrado"
```

### Passo 5: Renderizar Research Context

Gerar documento tokenizado com todas as variáveis:

```markdown
# Research Context: {manifest_id}

**Business:** {slug}
**Product:** {product ou "N/A"}
**Gerado em:** {YYYY-MM-DD HH:MM}
**Manifest:** {manifest_path}
**Variáveis:** {total} ({present} presentes, {placeholder} placeholders, {missing} ausentes)

---

## Variáveis Extraídas

### {dimension_name} (peso: {weight})

| ID | Source | Valor | Status |
|----|--------|-------|--------|
| {var_id} | {source_file} | {valor_extraído} | PRESENT/PLACEHOLDER/MISSING |

---

## Resumo de Cobertura

| Dimensão | Variáveis | Presentes | Placeholders | Ausentes | Cobertura |
|----------|-----------|-----------|-------------|----------|-----------|
| {dim} | {total} | {present} | {placeholder} | {missing} | {%} |

---

## Dados Brutos (para consumo por task)

```yaml
context:
  slug: "{slug}"
  product: "{product}"
  generated_at: "{timestamp}"

  {dimension_1}:
    {var_id}: {valor}
    {var_id}: {valor}

  {dimension_2}:
    {var_id}: {valor}
```
```

### Passo 6: Retornar Context

O research-context renderizado é passado diretamente para a task que o requisitou. Não é persistido em arquivo (é efêmero, sempre gerado fresco).

**Exceção:** O relatório final do diagnóstico (que CONSOME o context) é persistido em `docs/diagnostics/`.

## Tipos de Variável Suportados

| Type | Descrição | Exemplo |
|------|-----------|---------|
| `boolean` | true/false | arquivo existe? |
| `string` | texto | nome do ICP |
| `number` | numérico | preço, score |
| `integer` | inteiro | contagem |
| `percentage` | 0-100% | completude |
| `array_length` | tamanho de array | quantos items |
| `array_length_sum` | soma de arrays (wildcard) | total cross-products |
| `completeness` | % campos preenchidos | saúde do arquivo |
| `score_block` | bloco de scoring 1-10 | _strength_score |
| `object` | objeto YAML | archetype_mix |
| `boolean_any` | true se qualquer match | pelo menos 1 tem |
| `array` | lista de valores | stages com bottleneck |

## Regras

1. **Nunca inventar dados.** Se variável é MISSING, marcar como MISSING.
2. **Sempre usar templates como referência.** O manifest define quais campos são esperados.
3. **Placeholders são explícitos.** FILL_THIS, TBD, TODO, null, ~, [], "" = não preenchido.
4. **Context é efêmero.** Gerado on-demand, sempre fresco. Não cachear.
5. **Manifest é fixo.** As variáveis são determinadas por engenharia reversa, não mudam por execução.

## Validação

- [ ] Todas as variáveis do manifest foram processadas
- [ ] Nenhum campo inventado (só extração)
- [ ] Status (PRESENT/PLACEHOLDER/MISSING) correto para cada variável
- [ ] Resumo de cobertura calculado

---

*Task do Squad AIOX Workspace - COO Orchestrator*
*Versão: 1.0.0*
*Última atualização: 2026-03-18*
