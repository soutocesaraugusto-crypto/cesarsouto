#!/usr/bin/env bash
# =============================================================================
#  instalar.sh — Instalador da sua assistente Prisma (Aliança de Ouro)
# =============================================================================
#  O que ele faz:
#    1. Detecta o ambiente (Linux / macOS / WSL) e barra Windows puro.
#    2. Confere os pré-requisitos (node, claude logado, tmux, jq, git).
#    3. Pergunta nome da assistente, seu nome, negócio e canal.
#    4. Guia a captura do(s) token(s) (Telegram via BotFather, WhatsApp via QR).
#    5. Gera os arquivos finais da assistente a partir dos templates.
#    6. Sobe a assistente (install → deploy → enable do gateway).
#    7. Mostra como conversar, personalizar e ligar/desligar.
#
#  Rode assim, dentro desta pasta:
#      bash instalar.sh
# =============================================================================

set -uo pipefail

# --- Cores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}!${NC} $1"; }
erro()  { echo -e "  ${RED}✗${NC} $1"; }
info()  { echo -e "  $1"; }
titulo() {
    echo ""
    echo -e "${CYAN}===========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}===========================================${NC}"
    echo ""
}

# --- Caminhos (pacote self-contained) ---
PRISMA_HOME="$(cd "$(dirname "$0")" && pwd)"
export PRISMA_HOME
GATEWAY="${PRISMA_HOME}/gateway"
PERSONA_DIR="${PRISMA_HOME}/persona"
CONFIG_DIR="${PRISMA_HOME}/config"

# =============================================================================
#  PASSO 1 — Detectar o ambiente
# =============================================================================
titulo "Passo 1 de 7 — Conferindo o seu ambiente"

UNAME="$(uname -s 2>/dev/null || echo desconhecido)"
PLATAFORMA="desconhecido"
case "${UNAME}" in
    Darwin*) PLATAFORMA="macos" ;;
    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            PLATAFORMA="wsl"
        else
            PLATAFORMA="linux"
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # Git Bash / MSYS no Windows SEM WSL
        PLATAFORMA="windows-puro"
        ;;
esac

case "${PLATAFORMA}" in
    macos) ok "Detectado: macOS" ;;
    linux) ok "Detectado: Linux (servidor/VPS)" ;;
    wsl)   ok "Detectado: WSL (Linux dentro do Windows)" ;;
    windows-puro)
        erro "Você está no Windows SEM WSL (Git Bash/MSYS)."
        echo ""
        info "A Prisma precisa do ${BOLD}WSL${NC} (um Linux dentro do Windows)."
        info "Como instalar (leva uns 5 minutos):"
        info "  1. Abra o ${BOLD}PowerShell como Administrador${NC}"
        info "  2. Rode:  ${BOLD}wsl --install${NC}"
        info "  3. Reinicie o computador quando ele pedir"
        info "  4. Abra o app ${BOLD}Ubuntu${NC} (vai aparecer no menu Iniciar)"
        info "  5. Dentro do Ubuntu, copie esta pasta e rode de novo:  ${BOLD}bash instalar.sh${NC}"
        echo ""
        info "Guia oficial: https://learn.microsoft.com/windows/wsl/install"
        exit 1
        ;;
    *)
        erro "Não consegui identificar seu sistema operacional (${UNAME})."
        info "Este instalador funciona em Linux, macOS ou WSL."
        exit 1
        ;;
esac

# =============================================================================
#  PASSO 2 — Conferir pré-requisitos
# =============================================================================
titulo "Passo 2 de 7 — Conferindo os programas necessários"

FALTANDO=()
tem() { command -v "$1" >/dev/null 2>&1; }

tem node   && ok "node encontrado"   || { erro "node NÃO encontrado";   FALTANDO+=("node"); }
tem claude && ok "claude encontrado" || { erro "claude NÃO encontrado"; FALTANDO+=("claude"); }
tem tmux   && ok "tmux encontrado"   || { erro "tmux NÃO encontrado";   FALTANDO+=("tmux"); }
tem jq     && ok "jq encontrado"     || { erro "jq NÃO encontrado";     FALTANDO+=("jq"); }
tem git    && ok "git encontrado"    || { erro "git NÃO encontrado";    FALTANDO+=("git"); }
tem curl   && ok "curl encontrado"   || { erro "curl NÃO encontrado";   FALTANDO+=("curl"); }

# Gerenciador de pacotes sugerido por plataforma
if [[ "${PLATAFORMA}" == "macos" ]]; then
    INSTALADOR="brew install"
    NOTA_PM="(precisa do Homebrew: https://brew.sh)"
