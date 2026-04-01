#!/bin/bash
# Download workflow with subscription key support
# Note: Key authenticates user but DDoS-Guard may still require browser

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
aa_load_env "$SCRIPT_DIR/.."
aa_validate_setup || exit 1

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

log() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

if [ -z "${ANNAS_ARCHIVE_KEY:-}" ]; then
    log "ERROR: No ANNAS_ARCHIVE_KEY found in .env"
    log "Please add your key to: $SCRIPT_DIR/../.env"
    exit 1
fi

log "Searching for: $QUERY"
aa_describe_request_context

# First, find the book using authenticated search
SEARCH_TERM=$(echo "$QUERY" | sed 's/ /+/g')
DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

for domain in $DOMAINS; do
    URL="https://${domain}/search?q=${SEARCH_TERM}"
    log "Searching: $domain"

    RESPONSE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$URL" 2>/dev/null)
    aa_exit_on_challenge_text "$RESPONSE" "searching ${URL}"

    if echo "$RESPONSE" | grep "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" >/dev/null 2>&1; then
        # Validate first few results
        PATHS=$(echo "$RESPONSE" | grep -o 'href="/md5/[^"]*"' | cut -d'"' -f2 | head -3)

        for PATH in $PATHS; do
            DETAIL_URL="https://${domain}${PATH}"

            # Get detail page with auth
            DETAIL_PAGE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$DETAIL_URL" 2>/dev/null)
            aa_exit_on_challenge_text "$DETAIL_PAGE" "fetching detail page ${DETAIL_URL}"

            TITLE=$(echo "$DETAIL_PAGE" | grep -i "<title>" | sed 's/.*<title>//;s/<\/title>.*//')

            # Validate title matches query
            VALID=true
            for WORD in $(echo "$QUERY" | tr ' ' '\n' | grep -v "the\|and\|for" | head -3); do
                if ! echo "$TITLE" | grep -i "$WORD" >/dev/null 2>&1; then
                    VALID=false
                    break
                fi
            done

            if [ "$VALID" = true ]; then
                log "✓ Found: $TITLE"
                log "Detail page: $DETAIL_URL"

                # Save info
                echo "$TITLE" > "${OUTPUT_DIR}/last_book_title.txt"
                echo "$DETAIL_URL" > "${OUTPUT_DIR}/last_book_link.txt"

                # Try to get member codes for download
                MEMBER_CODES=$(echo "$DETAIL_PAGE" | grep -o 'href="/member_codes[^"]*"' | head -1 | cut -d'"' -f2)

                if [ -n "$MEMBER_CODES" ]; then
                    log "Found member codes link: $MEMBER_CODES"

                    # Follow member codes (will redirect to /codes/)
                    CODES_URL="https://${domain}${MEMBER_CODES}"
                    log "Accessing download mirrors..."

                    # Note: Even with auth key, DDoS-Guard may block
                    # The key helps but doesn't bypass all protection
                    CODES_PAGE=$(aa_curl -sS -L --connect-timeout 15 --max-time 45 "$CODES_URL" 2>/dev/null)
                    aa_exit_on_challenge_text "$CODES_PAGE" "fetching mirror selection page ${CODES_URL}"

                    # Look for direct download links
                    DL_LINK=$(echo "$CODES_PAGE" | grep -oE 'https?://[^"<>\s]+\.(pdf|epub)' | head -1)

                    if [ -n "$DL_LINK" ]; then
                        log "Found direct download: $DL_LINK"

                        # Download the file
                        FILENAME=$(echo "$TITLE" | sed 's/[\/:*?"<>|]/_/g').pdf
                        OUTPUT_PATH="${OUTPUT_DIR}/${FILENAME}"

                        log "Downloading to: $OUTPUT_PATH"
                        aa_curl -L --connect-timeout 30 --max-time 300 -o "$OUTPUT_PATH" "$DL_LINK" 2>/dev/null

                        if [ -f "$OUTPUT_PATH" ] && [ -s "$OUTPUT_PATH" ]; then
                            if aa_is_challenge_file "$OUTPUT_PATH"; then
                                rm -f "$OUTPUT_PATH"
                                aa_print_challenge_help "downloading ${DL_LINK}"
                                exit 2
                            fi

                            FILE_SIZE=$(stat -c%s "$OUTPUT_PATH" 2>/dev/null)
                            if [ "$FILE_SIZE" -gt 10000 ]; then
                                log "✓ Download successful: $FILE_SIZE bytes"
                                echo "Downloaded: $OUTPUT_PATH"
                                exit 0
                            fi
                        fi

                        log "Download may have failed, file too small"
                        rm -f "$OUTPUT_PATH"
                    fi
                fi

                # If we got here, provide the manual link
                echo ""
                echo "Book found: $TITLE"
                echo "Download link: $DETAIL_URL"
                echo ""
                echo "Please visit the link to download manually."
                exit 0
            fi
        done
    fi
done

log "ERROR: Could not find valid book matching: $QUERY"
exit 1
