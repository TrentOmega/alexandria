#!/bin/bash
# Simplified book downloader with basic title validation

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

# Logging function
log() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

log "Searching for book: $QUERY"

# URL encode function (simplified)
ENCODED_QUERY=$(echo "$QUERY" | sed 's/ /+/g' 2>/dev/null || echo "$QUERY")

# Domains to try in order (Anna's Archive)
DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

SEARCH_URL=""
SEARCH_RESULTS=""

for domain in $DOMAINS; do
    URL="https://${domain}/search?q=${ENCODED_QUERY}"
    log "Trying domain: $domain"

    # Try to get response (with fallback if curl is not available)
    if RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null); then
        log "Got response from $domain (${$#RESPONSE} chars)"

        # Check if we have results
        if echo "$RESPONSE" | grep -q "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" 2>/dev/null; then
            SEARCH_URL="$URL"
            SEARCH_RESULTS="$RESPONSE"
            log "Found results on $domain"
            break
        else
            log "No results found on $domain"
        fi
    else
        log "Failed to connect to $domain"
    fi
done

if [ -z "$SEARCH_URL" ]; then
    log "Error: No results found on any Anna's Archive domains."
    exit 1
fi

# Extract first result's detail page link
DETAIL_PATH=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' 2>/dev/null | head -1 2>/dev/null | cut -d'"' -f2 2>/dev/null)
log "DETAIL_PATH: $DETAIL_PATH"

if [ -z "$DETAIL_PATH" ]; then
    log "Error: Could not extract detail page link from search results."
    exit 1
fi

# Use the domain that gave us results
DOMAIN=$(echo "$SEARCH_URL" | cut -d'/' -f3)
DETAIL_URL="https://${DOMAIN}${DETAIL_PATH}"

# Extract book title for filename (simple approach)
BOOK_TITLE=$(echo "$QUERY" | sed 's/[<>:"/\\|?*]//g' 2>/dev/null || echo "book")

log "Found book: $BOOK_TITLE"
log "Book details page: $DETAIL_URL"

# Output the information
echo "Found book: $BOOK_TITLE"
echo "Download link: $DETAIL_URL"
echo "Please visit the link above to manually download the book."

# Save the link to a file (if possible)
{
    echo "$DETAIL_URL"
} > "${OUTPUT_DIR}/${BOOK_TITLE}_download_link.txt" 2>/dev/null || true

log "Search completed for: $QUERY"