else
    INSTALADOR="sudo apt install -y"
    NOTA_PM="(Ubuntu/Debian; em outras distros use o gerenciador equivalente)"
fi

if [[ ${#FALTANDO[@]} -gt 0 ]]; then
    echo ""
    erro "Faltam programas: ${FALTANDO[*]}"
    echo ""
    info "Como instalar ${NOTA_PM}:"
    for prog in "${FALTANDO[@]}"; do
        case "${prog}" in
            claude)
                info "  • claude (Claude Code): https://docs.anthropic.com/en/docs/claude-code"
                ;;
            node)
                info "  • node:  ${INSTALADOR} nodejs npm   (ou use nvm: https://github.com/nvm-sh/nvm)"
                ;;
            *)
                info "  • ${prog}:  ${INSTALADOR} ${prog}"
                ;;
        esac
    done
    echo ""
    info "Instale o que falta e rode de novo:  ${BOLD}bash instalar.sh${NC}"
    exit 1
fi

# Confere que o Claude está logado / aceito os termos
if ! claude --version >/dev/null 2>&1; then
    echo ""
    erro "O Claude está instalado, mas parece não estar configurado."
    info "Abra um terminal, rode  ${BOLD}claude${NC}  uma vez, aceite os termos e faça login."
    info "Depois rode de novo:  ${BOLD}bash instalar.sh${NC}"
    exit 1
fi
ok "Claude está logado e pronto ($(claude --version 2>/dev/null | head -1))"

# =============================================================================
#  PASSO 3 — Perguntas básicas
# =============================================================================
titulo "Passo 3 de 7 — Sobre a sua assistente"

read -r -p "  Nome da assistente [Prisma]: " ASSISTENTE
ASSISTENTE="${ASSISTENTE:-Prisma}"

# slug: minúsculo, sem espaços/acentos, só [a-z0-9-]
ASSISTENTE_SLUG="$(echo "${ASSISTENTE}" \
    | tr '[:upper:]' '[:lower:]' \
    | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
    | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//')"
[[ -z "${ASSISTENTE_SLUG}" ]] && ASSISTENTE_SLUG="prisma"

read -r -p "  Seu nome (o dono) [você]: " DONO
DONO="${DONO:-você}"

read -r -p "  Em uma frase, qual é o seu negócio? [meu negócio]: " NEGOCIO
NEGOCIO="${NEGOCIO:-meu negócio}"

ok "Assistente: ${ASSISTENTE} (slug: ${ASSISTENTE_SLUG})"
ok "Dono: ${DONO}"

# =============================================================================
#  PASSO 4 — Escolher canal
# =============================================================================
titulo "Passo 4 de 7 — Por onde você vai falar com a ${ASSISTENTE}?"

echo -e "  ${GREEN}[1]${NC} Telegram  — mais fácil de configurar (recomendado)"
echo -e "  ${GREEN}[2]${NC} WhatsApp  — você lê um QR Code com o celular"
echo -e "  ${GREEN}[3]${NC} Os dois"
echo ""
read -r -p "  Escolha [1]: " CANAL_OPT
CANAL_OPT="${CANAL_OPT:-1}"

TELEGRAM_ON="false"
WHATSAPP_ON="false"
case "${CANAL_OPT}" in
    1) TELEGRAM_ON="true" ;;
    2) WHATSAPP_ON="true" ;;
    3) TELEGRAM_ON="true"; WHATSAPP_ON="true" ;;
    *) warn "Opção inválida, usando Telegram."; TELEGRAM_ON="true" ;;
esac

# Onde os segredos moram (fora do repositório, com chmod 600)
CRM_INSTANCE_ID="default"
ENV_DIR="${HOME}/.claude-remote/${CRM_INSTANCE_ID}/config/${ASSISTENTE_SLUG}"
ENV_FILE="${ENV_DIR}/.env"
mkdir -p "${ENV_DIR}"
: > "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

# =============================================================================
#  PASSO 5 — Capturar tokens dos canais
# =============================================================================
titulo "Passo 5 de 7 — Conectando o(s) canal(is)"

