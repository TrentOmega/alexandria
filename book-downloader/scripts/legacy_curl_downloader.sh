#!/bin/bash
# Legacy curl-based Anna's Archive downloader.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${2:-${HOME}/Downloads}"
TMP_FILES=()

mkdir -p "$OUTPUT_DIR"

source "$SCRIPT_DIR/common.sh"
aa_load_env "$SKILL_DIR"
aa_validate_setup || exit 1

cleanup() {
    if [ "${#TMP_FILES[@]}" -gt 0 ]; then
        rm -f "${TMP_FILES[@]}" 2>/dev/null || true
    fi
}

trap cleanup EXIT

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

add_tmp_file() {
    TMP_FILES+=("$1")
}

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 \"book query\" [output_dir]"
    exit 1
fi

QUERY="$1"

get_md5_from_url() {
    echo "$1" | grep -o '/md5/[a-f0-9]*' | cut -d'/' -f3
}

get_fast_download_url() {
    local url="$1"
    local domain md5

    domain=$(echo "$url" | sed -n 's|https\?://\([^/]*\)/.*|\1|p')
    md5=$(get_md5_from_url "$url")

    if [ -n "$domain" ] && [ -n "$md5" ]; then
        echo "https://${domain}/fast_download/${md5}/0/0"
    fi
}

