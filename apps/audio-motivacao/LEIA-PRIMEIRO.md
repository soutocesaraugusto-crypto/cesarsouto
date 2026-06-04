# Gerador de áudios de Omniterapia — como usar

Este app gera áudios de omniterapia: você escreve um tema, a IA cria o roteiro e ele vira áudio com a voz escolhida (Rafa/Michael).

## Como abrir

No Claude Code, dentro do repositório, digite:

```
/audio-motivacao
```

A skill cuida de tudo: instala o que faltar (ffmpeg e dependências), sobe o app e abre no navegador em `http://127.0.0.1:7791`. Funciona em Windows, Mac e Linux.

> Você precisa ter **Node.js** instalado (versão 20 ou maior). O resto a skill instala sozinha.

## Primeira vez: chaves + sua voz

Na primeira vez, o app abre numa tela de configuração em dois passos.

**1) As chaves** (cada pessoa usa as suas):

- **Mistral** — é a voz. Crie em <https://console.mistral.ai/api-keys>
- **Google AI Studio** — escreve o roteiro (é grátis). Crie em <https://aistudio.google.com/apikey>

Cole as duas e clique em **Salvar e continuar**.

**2) Sua voz** (na versão personalizada): o app pede pra gravar **3 trechos curtos** (um calmo, um normal e um animado) lendo o texto que aparece na tela. Grave num lugar silencioso — ou suba um áudio pronto de ~20–30s. É isso que faz o app gerar os áudios com a **sua** voz.

Pronto. O app guarda tudo na sua máquina (chaves no `.env`, voz em `data/voices/`) — você não vê essa tela de novo.

## Depois

Rode `/audio-motivacao` de novo sempre que quiser usar. Se o app já estiver no ar, ele só abre o navegador. Para desligar, encerre o processo do servidor (ou feche a sessão do terminal).

## Deu algum problema?

- **"ffmpeg não encontrado" mesmo depois de instalar:** feche e reabra o terminal e rode `/audio-motivacao` de novo (o sistema precisa reconhecer o programa novo).
- **Qualquer outro erro:** tire um print e mande pro suporte OMNI.

---

### Detalhes técnicos (pra quem mexe no código)

- A skill fica em `.claude/skills/audio-motivacao/SKILL.md`.
- Os scripts de preparação de ambiente estão em `setup/setup.ps1` (Windows) e `setup/setup.sh` (Mac/Linux) — só instalam ffmpeg/deps e criam o `.env`; quem sobe o servidor é a skill.
- O onboarding de chaves é servido pelo próprio app (`/api/setup/status` e `/api/setup/save`, em `lib/setup-status.js`).
- Configuração de referência em `.env.example`.
