---
name: audio-motivacao
description: |
  Sobe o Gerador de Áudios Terapêuticos da Dra. Lauriane Silva na máquina.
  Prepara o ambiente (instala ffmpeg e dependências se faltarem), inicia o app
  localmente e abre no navegador. Gera áudios de autohipnose motivacional,
  hipnose clínica para tratamento e roteiros próprios, com a voz da Dra. Lauriane,
  sons bi-neurais, Escala Hawkins e personalização por cliente.
user-invocable: true
version: "2.0.0"
---

# /audio-motivacao — Gerador de Áudios Terapêuticos · Dra. Lauriane Silva

## Propósito

Subir o app de geração de áudios terapêuticos com a voz da Dra. Lauriane Silva. O app gera:
- **Motivacional:** tema → roteiro IA → áudio com sons relaxantes/binaurais
- **Tratamento:** intake clínico + Escala Hawkins → hipnose terapêutica personalizada
- **Roteiro Próprio:** texto livre → áudio com a voz da Dra. Lauriane

## Quando usar

Quando a usuária digita `/audio-motivacao`, ou diz "abre o gerador de áudios", "quero gerar um áudio", "sobe o app de áudio terapêutico".

## O que o app precisa (a skill garante tudo)

- **Node.js ≥ 20**
- **ffmpeg** no PATH — a skill instala via Homebrew se faltar (Mac)
- **Dependências** (`npm install`)
- **Chaves de API** — pedidas na tela de onboarding na 1ª vez:
  - **Mistral** (síntese de voz): https://console.mistral.ai/api-keys
  - **Google AI Studio** (roteiro via IA, gratuito): https://aistudio.google.com/apikey

A voz da Dra. Lauriane já está configurada com amostras reais de suas sessões — não precisa gravar na primeira vez.

## Passo a passo

### 1. Localizar a pasta do app

O app fica em `apps/audio-motivacao` na raiz do repositório. Confirme que `apps/audio-motivacao/server.js` existe.

### 2. Verificar se já está rodando

```
curl -s http://127.0.0.1:7791/api/health
```

Se responder `{"ok":true,...}`, pule para o passo 5.

### 3. Preparar o ambiente

- **Mac / Linux:** `bash setup/setup.sh`
- **Windows:** `powershell -NoProfile -ExecutionPolicy Bypass -File setup/setup.ps1`

### 4. Subir o servidor (background)

```
node server.js
```

Aguarde polling em `http://127.0.0.1:7791/api/health` retornar `ok` (timeout ~15s).

### 5. Abrir no navegador

- **Mac:** `open http://127.0.0.1:7791`
- **Windows:** `start http://127.0.0.1:7791`
- **Linux:** `xdg-open http://127.0.0.1:7791`

### 6. Avisar a usuária

O app abriu. Na primeira vez, uma tela pede as chaves da Mistral e do Google AI Studio — só colar e continuar. Depois disso: escolher o tipo de áudio, preencher o tema ou o formulário de intake, e gerar.

## Funcionalidades do app

| Recurso | Detalhe |
|---|---|
| **3 modos** | Motivacional, Tratamento (hipnose clínica), Roteiro Próprio |
| **6 durações** | ~3 min até ~30 min |
| **Sons de fundo** | Sem música, Natureza, Relaxante, Binaural puro |
| **Escala Hawkins** | Arco de elevação de consciência (17 níveis) com binaural automático |
| **Personalização** | Nome do cliente + formulário de intake com 6 campos clínicos |
| **Tom de voz** | Hipnótico, Natural ou Motivacional (no Roteiro Próprio) |
| **Histórico** | Lista de áudios gerados com download e roteiro |

## Notas

- App roda **100% local** (`127.0.0.1:7791`), nada exposto à internet.
- Chaves ficam no `.env` local — nunca expostas no frontend.
- Se a porta 7791 estiver ocupada, defina `PORT` no `.env`.