normalize_url() {
    local base_url="$1"
    local raw_url="$2"
    local domain

    case "$raw_url" in
        http://*|https://*)
            echo "$raw_url"
            ;;
        //*)
            echo "https:${raw_url}"
            ;;
        /*)
            domain=$(echo "$base_url" | sed -n 's|https\?://\([^/]*\)/.*|\1|p')
            echo "https://${domain}${raw_url}"
            ;;
        *)
            echo "${base_url%/*}/${raw_url}"
            ;;
    esac
}

fetch_page() {
    local url="$1"
    local output_file="$2"

    aa_curl -sS -L --connect-timeout 15 --max-time 60 \
        -o "$output_file" \
        "$url"
}

extract_download_link_from_file() {
    local page_file="$1"
    local base_url="$2"
    local href

    href=$(grep -oE 'https?://[^"<>[:space:]]+\.(pdf|epub)(\?[^"<>[:space:]]*)?' "$page_file" | head -1)
    if [ -n "$href" ]; then
        echo "$href"
        return 0
    fi

    href=$(grep -oE 'href="[^"]+\.(pdf|epub)(\?[^"]*)?"' "$page_file" | head -1 | cut -d'"' -f2)
    if [ -n "$href" ]; then
        normalize_url "$base_url" "$href"
        return 0
    fi

    return 1
}

resolve_download_url_from_detail() {
    local detail_url="$1"
    local detail_page member_path member_url mirrors_page redirect_path resolved_url

    detail_page="$(mktemp)"
    add_tmp_file "$detail_page"

    if ! fetch_page "$detail_url" "$detail_page"; then
        return 1
    fi

    aa_exit_on_challenge_file "$detail_page" "fetching detail page ${detail_url}"

    member_path=$(grep -o 'href="/member_codes[^"]*"' "$detail_page" | head -1 | cut -d'"' -f2)
    if [ -n "$member_path" ]; then
        member_url=$(normalize_url "$detail_url" "$member_path")
        mirrors_page="$(mktemp)"
        add_tmp_file "$mirrors_page"

        if fetch_page "$member_url" "$mirrors_page"; then
            aa_exit_on_challenge_file "$mirrors_page" "fetching mirror selection page ${member_url}"
            if grep -Eiq 'ddos-guard|checking your browser|challenge' "$mirrors_page"; then
                redirect_path=$(grep -o 'href="[^"]*"' "$mirrors_page" | cut -d'"' -f2 | grep '/codes/' | head -1)
                if [ -n "$redirect_path" ]; then
                    fetch_page "$(normalize_url "$member_url" "$redirect_path")" "$mirrors_page" || true
                    aa_exit_on_challenge_file "$mirrors_page" "following mirror redirect from ${member_url}"
                fi
            fi

            resolved_url=$(extract_download_link_from_file "$mirrors_page" "$member_url" || true)
            if [ -n "$resolved_url" ]; then
                echo "$resolved_url"
                return 0
            fi
        fi
    fi

    resolved_url=$(extract_download_link_from_file "$detail_page" "$detail_url" || true)
    if [ -n "$resolved_url" ]; then
        echo "$resolved_url"
        return 0
    fi

    return 1
}

is_html_response() {
    local file_path="$1"
    local headers_file="$2"
    local final_content_type

    final_content_type=$(awk 'BEGIN{IGNORECASE=1} /^content-type:/ {line=$0} END {print line}' "$headers_file")

    if echo "$final_content_type" | grep -Eiq 'text/html'; then
        return 0
    fi

    if head -c 1024 "$file_path" | grep -aEiq '<!DOCTYPE html|<html|<head|<body|ddos-guard|checking your browser|challenge'; then
        return 0
    fi

    return 1
}

detect_extension() {
    local url="$1"
    local headers_file="$2"
    local downloaded_file="$3"
    local final_content_type

    final_content_type=$(awk 'BEGIN{IGNORECASE=1} /^content-type:/ {line=$0} END {print line}' "$headers_file")

    if echo "$url" | grep -Eiq '\.epub(\?|$)'; then
        echo ".epub"
        return 0
    fi

    if echo "$final_content_type" | grep -Eiq 'application/epub\+zip'; then
        echo ".epub"
        return 0
    fi

    if echo "$final_content_type" | grep -Eiq 'application/pdf'; then
        echo ".pdf"
        return 0
    fi

    if head -c 4 "$downloaded_file" | grep -aq '^PK'; then
        echo ".epub"
        return 0
    fi

    echo ".pdf"
}

clean_filename() {
    echo "$1" | tr -cd '[:alnum:] [:space:]_-' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//' | tr ' ' '_' | cut -c1-80
}

download_candidate() {
    local source_url="$1"
    local title="$2"
    local temp_file headers_file final_ext final_name final_path file_size

    temp_file="$(mktemp)"
    headers_file="$(mktemp)"
    add_tmp_file "$temp_file"
    add_tmp_file "$headers_file"

    echo "Trying download URL: $source_url"

    if ! aa_curl -L --connect-timeout 30 --max-time 300 \
        -D "$headers_file" \
        -o "$temp_file" \
        "$source_url" \
        --progress-bar; then
        echo ""
        log "Download request failed for: $source_url"
        return 1
    fi

    if is_html_response "$temp_file" "$headers_file"; then
        echo ""
        log "Resolved URL returned HTML instead of a book file"
        return 1
    fi

    file_size=$(stat -c%s "$temp_file" 2>/dev/null || echo "0")
    if [ "$file_size" -lt 1024 ]; then
        echo ""
        log "Downloaded file is too small to be a valid book: ${file_size} bytes"
        return 1
    fi

    final_ext=$(detect_extension "$source_url" "$headers_file" "$temp_file")
    final_name="$(clean_filename "$title")${final_ext}"
    [ -z "$final_name" ] && final_name="book${final_ext}"
    final_path="${OUTPUT_DIR}/${final_name}"

    mv -f "$temp_file" "$final_path"
    echo ""
    echo "✓ Downloaded successfully: $final_name ($(ls -lh "$final_path" | awk '{print $5}'))"
    echo "Location: $OUTPUT_DIR/"
    return 0
}

OUTPUT=$("$SCRIPT_DIR/smart_finder.sh" "$QUERY" "$OUTPUT_DIR" 2>&1)
EXIT_CODE=$?

echo "$OUTPUT"

if [ $EXIT_CODE -ne 0 ]; then
    exit $EXIT_CODE
fi

DETAIL_URL=$(echo "$OUTPUT" | sed -n 's/^Download link: //p' | tail -1)
TITLE=$(echo "$OUTPUT" | sed -n 's/^Found book: //p' | tail -1)
[ -z "$TITLE" ] && TITLE="book"

if [ -z "$DETAIL_URL" ]; then
    echo ""
    echo "✗ Download failed: no detail page URL was returned"
    exit 1
fi

RESOLVED_URL=$(resolve_download_url_from_detail "$DETAIL_URL" || true)
FAST_URL=$(get_fast_download_url "$DETAIL_URL")
CANDIDATES=()

if [ -n "$RESOLVED_URL" ]; then
    CANDIDATES+=("$RESOLVED_URL")
    echo ""
    echo "Resolved download URL: $RESOLVED_URL"
fi

if [ -n "$FAST_URL" ] && [ "$FAST_URL" != "$RESOLVED_URL" ]; then
    CANDIDATES+=("$FAST_URL")
    echo ""
    echo "Fallback fast download URL: $FAST_URL"
fi

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
    echo ""
    echo "✗ Download failed: could not resolve a direct PDF/EPUB link"
    echo "You can try downloading manually from: $DETAIL_URL"
    exit 1
fi

echo ""
echo "Destination: $OUTPUT_DIR/"

for candidate in "${CANDIDATES[@]}"; do
    if download_candidate "$candidate" "$TITLE"; then
        echo ""
        echo "MD5 link (for reference): $DETAIL_URL"
        exit 0
    fi
done

echo ""
echo "✗ Download failed: the resolved links returned HTML instead of a book file"
echo "You can try downloading manually from: $DETAIL_URL"
exit 1