# ---------- TELEGRAM ----------
if [[ "${TELEGRAM_ON}" == "true" ]]; then
    echo -e "${CYAN}--- Telegram ---${NC}"
    echo ""
    info "1. Abra o Telegram e procure por  ${BOLD}@BotFather${NC}"
    info "2. Envie:  ${BOLD}/newbot${NC}"
    info "3. Escolha um nome e um @usuario pro bot"
    info "4. Copie o ${BOLD}token${NC} que ele te der"
    echo ""
    BOT_TOKEN=""
    while [[ -z "${BOT_TOKEN}" ]]; do
        read -r -p "  Cole aqui o token do bot: " BOT_TOKEN
        [[ -z "${BOT_TOKEN}" ]] && erro "Token vazio, tente de novo."
    done

    echo ""
    info "Agora ${BOLD}envie qualquer mensagem${NC} (ex: 'oi') pro seu bot no Telegram."
    read -r -p "  Quando enviar, aperte ENTER aqui..."

    info "Buscando seu chat ID..."
    CHAT_ID="$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
        | python3 -c "import sys,json; r=json.load(sys.stdin).get('result',[]); print(r[-1]['message']['from']['id'] if r else '')" 2>/dev/null)"

    if [[ -z "${CHAT_ID}" ]]; then
        warn "Não consegui pegar automaticamente."
        read -r -p "  Digite o chat ID manualmente (ou reenvie a msg e tente): " CHAT_ID
    fi

    if [[ -z "${CHAT_ID}" ]]; then
        erro "Sem chat ID não dá pra continuar com o Telegram."
        exit 1
    fi
    ok "Chat ID: ${CHAT_ID}"

    # Limpa mensagens antigas pra não reprocessar no boot
    LAST_UPDATE="$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
        | python3 -c "import sys,json; r=json.load(sys.stdin).get('result',[]); print(r[-1]['update_id']+1 if r else '')" 2>/dev/null)"
    if [[ -n "${LAST_UPDATE}" ]]; then
        curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${LAST_UPDATE}" >/dev/null 2>&1
    fi

    {
        echo "BOT_TOKEN=${BOT_TOKEN}"
        echo "CHAT_ID=${CHAT_ID}"
        echo "ALLOWED_USER=${CHAT_ID}"
    } >> "${ENV_FILE}"
    ok "Telegram conectado."
    echo ""
fi

# ---------- WHATSAPP ----------
if [[ "${WHATSAPP_ON}" == "true" ]]; then
    echo -e "${CYAN}--- WhatsApp ---${NC}"
    echo ""
    info "O WhatsApp funciona via ${BOLD}QR Code${NC} (igual ao WhatsApp Web)."
    info "Recomendado usar um ${BOLD}número dedicado${NC} pra assistente, não o seu pessoal."
    echo ""
    info "Na primeira vez que a ${ASSISTENTE} ligar, vai aparecer um QR Code no log."
    info "Você abre  WhatsApp → Aparelhos conectados → Conectar um aparelho  e lê o código."
    echo ""
    info "Opcional: restrinja quem pode falar com ela (recomendado)."
    read -r -p "  Seu número de WhatsApp com DDI (ex: 5511999998888) [deixe vazio p/ liberar]: " WA_NUMERO
    WA_NUMERO="$(echo "${WA_NUMERO}" | tr -cd '0-9')"

    {
        echo "WHATSAPP_BRIDGE_PORT=8445"
        [[ -n "${WA_NUMERO}" ]] && echo "WHATSAPP_ALLOWED_NUMBERS=${WA_NUMERO}"
    } >> "${ENV_FILE}"

    if [[ -n "${WA_NUMERO}" ]]; then
        ok "WhatsApp configurado (liberado só para ${WA_NUMERO}). QR aparece no primeiro boot."
    else
        ok "WhatsApp configurado (sem restrição de número). QR aparece no primeiro boot."
    fi
    echo ""
fi

chmod 600 "${ENV_FILE}"
ok "Segredos salvos com segurança em: ${ENV_FILE}"

# =============================================================================
#  PASSO 6 — Gerar os arquivos da assistente
# =============================================================================
titulo "Passo 6 de 7 — Montando a personalidade da ${ASSISTENTE}"

AGENT_DIR="${GATEWAY}/agents/${ASSISTENTE_SLUG}"
mkdir -p "${AGENT_DIR}"

# Função de substituição das variáveis nos templates
preencher() {
    # $1 = arquivo template de origem, $2 = arquivo destino
    sed \
        -e "s/{{ASSISTENTE}}/${ASSISTENTE}/g" \
        -e "s/{{ASSISTENTE_SLUG}}/${ASSISTENTE_SLUG}/g" \
        -e "s/{{DONO}}/${DONO}/g" \
        -e "s/{{NEGOCIO}}/${NEGOCIO}/g" \
        -e "s/{{TELEGRAM_ON}}/${TELEGRAM_ON}/g" \
        -e "s/{{WHATSAPP_ON}}/${WHATSAPP_ON}/g" \
        "$1" > "$2"
}

