#!/bin/bash
# Enhanced book downloader with title validation and edition checking

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

# Logging function
log() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

log "Searching for book: $QUERY"

# Extract author from query if present
AUTHOR=""
if echo "$QUERY" | grep -q " by "; then
    AUTHOR=$(echo "$QUERY" | sed 's/.* by //' | tr '[:upper:]' '[:lower:]')
    TITLE_ONLY=$(echo "$QUERY" | sed 's/ by .*//' | tr '[:upper:]' '[:lower:]')
else
    TITLE_ONLY=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
fi

# URL encode function (simplified)
ENCODED_QUERY=$(echo "$QUERY" | sed 's/ /+/g' 2>/dev/null || echo "$QUERY")

# Domains to try in order (Anna's Archive)
DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

SEARCH_URL=""
SEARCH_RESULTS=""

for domain in $DOMAINS; do
    URL="https://${domain}/search?q=${ENCODED_QUERY}"
    log "Trying domain: $domain"

    # Try to get response
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

# Parse search results to find the best match
BEST_TITLE=""
BEST_PATH=""
BEST_SCORE=0

# Extract multiple results to compare
RESULTS=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' 2>/dev/null | head -5 2>/dev/null)

for result in $RESULTS; do
    PATH=$(echo "$result" | cut -d'"' -f2 2>/dev/null)

    # Get the title line associated with this result
    TITLE_LINE=$(echo "$SEARCH_RESULTS" | grep -A 5 "$PATH" | grep -E "(lgli/|epub/)" | head -1 2>/dev/null)

    if [ -n "$TITLE_LINE" ]; then
        # Extract title from the line
        EXTRACTED_TITLE=$(echo "$TITLE_LINE" | sed 's/.*\///' | sed 's/\.[^.]*$//' | sed 's/_/ /g' 2>/dev/null)

        # Score this result based on title match
        SCORE=0

        # Check if main title words are in the extracted title
        for word in $TITLE_ONLY; do
            if echo "$EXTRACTED_TITLE" | tr '[:upper:]' '[:lower:]' | grep -q "$word" 2>/dev/null; then
                SCORE=$((SCORE + 10))
            fi
        done

        # Check author match if we have one
        if [ -n "$AUTHOR" ]; then
            AUTHOR_WORDS=$(echo "$AUTHOR" | wc -w)
            MATCHED_WORDS=0
            for word in $AUTHOR; do
                if echo "$EXTRACTED_TITLE" | tr '[:upper:]' '[:lower:]' | grep -q "$word" 2>/dev/null; then
                    MATCHED_WORDS=$((MATCHED_WORDS + 1))
                fi
            done
            if [ $MATCHED_WORDS -gt 0 ]; then
                SCORE=$((SCORE + (MATCHED_WORDS * 5)))
            fi
        fi

        # Bonus for recent years (2017-2026)
        if echo "$EXTRACTED_TITLE" | grep -E "(201[7-9]|202[0-6])" 2>/dev/null; then
            SCORE=$((SCORE + 15))
        fi

        # Bonus for preferred formats
        if echo "$TITLE_LINE" | grep -q "\.pdf" 2>/dev/null; then
            SCORE=$((SCORE + 5))
        fi

        log "Found: $EXTRACTED_TITLE (Score: $SCORE)"

        # Update best match if this score is better
        if [ $SCORE -gt $BEST_SCORE ]; then
            BEST_SCORE=$SCORE
            BEST_PATH=$PATH
            BEST_TITLE="$EXTRACTED_TITLE"
        fi
    fi
done

# If we didn't find a good match, fall back to first result
if [ $BEST_SCORE -lt 10 ] || [ -z "$BEST_PATH" ]; then
    log "No good matches found, using first result"
    BEST_PATH=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' 2>/dev/null | head -1 2>/dev/null | cut -d'"' -f2 2>/dev/null)
    BEST_TITLE="$QUERY"
else
    log "Best match: $BEST_TITLE (Score: $BEST_SCORE)"
fi

if [ -z "$BEST_PATH" ]; then
    log "Error: Could not extract detail page link from search results."
    exit 1
fi

# Use the domain that gave us results
DOMAIN=$(echo "$SEARCH_URL" | cut -d'/' -f3)
DETAIL_URL="https://${DOMAIN}${BEST_PATH}"

# Clean up the title for filename
CLEAN_TITLE=$(echo "$BEST_TITLE" | sed 's/[<>:"/\\|?*]//g' 2>/dev/null || echo "book")

log "Found book: $CLEAN_TITLE"
log "Book details page: $DETAIL_URL"

# Output the information
echo "Found book: $CLEAN_TITLE"
echo "Download link: $DETAIL_URL"
echo "Please visit the link above to manually download the book."

# Save the link to a file
{
    echo "$DETAIL_URL"
} > "${OUTPUT_DIR}/${CLEAN_TITLE}_download_link.txt" 2>/dev/null || true

log "Search completed for: $QUERY"