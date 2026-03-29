#!/bin/bash
# Simplified book downloader that finds books on Anna's Archive and provides download links

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# URL encode function
urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "%s" "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    printf "\n"
}

ENCODED_QUERY=$(urlencode "$QUERY")

# Domains to try in order (Anna's Archive)
DOMAINS=("annas-archive.gl" "annas-archive.pk" "annas-archive.gd")

log "Searching for book: $QUERY"

SEARCH_URL=""
SEARCH_RESULTS=""

for domain in "${DOMAINS[@]}"; do
    URL="https://${domain}/search?q=${ENCODED_QUERY}"
    log "Trying domain: $domain"

    if RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "$URL" 2>/dev/null); then
        log "Got response from $domain (length: ${#RESPONSE} characters)"
        if echo "$RESPONSE" | grep -q "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono"; then
            SEARCH_URL="$URL"
            SEARCH_RESULTS="$RESPONSE"
            log "Found results on $domain"
            break
        else
            MATCH_COUNT=$(echo "$RESPONSE" | grep -c "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" 2>/dev/null || echo "0")
            log "No results found on $domain - Found $MATCH_COUNT matches"
        fi
    else
        log "Failed to connect to $domain"
    fi
done

if [[ -z "$SEARCH_URL" ]]; then
    log "Error: No results found on any Anna's Archive domains."
    exit 1
fi

# Extract first result's detail page link (href="/md5/...")
DETAIL_PATH=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
log "DETAIL_PATH: $DETAIL_PATH"
if [[ -z "$DETAIL_PATH" ]]; then
    log "Error: Could not extract detail page link from search results."
    exit 1
fi

# Use the domain that gave us results
DOMAIN="${SEARCH_URL#https://}"
DOMAIN="${DOMAIN%%/*}"
DETAIL_URL="https://${DOMAIN}${DETAIL_PATH}"

# Extract book title for filename
BOOK_TITLE=$(echo "$SEARCH_RESULTS" | grep -A 2 'line-clamp-\[2\]' | grep -o '>[^<]*<' | head -1 | sed 's/[<>]//g' | sed 's/[<>:"/\\|?*]//g' | xargs)
if [[ -z "$BOOK_TITLE" ]]; then
    BOOK_TITLE="book_$(date +%s)"
fi

log "Found book: $BOOK_TITLE"
log "Book details page: $DETAIL_URL"

# Output the information
echo "Found book: $BOOK_TITLE"
echo "Download link: $DETAIL_URL"
echo "Please visit the link above to manually download the book."

# Save the link to a file
LINK_FILE="${OUTPUT_DIR}/${BOOK_TITLE}_download_link.txt"
echo "$DETAIL_URL" > "$LINK_FILE"
log "Download link saved to: $LINK_FILE"