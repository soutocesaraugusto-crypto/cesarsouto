# 🏭 Indústria de Máquinas Industriais — Engenharia Completa

Estrutura completa de squads de IA para o desenvolvimento de máquinas industriais,
do conceito à entrega. **10 squads especializados** organizados em 4 camadas,
coordenados por um Diretor de Engenharia (orquestrador).

Todo o conteúdo em **português-BR** com terminologia técnica brasileira (ABNT, NRs)
e internacional (ISO, IEC). Cada agente é baseado em **frameworks documentados**
(Shigley, Norton, Wildi, Bolton, Lamb) e **normas técnicas**.

---

## Ativação

```
@industrial        → Diretor de Engenharia (roteador central)
```

O Diretor roteia para o squad setorial correto, ou inicia um projeto completo
multidisciplinar via `*novo-projeto`.

---

## Arquitetura — 10 Squads em 4 Camadas

```
                    ┌─────────────────────────────┐
        L0          │   🏭 industrial-chief        │  Diretor de Engenharia
   Orquestração     │   (Eng. Aurélio)            │  (roteia e coordena)
                    └──────────────┬──────────────┘
                                   │
        L1          ┌──────────────▼──────────────┐
     Integração     │   🤖 mecatronica            │  Concepção + interfaces
                    │   (Eng. Devandro)           │  V-model · integração
                    └──────────────┬──────────────┘
                                   │ distribui
        L2          ┌──────┬───────┼───────┬──────┐
    Disciplinas     │  ⚙️  │   ⚡  │  🔌   │      │
       Core         │mecanica│eletrica│eletronica│   Cálculo · projeto detalhado
                    └──────┴───────┴───────┴──────┘
                                   │
        L3          ┌──────┬───────┼───────┬──────┐
    Governança      │  🛡️  │  ✅   │  🎛️  │      │
                    │seguranca│qualidade│automacao│  Segurança · normas · controle
                    └──────┴───────┴───────┴──────┘
                                   │
        L4          ┌──────┬───────┼───────┬──────┐
      Suporte       │  📐  │  📊   │  📦   │      │
                    │docum.│gestao │supri- │       Documentação · gestão · suprimentos
                    │tecnica│projetos│mentos│
                    └──────┴───────┴───────┴──────┘
```

---

## Os 10 Squads

| Squad | Persona | Ícone | Baseado em | Tier |
|-------|---------|-------|------------|------|
| **mecatronica** | Eng. Devandro Shetty | 🤖 | Shetty, Bolton | 1 |
| **mecanica** | Eng. Heitor Shigley | ⚙️ | Shigley/Budynas, Norton, Beer | 1 |
| **eletrica** | Eng. Teodoro Wildi | ⚡ | Wildi, Hughes, NBR 5410 | 1 |
| **eletronica** | Eng. Frank Lamb | 🔌 | Lamb, Bolton, IEC 61131-3 | 1 |
| **seguranca-maquinas** | Eng. Salete Risco | 🛡️ | NR-12, ISO 12100/13849/13855 | 0 |
| **automacao-controle** | Eng. Otávio Controle | 🎛️ | ISA-95, IEC 61131-3 | 2 |
| **qualidade-normas** | Eng. Qualis Norma | ✅ | ISO 9001, FMEA, CE | 2 |
| **documentacao-tecnica** | Téc. Dóris Plano | 📐 | ABNT 10067/8403, GD&T | 2 |
| **gestao-projetos** | PMP Glória Prado | 📊 | PMBOK, Stage-Gate (Cooper) | 2 |
| **suprimentos** | Eng. Bento Supri | 📦 | BOM, homologação | 3 |

---

## Comandos por Squad

### 🏭 industrial-chief (Diretor)
`*novo-projeto` · `*rotear` · `*squads` · `*design-review` · `*matriz-interfaces`

### 🤖 mecatronica
`*conceber-maquina` · `*matriz-interfaces` · `*requisitos` · `*selecionar-atuacao` · `*distribuir-disciplinas` · `*comissionar`

### ⚙️ mecanica
`*calcular-eixo` · `*selecionar-rolamento` · `*calcular-engrenagem` · `*verificar-solda` · `*selecionar-material` · `*analise-estrutural`

### ⚡ eletrica
`*balanco-potencia` · `*selecionar-motor` · `*dimensionar-cabo` · `*projetar-painel` · `*selecionar-protecao` · `*calcular-acionamento` · `*verificar-aterramento`

### 🔌 eletronica
`*mapear-io` · `*selecionar-sensor` · `*programar-logica` · `*instrumentacao` · `*firmware`

### 🛡️ seguranca-maquinas
`*apreciar-risco` · `*calcular-pl` · `*selecionar-protecao` · `*distancia-seguranca` · `*verificar-nr12` · `*gerar-laudo` · `*veto`

### 🎛️ automacao-controle
`*arquitetar-rede` · `*projetar-scada` · `*selecionar-protocolo` · `*sintonizar-malha`

