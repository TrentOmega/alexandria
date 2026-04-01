#!/bin/bash

ANNAS_ARCHIVE_USER_AGENT="${ANNAS_ARCHIVE_USER_AGENT:-Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36}"
AA_CURL_ARGS=()

aa_log_line() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

aa_load_env() {
    local base_dir="${1:-}"

    if [ -n "$base_dir" ] && [ -f "$base_dir/.env" ]; then
        set -a
        source "$base_dir/.env"
        set +a
    fi

    AA_CURL_ARGS=(-A "$ANNAS_ARCHIVE_USER_AGENT")

    if [ -n "${ANNAS_ARCHIVE_KEY:-}" ]; then
        AA_CURL_ARGS+=(-H "Authorization: Bearer $ANNAS_ARCHIVE_KEY")
    fi

    if [ -n "${ANNAS_ARCHIVE_COOKIE_JAR:-}" ]; then
        AA_CURL_ARGS+=(-b "$ANNAS_ARCHIVE_COOKIE_JAR" -c "$ANNAS_ARCHIVE_COOKIE_JAR")
    fi
}

aa_validate_setup() {
    if [ -n "${ANNAS_ARCHIVE_COOKIE_JAR:-}" ] && [ ! -r "${ANNAS_ARCHIVE_COOKIE_JAR}" ]; then
        aa_log_line "ERROR: ANNAS_ARCHIVE_COOKIE_JAR is set but not readable: ${ANNAS_ARCHIVE_COOKIE_JAR}"
        aa_log_line "Export Anna's Archive cookies from Firefox to a Netscape cookie file and point ANNAS_ARCHIVE_COOKIE_JAR at it."
        return 1
    fi

    return 0
}

aa_describe_request_context() {
    if [ -n "${ANNAS_ARCHIVE_KEY:-}" ]; then
        aa_log_line "Using authenticated requests"
    fi

    if [ -n "${ANNAS_ARCHIVE_COOKIE_JAR:-}" ]; then
        aa_log_line "Using browser cookie jar: ${ANNAS_ARCHIVE_COOKIE_JAR}"
    fi
}

aa_curl() {
    curl "${AA_CURL_ARGS[@]}" "$@"
}

aa_is_challenge_text() {
    printf '%s' "$1" | grep -Eiq 'ddos-guard|checking your browser|captcha|attention required|enable javascript|challenge'
}

aa_is_challenge_file() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        return 1
    fi

    grep -Eiq 'ddos-guard|checking your browser|captcha|attention required|enable javascript|challenge' "$file_path" && return 0
    head -c 2048 "$file_path" | grep -aEiq '<!DOCTYPE html|<html|<head|<body' && return 0
    return 1
}

aa_print_challenge_help() {
    local context="$1"

    aa_log_line "ERROR: DDoS-Guard blocked the request while ${context}"
    if [ -n "${ANNAS_ARCHIVE_COOKIE_JAR:-}" ]; then
        aa_log_line "The current cookie jar did not bypass the challenge."
        aa_log_line "Refresh the Anna's Archive page in Firefox, export cookies again, and retry."
    else
        aa_log_line "Pass the challenge in Firefox, export the site cookies, and set ANNAS_ARCHIVE_COOKIE_JAR=/path/to/cookies.txt in .env."
    fi
}

aa_exit_on_challenge_text() {
    local response_text="$1"
    local context="$2"

    if aa_is_challenge_text "$response_text"; then
        aa_print_challenge_help "$context"
        exit 2
    fi
}

aa_exit_on_challenge_file() {
    local file_path="$1"
    local context="$2"

    if aa_is_challenge_file "$file_path"; then
        aa_print_challenge_help "$context"
        exit 2
    fi
}
