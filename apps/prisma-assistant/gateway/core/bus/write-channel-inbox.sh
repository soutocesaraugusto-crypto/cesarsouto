#!/usr/bin/env bash
# write-channel-inbox.sh — Atomic write of normalized messages to channel-inbox/
#
# Adapters call this to write messages in the adapter-message schema.
# Messages are picked up by fast-checker.sh in ADAPTER_MODE.
#
# Usage:
#   write-channel-inbox.sh <agent> <json_message>
#   echo '{"_source":"telegram",...}' | write-channel-inbox.sh <agent>
#
# The JSON must conform to core/schemas/adapter-message.schema.json.
# Required fields: _source, _type, _timestamp, platform, chat_id, from, text
#
# Output: filename written (for ACK tracking)
#
# Epic 110 / Story 110.27 Phase 1

set -uo pipefail

AGENT="${1:-}"
JSON_MSG="${2:-}"

# Read from stdin if no second argument
if [[ -z "${JSON_MSG}" ]]; then
    JSON_MSG=$(cat)
fi

if [[ -z "${AGENT}" || -z "${JSON_MSG}" ]]; then
    echo "Usage: write-channel-inbox.sh <agent> '<json>'" >&2
    echo "   or: echo '<json>' | write-channel-inbox.sh <agent>" >&2
    exit 1
fi

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
INBOX_DIR="${CRM_ROOT}/channel-inbox/${AGENT}"

mkdir -p "${INBOX_DIR}" 2>/dev/null || true

# Validate required fields
REQUIRED_FIELDS=("_source" "_type" "_timestamp" "platform" "chat_id" "from" "text")
for field in "${REQUIRED_FIELDS[@]}"; do
    VAL=$(echo "${JSON_MSG}" | jq -r ".${field} // empty" 2>/dev/null)
    if [[ -z "${VAL}" ]]; then
        echo "ERROR: Missing required field '${field}' in message JSON" >&2
        exit 1
    fi
done

# Generate filename: {epoch_ms}-{source}-{random}.json
SOURCE=$(echo "${JSON_MSG}" | jq -r '._source' 2>/dev/null)
EPOCH_MS=$(date +%s%N 2>/dev/null | cut -c1-13 || date +%s)
RAND=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
FILENAME="${EPOCH_MS}-${SOURCE}-${RAND}.json"

# Atomic write: tempfile + rename (prevents partial reads by fast-checker)
TMPFILE=$(mktemp "${INBOX_DIR}/.tmp-XXXXXX" 2>/dev/null) || {
    echo "ERROR: Failed to create temp file in ${INBOX_DIR}" >&2
    exit 1
}
chmod 600 "${TMPFILE}"
printf '%s\n' "${JSON_MSG}" > "${TMPFILE}"
mv "${TMPFILE}" "${INBOX_DIR}/${FILENAME}"

echo "${FILENAME}"
