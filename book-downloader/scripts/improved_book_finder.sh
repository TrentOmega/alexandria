#!/bin/bash
# Improved book downloader that finds books on Anna's Archive and validates title match

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

# Function to check if a title is relevant to the query
is_title_relevant() {
    local title="$1"
    local query="$2"

    # Convert to lowercase for case-insensitive comparison
    local lower_title=$(echo "$title" | tr '[:upper:]' '[:lower:]')
    local lower_query=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    # Check if query terms are in the title
    # Split query into words and check each one
    local query_words=$(echo "$lower_query" | tr ' ' '\n')
    local match_count=0
    local total_words=$(echo "$query_words" | wc -l)

    while IFS= read -r word; do
        if [[ -n "$word" ]] && echo "$lower_title" | grep -q "$word"; then
            match_count=$((match_count + 1))
        fi
    done <<< "$query_words"

    # If at least 50% of query words are found in title, consider it relevant
    local threshold=$((total_words / 2))
    if [[ $match_count -gt $threshold ]] || [[ $total_words -eq 1 && $match_count -eq 1 ]]; then
        return 0  # Relevant
    else
        return 1  # Not relevant
    fi
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

# Extract book results and find the most relevant one
log "Analyzing search results for relevance..."

# Get all book titles and their links
BOOK_ENTRIES=$(echo "$SEARCH_RESULTS" | grep -A 2 'line-clamp-\[2\]' | grep -B 2 'line-clamp-\[2\]' | grep -E 'href="/md5/|>[^<]*</div>' | paste - - - | head -10)

BEST_MATCH_TITLE=""
BEST_MATCH_PATH=""
BEST_MATCH_SCORE=0

while IFS= read -r entry; do
    # Extract title (text between > and <)
    TITLE=$(echo "$entry" | grep -o '>[^<]*</div>' | sed 's/[<>]/ /g' | xargs)

    # Extract path (href="/md5/...")
    PATH=$(echo "$entry" | grep -o 'href="/md5/[^"]*"' | cut -d'"' -f2)

    if [[ -n "$TITLE" && -n "$PATH" ]]; then
        log "Found book: $TITLE"

        # Check relevance
        if is_title_relevant "$TITLE" "$QUERY"; then
            log "  -> Relevant match found!"
            BEST_MATCH_TITLE="$TITLE"
            BEST_MATCH_PATH="$PATH"
            break
        else
            log "  -> Not relevant to query"
        fi
    fi
done <<< "$BOOK_ENTRIES"

# If no relevant match found, try a broader search
if [[ -z "$BEST_MATCH_TITLE" ]]; then
    log "No highly relevant matches found. Trying first result..."
    BEST_MATCH_PATH=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
    BEST_MATCH_TITLE=$(echo "$SEARCH_RESULTS" | grep -A 2 'line-clamp-\[2\]' | grep -o '>[^<]*<' | head -1 | sed 's/[<>]//g' | sed 's/[<>:"/\\|?*]//g' | xargs)
fi

if [[ -z "$BEST_MATCH_PATH" ]]; then
    log "Error: Could not extract detail page link from search results."
    exit 1
fi

# Use the domain that gave us results
DOMAIN="${SEARCH_URL#https://}"
DOMAIN="${DOMAIN%%/*}"
DETAIL_URL="https://${DOMAIN}${BEST_MATCH_PATH}"

if [[ -z "$BEST_MATCH_TITLE" ]]; then
    BEST_MATCH_TITLE="book_$(date +%s)"
fi

log "Found book: $BEST_MATCH_TITLE"
log "Book details page: $DETAIL_URL"

# Output the information
echo "Found book: $BEST_MATCH_TITLE"
echo "Download link: $DETAIL_URL"
echo "Please visit the link above to manually download the book."

# Save the link to a file
LINK_FILE="${OUTPUT_DIR}/${BEST_MATCH_TITLE}_download_link.txt"
echo "$DETAIL_URL" > "$LINK_FILE"
log "Download link saved to: $LINK_FILE"