preencher "${PERSONA_DIR}/SOUL.md.template"        "${AGENT_DIR}/SOUL.md"
preencher "${PERSONA_DIR}/CLAUDE.md.template"       "${AGENT_DIR}/CLAUDE.md"
preencher "${CONFIG_DIR}/config.json.template"      "${AGENT_DIR}/config.json"

# A assistente roda no próprio diretório dela (onde SOUL.md/CLAUDE.md vivem).
# Isso evita a complexidade de "working_directory" externo. Substitui o
# placeholder do template por vazio (= diretório do agente).
python3 - "${AGENT_DIR}/config.json" "${ASSISTENTE_SLUG}" <<'PYEOF'
import json, sys
path, slug = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)
cfg["agent_name"] = slug
cfg["working_directory"] = ""   # roda no diretório do próprio agente
with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
PYEOF

# Valida o JSON gerado
if ! jq empty "${AGENT_DIR}/config.json" 2>/dev/null; then
    erro "O config.json gerado ficou inválido. Abortei pra não subir quebrado."
    exit 1
fi

ok "SOUL.md, CLAUDE.md e config.json criados em: ${AGENT_DIR}"

# =============================================================================
#  PASSO 7 — Subir a assistente
# =============================================================================
titulo "Passo 7 de 7 — Ligando a ${ASSISTENTE}"

export PRISMA_AGENT_SLUG="${ASSISTENTE_SLUG}"
export CRM_AGENT_NAME="${ASSISTENTE_SLUG}"

# 7.1 — install (cria ~/.claude-remote/<instance>/ se ainda não existe)
if [[ ! -d "${HOME}/.claude-remote/${CRM_INSTANCE_ID}" ]]; then
    info "Preparando a infraestrutura local..."
    if ! bash "${GATEWAY}/install.sh" "${CRM_INSTANCE_ID}"; then
        erro "Falha ao rodar install.sh. Confira a mensagem acima."
        exit 1
    fi
else
    ok "Infraestrutura local já existe."
fi

# 7.2 — deploy (monta o diretório do agente, liga o .env, valida)
info "Montando a assistente..."
if ! bash "${GATEWAY}/deploy-agent.sh" "${ASSISTENTE_SLUG}"; then
    erro "Falha no deploy-agent.sh. Confira a mensagem acima."
    exit 1
fi

# 7.3 — enable (cria a persistência: systemd/launchd/schtasks + sobe no tmux)
info "Ligando a assistente (ela vai reiniciar sozinha se cair)..."
if ! bash "${GATEWAY}/enable-agent.sh" "${ASSISTENTE_SLUG}"; then
    erro "Falha no enable-agent.sh. Confira a mensagem acima."
    exit 1
fi

# =============================================================================
#  FIM — Instruções
# =============================================================================
titulo "Pronto! A ${ASSISTENTE} está no ar 💎"

echo -e "  ${BOLD}Como conversar:${NC}"
[[ "${TELEGRAM_ON}" == "true" ]] && info "  • Telegram: mande uma mensagem pro seu bot."
[[ "${WHATSAPP_ON}" == "true" ]] && info "  • WhatsApp: leia o QR Code (veja o log abaixo) e mande mensagem."
echo ""

echo -e "  ${BOLD}Onde editar a personalidade dela:${NC}"
info "  • ${AGENT_DIR}/SOUL.md     (quem ela é, tom, regras)"
info "  • ${AGENT_DIR}/CLAUDE.md   (o que ela sabe fazer, sua rotina)"
info "  Depois de editar, reinicie:  bash gateway/enable-agent.sh ${ASSISTENTE_SLUG} --restart"
echo ""

echo -e "  ${BOLD}Comandos do dia a dia:${NC}"
info "  • Ligar:     bash gateway/enable-agent.sh ${ASSISTENTE_SLUG}"
info "  • Reiniciar: bash gateway/enable-agent.sh ${ASSISTENTE_SLUG} --restart"
info "  • Desligar:  bash gateway/disable-agent.sh ${ASSISTENTE_SLUG}"
info "  • Status:    bash gateway/gateway-health.sh"
info "  • Ver ao vivo: tmux attach -t crm-${CRM_INSTANCE_ID}-${ASSISTENTE_SLUG}   (saia com Ctrl-b depois d)"
echo ""

if [[ "${WHATSAPP_ON}" == "true" ]]; then
    echo -e "  ${BOLD}QR Code do WhatsApp (primeiro boot):${NC}"
    info "  tail -f ~/.claude-remote/${CRM_INSTANCE_ID}/logs/${ASSISTENTE_SLUG}/whatsapp-bridge.log"
    echo ""
fi

info "Qualquer dúvida, fale com o suporte da Aliança de Ouro."
echo ""
