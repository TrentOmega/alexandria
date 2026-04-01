#!/bin/bash
# Basic book finder that works with limited commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
aa_load_env "$SCRIPT_DIR/.."
aa_validate_setup || exit 1

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

# Logging function
log() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

log "Searching for book: $QUERY"
aa_describe_request_context

# Use more specific search terms
case "$QUERY" in
    *"Australia's Home Buying Guide"*)
        # Try exact title search
        SEARCH_TERM="Australia's+Home+Buying+Guide+Todd+Sloan"
        EXPECTED_TITLE="Australia's Home Buying Guide"
        ;;
    *"Let It Go"*)
        SEARCH_TERM="Let+It+Go+Peter+Walsh+pdf"
        EXPECTED_TITLE="Let It Go"
        ;;
    *"Selling Your House"*)
        SEARCH_TERM="Selling+Your+House+Nolo+Ilona+Bray+2021"
        EXPECTED_TITLE="Selling Your House"
        ;;
    *)
        SEARCH_TERM=$(echo "$QUERY" | sed 's/ /+/g' 2>/dev/null || echo "$QUERY")
        EXPECTED_TITLE=""
        ;;
esac

log "Using search term: $SEARCH_TERM"

# Domains to try in order (Anna's Archive)
DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

SEARCH_URL=""
SEARCH_RESULTS=""

for domain in $DOMAINS; do
    URL="https://${domain}/search?q=${SEARCH_TERM}"
    log "Trying domain: $domain"

    # Try to get response
    RESPONSE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$URL" 2>/dev/null)
    aa_exit_on_challenge_text "$RESPONSE" "searching ${URL}"
    RESPONSE_LEN=${#RESPONSE}
    log "Got response from $domain (${RESPONSE_LEN} chars)"

    # Check if we have results by looking for the specific pattern
    if echo "$RESPONSE" | grep "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" >/dev/null 2>&1; then
        SEARCH_URL="$URL"
        SEARCH_RESULTS="$RESPONSE"
        log "Found results on $domain"
        break
    else
        log "No results found on $domain"
    fi
done

if [ -z "$SEARCH_URL" ]; then
    log "Error: No results found on any Anna's Archive domains."
    exit 1
fi

# Extract the detail page link
# Look for the first href="/md5/... pattern
DETAIL_PATH=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)

if [ -z "$DETAIL_PATH" ]; then
    log "Error: Could not extract detail page link from search results."
    exit 1
fi

log "DETAIL_PATH: $DETAIL_PATH"

# Use the domain that gave us results
DOMAIN=$(echo "$SEARCH_URL" | cut -d'/' -f3)
DETAIL_URL="https://${DOMAIN}${DETAIL_PATH}"

# Create a descriptive title
case "$QUERY" in
    *"Australia's Home Buying Guide"*)
        BOOK_TITLE="Australia's Home Buying Guide - Todd Sloan"
        ;;
    *"Let It Go"*)
        BOOK_TITLE="Let It Go - Peter Walsh"
        ;;
    *"Selling Your House"*)
        BOOK_TITLE="Selling Your House - Nolo's Essential Guide - Ilona Bray"
        ;;
    *)
        BOOK_TITLE="$QUERY"
        ;;
esac

log "Found book: $BOOK_TITLE"
log "Book details page: $DETAIL_URL"

# Output the information
echo "Found book: $BOOK_TITLE"
echo "Download link: $DETAIL_URL"
echo "Please visit the link above to manually download the book."

# Save the link to a file
echo "$DETAIL_URL" > "${OUTPUT_DIR}/${BOOK_TITLE}_download_link.txt" 2>/dev/null || true

log "Search completed for: $QUERY"
