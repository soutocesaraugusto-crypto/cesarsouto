#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Preparação de ambiente do Gerador de áudios de Omniterapia — Mac / Linux
# Chamado pela skill /audio-motivacao. Instala o que falta (Node, ffmpeg),
# as dependências e cria o .env. NÃO sobe o servidor (a skill faz isso).
# ─────────────────────────────────────────────────────────────────────────────
set -e

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_ROOT"

green(){ printf "  \033[32m[OK]\033[0m %s\n" "$1"; }
info(){  printf "  %s\n" "$1"; }
warn(){  printf "  \033[33m[!]\033[0m %s\n" "$1"; }
step(){  printf "\n\033[36m> %s\033[0m\n" "$1"; }

OS="$(uname -s)"
has(){ command -v "$1" >/dev/null 2>&1; }

echo ""
echo "==========================================="
echo "  OMNI - Gerador de audios de Omniterapia"
echo "  Instalacao automatica"
echo "==========================================="

# ── Homebrew (Mac, se necessário) ────────────────────────────────────────────
if [ "$OS" = "Darwin" ] && ! has brew; then
  step "Instalando Homebrew (gerenciador de programas)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # adiciona o brew ao PATH desta sessão (Apple Silicon e Intel)
  [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
fi

# ── Node.js ──────────────────────────────────────────────────────────────────
step "Verificando Node.js"
if has node; then
  green "Node ja instalado ($(node --version))"
elif [ "$OS" = "Darwin" ] && has brew; then
  info "Instalando Node via Homebrew..."
  brew install node
  green "Node instalado ($(node --version))"
else
  warn "Node nao encontrado. Instale em https://nodejs.org (versao LTS) e rode de novo."
  read -r -p "Pressione ENTER para sair" _; exit 1
fi

# ── ffmpeg ───────────────────────────────────────────────────────────────────
step "Verificando ffmpeg (montagem do audio)"
if has ffmpeg; then
  green "ffmpeg ja instalado"
elif [ "$OS" = "Darwin" ] && has brew; then
  info "Instalando ffmpeg via Homebrew..."
  brew install ffmpeg
  green "ffmpeg instalado"
else
  warn "ffmpeg nao encontrado. No Linux: 'sudo apt install ffmpeg'. Depois rode de novo."
fi

# ── Dependencias do app ──────────────────────────────────────────────────────
step "Instalando dependencias do app (npm install)"
if [ -f package-lock.json ]; then npm ci; else npm install; fi
green "Dependencias instaladas"

# ── Arquivo de configuracao ──────────────────────────────────────────────────
step "Preparando configuracao (.env)"
if [ ! -f .env ]; then
  cp .env.example .env
  green ".env criado (as chaves voce coloca na tela que vai abrir)"
else
  green ".env ja existe"
fi

echo ""
echo "  Ambiente pronto."
echo ""
