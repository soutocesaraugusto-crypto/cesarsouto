#!/usr/bin/env bash
# _media-extractor.sh — Extract media references from response text
# Hermes pattern: extract_images(), extract_media(), extract_local_files()
#
# Detects:
#   1. Markdown images: ![alt](url) or ![alt](/path/to/file.png)
#   2. MEDIA: directives: MEDIA:/path/to/file
#   3. Bare local file paths: /path/to/image.png (validated with -f)
#
# Usage: source this file, then call:
#   extract_and_send_media "$CHAT_ID" "$RESPONSE_TEXT" "$PLATFORM"
#   → sends extracted media via send-channel.sh
#   → outputs cleaned text (media references removed)
#
# Epic 110 / Story 110.29 Phase 2

# Supported media extensions (case-insensitive match)
_MEDIA_EXTENSIONS="jpg|jpeg|png|gif|webp|svg|bmp|tiff|mp4|webm|mov|mp3|ogg|wav|pdf|doc|docx"

# Extract markdown images ![alt](path_or_url) and return cleaned text
# Outputs: lines of "PATH<tab>CAPTION" to stdout, cleaned text to fd 3
extract_markdown_images() {
    local text="$1"
    local images=""
    local cleaned="$text"

    # Match ![caption](path) — but NOT inside code blocks
    # Simple approach: process line by line, skip lines inside ``` fences
    local in_fence=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\` ]]; then
            $in_fence && in_fence=false || in_fence=true
            continue
        fi
        $in_fence && continue

        # Extract ![alt](path) using grep (bash regex can't handle nested brackets)
        while read -r match; do
            [[ -z "$match" ]] && continue
            local caption path
            caption=$(echo "$match" | sed -E 's/^!\[([^]]*)\].*/\1/')
            path=$(echo "$match" | sed -E 's/^!\[[^]]*\]\(([^)]+)\)/\1/')
            # Only extract if it's a local file path (starts with / or ~)
            if [[ "$path" =~ ^[/~] ]] && [[ -f "$(eval echo "$path" 2>/dev/null)" ]]; then
                images+="${path}"$'\t'"${caption}"$'\n'
                cleaned="${cleaned//${match}/}"
            fi
        done < <(echo "$line" | grep -oE '!\[[^]]*\]\([^)]+\)' 2>/dev/null)
    done <<< "$text"

    printf '%s' "$images"
    # Cleaned text available via: cleaned=$(extract_...; echo "$text" minus images)
    export _CLEANED_TEXT="$cleaned"
}

# Extract MEDIA:/path/to/file directives
extract_media_directives() {
    local text="$1"
    local media=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^MEDIA:(.+)$ ]]; then
            local path="${BASH_REMATCH[1]}"
            path=$(echo "$path" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [[ -f "$path" ]]; then
                media+="${path}"$'\t'""$'\n'
            fi
        fi
    done <<< "$text"

    printf '%s' "$media"
}

# Extract bare local file paths ending in media extensions
extract_local_files() {
    local text="$1"
    local files=""
    local in_fence=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\` ]]; then
            $in_fence && in_fence=false || in_fence=true
            continue
        fi
        $in_fence && continue
        # Skip inline code
        [[ "$line" =~ ^\`.*\`$ ]] && continue

        # Find paths ending in media extensions
        while read -r match; do
            [[ -z "$match" ]] && continue
            # Expand tilde
            local expanded
            expanded=$(eval echo "$match" 2>/dev/null || echo "$match")
            if [[ -f "$expanded" ]]; then
                files+="${expanded}"$'\t'""$'\n'
            fi
        done < <(echo "$line" | grep -oE "[/~][^ \"'<>]+\.(${_MEDIA_EXTENSIONS})" 2>/dev/null)
    done <<< "$text"

    printf '%s' "$files"
}

# Main function: extract all media from text and send natively
# Usage: extract_and_send_media <chat_id> <text> <platform>
# Outputs: cleaned text (media references removed)
extract_and_send_media() {
    local chat_id="$1"
    local text="$2"
    local platform="${3:-telegram}"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 1. Extract markdown images
    local md_images
    md_images=$(extract_markdown_images "$text")
    local cleaned="${_CLEANED_TEXT:-$text}"

    # 2. Extract MEDIA: directives
    local media_dirs
    media_dirs=$(extract_media_directives "$cleaned")

    # 3. Extract bare local file paths
    local bare_files
    bare_files=$(extract_local_files "$cleaned")

    # 4. Combine and deduplicate
    local all_media
    all_media=$(printf '%s\n%s\n%s' "$md_images" "$media_dirs" "$bare_files" | sort -u)

    # 5. Send each media file natively
    while IFS=$'\t' read -r path caption; do
        [[ -z "$path" ]] && continue
        [[ ! -f "$path" ]] && continue

        # Determine media type from extension
        local ext
        ext=$(echo "${path##*.}" | tr '[:upper:]' '[:lower:]')

        case "$ext" in
            jpg|jpeg|png|gif|webp|bmp|tiff|svg)
                bash "${script_dir}/send-channel.sh" "${platform}" "${chat_id}" "${caption:-Image}" --image "$path" 2>/dev/null || true
                # Remove the path reference from cleaned text
                cleaned=$(echo "$cleaned" | sed "s|${path}||g" | sed "s|MEDIA:${path}||g")
                ;;
            mp4|webm|mov)
                # Video — send as document for now (native video requires separate API)
                bash "${script_dir}/send-channel.sh" "${platform}" "${chat_id}" "${caption:-Video}: ${path}" 2>/dev/null || true
                ;;
            mp3|ogg|wav)
                # Audio — send as document
                bash "${script_dir}/send-channel.sh" "${platform}" "${chat_id}" "${caption:-Audio}: ${path}" 2>/dev/null || true
                ;;
            pdf|doc|docx)
                # Document — send path reference
                bash "${script_dir}/send-channel.sh" "${platform}" "${chat_id}" "${caption:-Document}: ${path}" 2>/dev/null || true
                ;;
        esac
    done <<< "$all_media"

    # 6. Output cleaned text (remove empty lines from extraction)
    printf '%s' "$cleaned" | sed '/^[[:space:]]*$/d'
}
