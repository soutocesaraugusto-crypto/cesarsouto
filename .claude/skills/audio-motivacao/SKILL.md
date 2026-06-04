---
name: audio-motivacao
description: |
  Sobe o Gerador de áudios de Omniterapia da OMNI Brasil na máquina do usuário.
  Prepara o ambiente (instala ffmpeg e dependências se faltarem), inicia o app
  localmente e abre no navegador. Na primeira vez, o app pede as chaves de API
  (Mistral + Google AI Studio) numa tela de configuração.
user-invocable: true
version: "1.0.0"
---

# /audio-motivacao — Subir o Gerador de áudios de Omniterapia

## Propósito

Deixar o app de geração de áudios de omniterapia rodando na máquina do usuário com um comando só. O app gera: **tema → roteiro (IA) → áudio com a voz da Rafa/Michael**. Esta skill cuida de preparar o ambiente, subir o servidor local e abrir o navegador.

## Quando usar

Quando o usuário digita `/audio-motivacao`, ou diz "abre o gerador de áudios", "quero gerar uma omniterapia", "sobe o app de áudio".

## O que o app precisa (a skill garante tudo isto)

- **Node.js ≥ 20** (o usuário geralmente já tem)
- **ffmpeg** no PATH (monta o MP3) — a skill instala se faltar
- **dependências** (`npm install`)
- **chaves de API** — o próprio app pede numa tela de onboarding na 1ª vez (cada pessoa usa as suas):
  - **Mistral** (a voz): https://console.mistral.ai/api-keys
  - **Google AI Studio** (o roteiro, gratuito): https://aistudio.google.com/apikey
- **a voz do usuário** (nas versões que exigem) — na 1ª vez o app pede pra gravar 3 amostras curtas (uma por tom: calmo, normal, motivacional) ou subir áudios prontos. É o que faz o app gerar com a voz da própria pessoa.

## Passo a passo (executar nesta ordem)

### 1. Localizar a pasta do app

O app fica em `apps/audio-motivacao` a partir da raiz do repositório. Confirme que `apps/audio-motivacao/server.js` existe. Se não estiver lá (estrutura diferente no repo do aluno), procure com Glob `**/audio-motivacao/server.js` e use a pasta encontrada. Trabalhe sempre **dentro** dessa pasta.

### 2. Verificar se o app já está rodando

Antes de qualquer coisa, cheque a saúde:

```
curl -s http://127.0.0.1:7791/api/health
```

Se responder `{"ok":true,...}`, o app **já está no ar** — pule direto para o passo 5 (abrir o navegador) e avise o usuário.

### 3. Preparar o ambiente (instala o que falta)

Rode o script de preparação adequado ao sistema. Ele é idempotente (seguro rodar de novo) e instala ffmpeg/dependências só se faltarem.

- **Windows (PowerShell):**
  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File setup/setup.ps1
  ```
- **Mac / Linux (bash):**
  ```
  bash setup/setup.sh
  ```

Se o script avisar que o ffmpeg foi instalado agora mas não está visível ainda, peça ao usuário para fechar e reabrir o terminal e rodar `/audio-motivacao` de novo (o sistema precisa reconhecer o programa novo no PATH).

### 4. Subir o servidor (em background)

Suba o app **em background** (use `run_in_background` do Bash) a partir da pasta do app:

```
node server.js
```

Depois espere o servidor responder (faça polling curto em `http://127.0.0.1:7791/api/health` até retornar `ok`, com timeout de ~15s). Não bloqueie esperando o processo terminar — ele fica rodando.

### 5. Abrir no navegador

Abra `http://127.0.0.1:7791`:

- **Windows:** `start http://127.0.0.1:7791`
- **Mac:** `open http://127.0.0.1:7791`
- **Linux:** `xdg-open http://127.0.0.1:7791`

### 6. Avisar o usuário

Diga, em pt-BR e de forma curta:

- O app abriu no navegador.
- **Se for a primeira vez:** vai aparecer uma tela de configuração. Primeiro pede as chaves (Mistral e Google AI Studio) — é só colar e continuar. Depois (nas versões com voz própria) pede pra **gravar 3 trechos curtos com a própria voz** (ou subir áudios prontos), um por tom. Inclua os dois links de onde tirar as chaves.
- Depois disso, é só escrever o tema, escolher a duração, e gerar.
- Para **desligar** o app depois: encerrar o processo do servidor (ou fechar o terminal/sessão).

## Notas

- **Não precisa de chave pra rodar a skill** — quem pede as chaves é o app, na tela de onboarding. A skill nunca digita ou guarda chave.
- O app roda **100% local** (`127.0.0.1:7791`), nada é exposto pra internet.
- Se a porta 7791 estiver ocupada por outra coisa, o usuário pode definir `PORT` no `.env`; ajuste a URL de acordo.
- **Não há transcrição** neste app — o fluxo é só texto → áudio.