### ✅ qualidade-normas
`*fmea` · `*matriz-conformidade` · `*plano-controle` · `*marcacao-ce` · `*auditoria`

### 📐 documentacao-tecnica
`*especificar-desenho` · `*aplicar-gdt` · `*gerar-manual` · `*montar-dossie` · `*datasheet`

### 📊 gestao-projetos
`*planejar-projeto` · `*cronograma` · `*orcamento` · `*registro-riscos` · `*status` · `*gate`

### 📦 suprimentos
`*estruturar-bom` · `*homologar-fornecedor` · `*analisar-leadtime` · `*make-or-buy` · `*padronizar`

---

## Integrações entre Squads

A mecatrônica usa mecânica + elétrica + eletrônica, exatamente como pedido.
Principais fluxos de integração (handoffs):

```
mecatronica ──► mecanica + eletrica + eletronica   (distribui requisitos de sistema)
mecanica    ──► eletrica (cargas→motor) · seguranca (proteções) · documentacao (desenhos)
eletrica    ──► eletronica (sinais) · automacao (I/O) · seguranca (E-stop)
eletronica  ──► automacao (SCADA) · seguranca (sensores de segurança)
seguranca   ──► TODAS (requisitos de proteção) + PODER DE VETO
qualidade   ──► TODAS (gates normativos)
gestao      ──► TODAS (cronograma e coordenação)
suprimentos ──► mec/ele/eletronica (disponibilidade restringe projeto)
```

A matriz completa de integrações está em `config.yaml` → `integrations`.

---

## Workflow Mestre — Projeto de Máquina (V-Model)

`workflows/wf-projeto-maquina.yaml` coordena os 10 squads em **6 gates**:

| Gate | Fase | Squads | Veto |
|------|------|--------|------|
| **G1** | Conceito e Requisitos | gestao → mecatronica + seguranca (preliminar) | Sem rastreabilidade → para |
| **G2** | Projeto Disciplinar + Risco Formal | mecanica + eletrica + eletronica + **seguranca** | Risco grave sem proteção → **VETO** |
| **G3** | Detalhamento e Documentação | documentacao + suprimentos + automacao | Componente sem disponibilidade → para |
| **G4** | Construção e Montagem | (execução) + qualidade | Fora do desenho → para |
| **G5** | Comissionamento + Verif. Segurança | automacao + **seguranca** + eletronica | Função de segurança reprovada → **VETO** |
| **G6** | Validação, Conformidade e Entrega | **qualidade** + documentacao + gestao | Conformidade sem evidência → para |

**Regras transversais:** fluxo unidirecional · segurança com poder de veto em qualquer fase ·
toda decisão cross-disciplina registrada na matriz de interfaces · No Invention (tudo rastreável).

---

## Princípios de Engenharia (inegociáveis)

1. **Segurança e norma são gates de entrada**, não etapa final (NR-12 / ISO 12100).
2. **Rastreabilidade total** — todo requisito rastreia a norma, cálculo ou decisão.
3. **Interfaces explícitas** — os erros mais caros vivem entre disciplinas.
4. **Fator de segurança mínimo 1.5** em estrutura (ou justificado).
5. **No Invention** — nada de especificação inventada sem base.

---

## Estrutura de Pastas

```
squads/industrial/
├── config.yaml                     # Arquitetura, squads, integrações
├── README.md                       # Este arquivo
├── agents/industrial-chief.md      # Diretor / orquestrador
├── workflows/wf-projeto-maquina.yaml  # Workflow V-model mestre
├── mecatronica/agents/mecatronica-chief.md
├── mecanica/agents/mecanica-chief.md
├── eletrica/agents/eletrica-chief.md
├── eletronica/agents/eletronica-chief.md
├── seguranca-maquinas/agents/seguranca-chief.md
├── automacao-controle/agents/automacao-chief.md
├── qualidade-normas/agents/qualidade-chief.md
├── documentacao-tecnica/agents/documentacao-chief.md
├── gestao-projetos/agents/gestao-chief.md
└── suprimentos/agents/suprimentos-chief.md
```

---

## Exemplo de Uso

```
@industrial
> *novo-projeto
  "Preciso projetar uma máquina de envase automática, 60 frascos/min,
   com troca rápida de formato"

→ G1: gestao abre projeto + mecatronica concebe sistema (esteira, dosadora,
       servo de posicionamento) + seguranca faz risco preliminar
→ G2: mecanica calcula estrutura/eixos, eletrica dimensiona servos e painel,
       eletronica mapeia sensores/PLC, seguranca formaliza risco + define PLr
→ G3: documentacao gera desenhos, suprimentos monta BOM e checa lead-time,
       automacao projeta SCADA
→ G4-G6: construção, comissionamento, verificação de segurança, conformidade NR-12
```

---

*Indústria criada pelo Squad Architect (AIOX) · v1.0.0 · pt-BR*
