#!/usr/bin/env bash
# reminder-check.sh — Lembretes PONTUAIS (one-time) da Prisma
#
# O /loop do runtime so faz tarefas RECORRENTES (intervalo fixo). Lembretes
# pontuais ("me lembra amanha as 15h", "daqui 30 min") precisam disparar UMA
# vez num horario exato. Este script resolve isso com um arquivo de estado +
# um cron curto que chama "check" a cada minuto.
#
# COMO FUNCIONA
#   1. A Prisma registra o lembrete:   reminder-check.sh add <fire_at> <channel> <chat_id> "<texto>"
#   2. Um cron de 1 min roda:          reminder-check.sh check
#      - se nada venceu -> imprime nada (silencio)
#      - se algo venceu -> imprime os lembretes DEVIDOS e os marca como disparados
#   3. A Prisma le a saida do "check" e entrega cada lembrete pelo canal de origem.
#
# Por que assim e nao um "at"/"sleep"? Porque sobrevive a restart da maquina:
# o estado fica em disco (lembretes.json) e o cron e recriado do config.json no
# boot. Nenhum processo precisa ficar "dormindo" esperando a hora chegar.
#
# ESTADO: ${CRM_ROOT}/state/${AGENT}/lembretes.json  (gitignored via **/state/)
#
# USO
#   reminder-check.sh add <fire_at_epoch_ou_ISO> <channel> <chat_id> "<texto>"
#   reminder-check.sh check                 # imprime e marca os que venceram
#   reminder-check.sh list                  # lista os pendentes (humano)
#   reminder-check.sh cancel <id>           # cancela um lembrete pendente
#   reminder-check.sh prune                 # remove disparados com +7 dias
#
# <fire_at> aceita:
#   - epoch unix (ex: 1717520400)
#   - ISO 8601   (ex: 2026-06-05T15:00:00  ou  "2026-06-05 15:00")
#
# Requer: jq, date (GNU ou BSD). Testado em Linux/Mac/WSL.

set -uo pipefail

ACTION="${1:-check}"
shift 2>/dev/null || true

# --- Resolucao de caminhos (mesmo padrao dos outros scripts do core) ---
AGENT="${CRM_AGENT_NAME:-prisma}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

STATE_DIR="${CRM_ROOT}/state/${AGENT}"
STATE_FILE="${STATE_DIR}/lembretes.json"
BUS_DIR="${TEMPLATE_ROOT}/core/bus"

mkdir -p "${STATE_DIR}" 2>/dev/null || true

# Garante que o arquivo de estado existe e e um JSON valido (array vazio)
if [[ ! -s "${STATE_FILE}" ]]; then
    echo "[]" > "${STATE_FILE}"
fi

# --- Helper: converte <fire_at> (epoch ou ISO) para epoch unix ---
# Funciona com GNU date (Linux) e BSD date (Mac). Retorna "" se nao parsear.
to_epoch() {
    local input="$1"
    # Ja e epoch (so digitos)?
    if [[ "${input}" =~ ^[0-9]+$ ]]; then
        echo "${input}"
        return 0
    fi
    # Tenta GNU date (Linux/WSL)
    local out
    out=$(date -d "${input}" +%s 2>/dev/null) && { echo "${out}"; return 0; }
    # Tenta BSD date (Mac) com alguns formatos comuns
    for fmt in "%Y-%m-%dT%H:%M:%S" "%Y-%m-%d %H:%M:%S" "%Y-%m-%dT%H:%M" "%Y-%m-%d %H:%M"; do
        out=$(date -j -f "${fmt}" "${input}" +%s 2>/dev/null) && { echo "${out}"; return 0; }
    done
    echo ""
    return 1
}

# --- Helper: epoch -> string legivel (para confirmacoes/listagem) ---
human_time() {
    local epoch="$1"
    date -d "@${epoch}" "+%Y-%m-%d %H:%M" 2>/dev/null \
        || date -r "${epoch}" "+%Y-%m-%d %H:%M" 2>/dev/null \
        || echo "${epoch}"
}

NOW="$(date +%s)"

