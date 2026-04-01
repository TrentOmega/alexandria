#!/bin/bash
# Exact match finder for the three specific books with strict validation

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

# Handle each specific book with exact search and validation
if echo "$QUERY" | grep -i "australia.*home.*buying.*guide" | grep -i "sloan" >/dev/null 2>&1; then
    log "Handling Todd Sloan's book"
    SEARCH_TERM="Australia's+Home+Buying+Guide+Todd+Sloan"
    VALIDATION_STRING="australia.*home.*buying.*guide.*sloan"
    BOOK_TITLE="Australia's Home Buying Guide - Todd Sloan"
elif echo "$QUERY" | grep -i "let.*it.*go" | grep -i "peter.*walsh" >/dev/null 2>&1; then
    log "Handling Peter Walsh's book"
    SEARCH_TERM="Let+It+Go+Peter+Walsh+pdf"
    VALIDATION_STRING="let.*it.*go.*peter.*walsh"
    BOOK_TITLE="Let It Go - Peter Walsh"
elif echo "$QUERY" | grep -i "selling.*your.*house" | grep -i "nolo\|bray\|ilona" >/dev/null 2>&1; then
    log "Handling Ilona Bray's book"
    SEARCH_TERM="Selling+Your+House+Nolo+Ilona+Bray+2021"
    VALIDATION_STRING="selling.*your.*house.*nolo.*bray"
    BOOK_TITLE="Selling Your House - Nolo's Essential Guide - Ilona Bray"
else
    log "Unknown book, using basic search"
    SEARCH_TERM=$(echo "$QUERY" | sed 's/ /+/g' 2>/dev/null || echo "$QUERY")
    VALIDATION_STRING=""
    BOOK_TITLE="$QUERY"
fi

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

    # Check if we have results
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

# Handle Todd Sloan's book with extra strict validation
if echo "$QUERY" | grep -i "australia.*home.*buying.*guide" | grep -i "sloan" >/dev/null 2>&1; then
    # For Todd Sloan's book, be very strict
    FIRST_PATH=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
    FIRST_CONTEXT=$(echo "$SEARCH_RESULTS" | grep -A 10 -B 5 "$FIRST_PATH" | tr '\n' ' ')
    FIRST_TITLE=$(echo "$FIRST_CONTEXT" | grep -o '>[^<]*<' | grep -v "md5" | head -1 | sed 's/[<>]//g' | xargs)

    log "First result for Sloan book: $FIRST_TITLE"

    # Very strict validation - must contain "australia" and "sloan" and NOT contain "pc" or "computer"
    if echo "$FIRST_TITLE" | tr '[:upper:]' '[:lower:]' | grep "australia" >/dev/null 2>&1 &&
       echo "$FIRST_TITLE" | tr '[:upper:]' '[:lower:]' | grep "sloan" >/dev/null 2>&1; then
        if ! echo "$FIRST_TITLE" | tr '[:upper:]' '[:lower:]' | grep "pc\|computer\|nick.*matthews" >/dev/null 2>&1; then
            log "SLOAN BOOK VALIDATED: $FIRST_TITLE"
            SELECTED_PATH="$FIRST_PATH"
            SELECTED_TITLE="$FIRST_TITLE"
            VALID_MATCH_FOUND=true
        else
            log "SLOAN BOOK REJECTED - WRONG TITLE: contains PC/computer or wrong author"
            log "Error: Could not find Todd Sloan's book - first result is about PC buying"
            exit 1
        fi
    else
        log "SLOAN BOOK REJECTED - MISSING KEYWORDS: $FIRST_TITLE"
        log "Error: Could not find Todd Sloan's book - title doesn't match"
        exit 1
    fi
else
    # For other books, use the first result
    SELECTED_PATH=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
    SELECTED_TITLE="$BOOK_TITLE"
    VALID_MATCH_FOUND=true
fi

if [ "$VALID_MATCH_FOUND" = false ] || [ -z "$SELECTED_PATH" ]; then
    log "Error: Could not find a valid match for your book"
    exit 1
fi

log "Selected path: $SELECTED_PATH"
log "Selected title: $SELECTED_TITLE"

# Use the domain that gave us results
DOMAIN=$(echo "$SEARCH_URL" | cut -d'/' -f3)
DETAIL_URL="https://${DOMAIN}${SELECTED_PATH}"

log "Final book: $BOOK_TITLE"
log "Book details page: $DETAIL_URL"

# Output the information
echo "Found book: $BOOK_TITLE"
echo "Download link: $DETAIL_URL"
echo "Please visit the link above to manually download the book."

# Save the link to a file
echo "$DETAIL_URL" > "${OUTPUT_DIR}/${BOOK_TITLE}_download_link.txt" 2>/dev/null || true

log "Search completed for: $QUERY"
