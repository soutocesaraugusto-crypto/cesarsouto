# ─────────────────────────────────────────────────────────────────────────────
# Preparação de ambiente do Gerador de áudios de Omniterapia — Windows
# Chamado pela skill /audio-motivacao. Instala o que falta (Node, ffmpeg),
# as dependências e cria o .env. NÃO sobe o servidor (a skill faz isso).
# ─────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
$AppRoot = Split-Path -Parent $PSScriptRoot
Set-Location $AppRoot

function Ok($m)   { Write-Host "  [OK] $m"   -ForegroundColor Green }
function Info($m) { Write-Host "  $m"        -ForegroundColor Gray }
function Warn($m) { Write-Host "  [!] $m"    -ForegroundColor Yellow }
function Step($m) { Write-Host "`n> $m"      -ForegroundColor Cyan }

function Refresh-Path {
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
}
function Has($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Write-Host ""
Write-Host "===========================================" -ForegroundColor DarkYellow
Write-Host "  OMNI - Gerador de audios de Omniterapia"   -ForegroundColor Yellow
Write-Host "  Instalacao automatica"                     -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor DarkYellow

$hasWinget = Has "winget"

# ── Node.js ──────────────────────────────────────────────────────────────────
Step "Verificando Node.js"
if (Has "node") {
  Ok "Node ja instalado ($(node --version))"
} elseif ($hasWinget) {
  Info "Instalando Node.js (LTS) via winget..."
  winget install --id OpenJS.NodeJS.LTS -e --silent --accept-source-agreements --accept-package-agreements
  Refresh-Path
  if (Has "node") { Ok "Node instalado ($(node --version))" }
  else { Warn "Node instalado, mas pode ser preciso reabrir. Feche esta janela e rode o INSTALAR de novo." }
} else {
  Warn "Node nao encontrado e o winget nao esta disponivel."
  Warn "Instale o Node manualmente em https://nodejs.org (versao LTS) e rode o INSTALAR de novo."
  Read-Host "Pressione ENTER para sair"; exit 1
}

# ── ffmpeg ───────────────────────────────────────────────────────────────────
Step "Verificando ffmpeg (montagem do audio)"
if (Has "ffmpeg") {
  Ok "ffmpeg ja instalado"
} elseif ($hasWinget) {
  Info "Instalando ffmpeg via winget..."
  winget install --id Gyan.FFmpeg -e --silent --accept-source-agreements --accept-package-agreements
  Refresh-Path
  if (Has "ffmpeg") { Ok "ffmpeg instalado" }
  else { Warn "ffmpeg instalado, mas o sistema pode precisar reabrir. Feche tudo e rode o INSTALAR de novo." }
} else {
  Warn "ffmpeg nao encontrado e o winget nao esta disponivel."
  Warn "Baixe em https://www.gyan.dev/ffmpeg/builds/ e adicione ao PATH, depois rode o INSTALAR de novo."
}

# ── Dependencias do app ──────────────────────────────────────────────────────
Step "Instalando dependencias do app (npm install)"
if (Test-Path "package-lock.json") { npm ci } else { npm install }
Ok "Dependencias instaladas"

# ── Arquivo de configuracao ──────────────────────────────────────────────────
Step "Preparando configuracao (.env)"
if (-not (Test-Path ".env")) {
  Copy-Item ".env.example" ".env"
  Ok ".env criado (as chaves voce coloca na tela que vai abrir)"
} else {
  Ok ".env ja existe"
}

Write-Host ""
Write-Host "  Ambiente pronto." -ForegroundColor Green
Write-Host ""