case "${ACTION}" in
    # =========================================================
    # add — registra um lembrete pontual
    # =========================================================
    add)
        FIRE_AT_RAW="${1:-}"
        CHANNEL="${2:-}"
        CHAT_ID="${3:-}"
        TEXT="${4:-}"

        if [[ -z "${FIRE_AT_RAW}" || -z "${CHANNEL}" || -z "${CHAT_ID}" || -z "${TEXT}" ]]; then
            echo "ERRO: uso: reminder-check.sh add <fire_at> <channel> <chat_id> \"<texto>\"" >&2
            exit 1
        fi

        FIRE_AT="$(to_epoch "${FIRE_AT_RAW}")"
        if [[ -z "${FIRE_AT}" ]]; then
            echo "ERRO: nao consegui interpretar a data/hora '${FIRE_AT_RAW}'. Use epoch unix ou ISO (2026-06-05T15:00)." >&2
            exit 1
        fi

        # id curto e unico
        ID="lmb-$(date +%s)-$$"

        # Anexa ao array de forma atomica (jq -> tmp -> mv)
        TMP="$(mktemp "${STATE_DIR}/.lembretes-XXXXXX.json" 2>/dev/null || mktemp)"
        jq \
            --arg id "${ID}" \
            --argjson fire_at "${FIRE_AT}" \
            --arg channel "${CHANNEL}" \
            --arg chat_id "${CHAT_ID}" \
            --arg text "${TEXT}" \
            --argjson created "${NOW}" \
            '. += [{id:$id, fire_at:$fire_at, channel:$channel, chat_id:$chat_id, text:$text, status:"pending", created:$created}]' \
            "${STATE_FILE}" > "${TMP}" && mv "${TMP}" "${STATE_FILE}"

        echo "OK ${ID} agendado para $(human_time "${FIRE_AT}")"
        ;;

    # =========================================================
    # check — imprime e marca os lembretes que VENCERAM
    # (e isto que o cron de 1 min chama)
    # =========================================================
    check)
        # Lembretes pendentes com fire_at <= agora
        DUE="$(jq -c --argjson now "${NOW}" \
            '[.[] | select(.status=="pending" and .fire_at <= $now)]' \
            "${STATE_FILE}" 2>/dev/null || echo "[]")"

        COUNT="$(echo "${DUE}" | jq 'length' 2>/dev/null || echo 0)"
        if [[ "${COUNT}" -eq 0 ]]; then
            # Nada venceu -> silencio total (o cron nao notifica nada)
            exit 0
        fi

        # Imprime instrucoes claras para a Prisma entregar cada lembrete
        echo "LEMBRETES_DEVIDOS=${COUNT}"
        echo "${DUE}" | jq -r '.[] | "ENTREGAR id=\(.id) canal=\(.channel) chat_id=\(.chat_id) texto=\(.text)"'

        # Marca todos os devidos como "fired" (atomico)
        TMP="$(mktemp "${STATE_DIR}/.lembretes-XXXXXX.json" 2>/dev/null || mktemp)"
        jq --argjson now "${NOW}" \
            'map(if (.status=="pending" and .fire_at <= $now) then (.status="fired" | .fired_at=$now) else . end)' \
            "${STATE_FILE}" > "${TMP}" && mv "${TMP}" "${STATE_FILE}"
        ;;

    # =========================================================
    # list — lista pendentes (consumo humano / Prisma)
    # =========================================================
    list)
        PENDING="$(jq -c '[.[] | select(.status=="pending")]' "${STATE_FILE}" 2>/dev/null || echo "[]")"
        COUNT="$(echo "${PENDING}" | jq 'length' 2>/dev/null || echo 0)"
        if [[ "${COUNT}" -eq 0 ]]; then
            echo "Nenhum lembrete pontual pendente."
            exit 0
        fi
        # Usa TAB como separador (improvavel no texto) e converte epoch->humano no loop
        echo "${PENDING}" | jq -r '.[] | "\(.id)\t\(.fire_at)\t\(.text)"' | while IFS=$'\t' read -r ID EP TX; do
            echo "${ID}  ->  $(human_time "${EP}")  ->  ${TX}"
        done
        ;;

    # =========================================================
    # cancel — cancela um lembrete pendente pelo id
    # =========================================================
    cancel)
        ID="${1:-}"
        if [[ -z "${ID}" ]]; then
            echo "ERRO: uso: reminder-check.sh cancel <id>" >&2
            exit 1
        fi
        TMP="$(mktemp "${STATE_DIR}/.lembretes-XXXXXX.json" 2>/dev/null || mktemp)"
        BEFORE="$(jq 'length' "${STATE_FILE}")"
        jq --arg id "${ID}" 'map(select(.id != $id))' "${STATE_FILE}" > "${TMP}" && mv "${TMP}" "${STATE_FILE}"
        AFTER="$(jq 'length' "${STATE_FILE}")"
        if [[ "${BEFORE}" != "${AFTER}" ]]; then
            echo "OK lembrete ${ID} cancelado."
        else
            echo "Nao achei lembrete com id ${ID}."
        fi
        ;;

    # =========================================================
    # prune — limpa disparados com mais de 7 dias (higiene)
    # =========================================================
    prune)
        CUTOFF=$((NOW - 7*24*3600))
        TMP="$(mktemp "${STATE_DIR}/.lembretes-XXXXXX.json" 2>/dev/null || mktemp)"
        jq --argjson cutoff "${CUTOFF}" \
            'map(select(.status != "fired" or (.fired_at // 0) > $cutoff))' \
            "${STATE_FILE}" > "${TMP}" && mv "${TMP}" "${STATE_FILE}"
        echo "OK lembretes disparados com +7 dias removidos."
        ;;

    *)
        echo "Uso: reminder-check.sh {add|check|list|cancel|prune} [args...]" >&2
        exit 1
        ;;
esac
