#!/usr/bin/env bash
# detect-platform.sh — Cross-platform OS detection for the Message Gateway
# Exports CRM_PLATFORM: darwin | linux | windows
#
# Usage (source):
#   source "$(dirname "$0")/detect-platform.sh"
#   echo "${CRM_PLATFORM}"
#
# Usage (standalone):
#   bash detect-platform.sh   # prints platform name
#
# Story 114.24 — Cross-Platform Persistence

detect_platform() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        Darwin*)  echo "darwin"  ;;
        Linux*)   echo "linux"   ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT*)
                  echo "windows" ;;
        *)
            # Fallback: check OSTYPE
            case "${OSTYPE:-}" in
                darwin*)  echo "darwin"  ;;
                linux*)   echo "linux"   ;;
                msys*|cygwin*|win32*)
                          echo "windows" ;;
                *)        echo "unknown" ;;
            esac
            ;;
    esac
}

CRM_PLATFORM="$(detect_platform)"
export CRM_PLATFORM

# When run standalone, print the platform
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "${CRM_PLATFORM}"
fi
