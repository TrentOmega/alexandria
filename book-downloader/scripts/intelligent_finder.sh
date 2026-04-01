#!/bin/bash
# Intelligent book finder that parses search results and selects the most relevant match

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

# Extract author from query if present
AUTHOR=""
TITLE_ONLY="$QUERY"

if echo "$QUERY" | grep -q " by "; then
    AUTHOR=$(echo "$QUERY" | sed 's/.* by //' | tr '[:upper:]' '[:lower:]')
    TITLE_ONLY=$(echo "$QUERY" | sed 's/ by .*//' | tr '[:upper:]' '[:lower:]')
fi

# URL encode function
ENCODED_QUERY=$(echo "$QUERY" | sed 's/ /+/g' 2>/dev/null || echo "$QUERY")

# Domains to try in order (Anna's Archive)
DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

SEARCH_URL=""
SEARCH_RESULTS=""

for domain in $DOMAINS; do
    URL="https://${domain}/search?q=${ENCODED_QUERY}"
    log "Trying domain: $domain"

    # Try to get response
    if RESPONSE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$URL" 2>/dev/null); then
        aa_exit_on_challenge_text "$RESPONSE" "searching ${URL}"
        RESPONSE_LEN=${#RESPONSE}
        log "Got response from $domain (${RESPONSE_LEN} chars)"

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

# Parse search results to find the best matching book
BEST_TITLE=""
BEST_PATH=""
BEST_SCORE=0

# Extract book entries (title and path pairs)
# Look for book title links and their associated file paths
BOOK_ENTRIES=$(echo "$SEARCH_RESULTS" | grep -E 'href="/md5/[^"]*".*line-clamp-\[3\]' | head -10 2>/dev/null)

if [ -n "$BOOK_ENTRIES" ]; then
    # Process each book entry
    while IFS= read -r line; do
        # Extract path
        PATH=$(echo "$line" | grep -o 'href="/md5/[^"]*"' | cut -d'"' -f2 2>/dev/null)

        # Extract title (text between > and < after the href)
        TITLE=$(echo "$line" | sed -n 's/.*href="[^"]*"[^>]*>\([^<]*\)<.*/\1/p' 2>/dev/null)

        if [ -n "$PATH" ] && [ -n "$TITLE" ]; then
            # Score this book based on relevance
            SCORE=0

            # Convert to lowercase for comparison
            LOWER_TITLE=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]')
            LOWER_QUERY=$(echo "$TITLE_ONLY" | tr '[:upper:]' '[:lower:]')

            # Check title match
            if echo "$LOWER_TITLE" | grep -q "$LOWER_QUERY" 2>/dev/null; then
                SCORE=$((SCORE + 50))  # Major bonus for title match
            fi

            # Check author match
            if [ -n "$AUTHOR" ]; then
                if echo "$LOWER_TITLE" | grep -q "$AUTHOR" 2>/dev/null; then
                    SCORE=$((SCORE + 30))  # Bonus for author match
                fi
            fi

            # Bonus for recent years (2017-2026)
            if echo "$TITLE" | grep -E "(201[7-9]|202[0-6])" 2>/dev/null; then
                SCORE=$((SCORE + 15))
            fi

            # Bonus for preferred formats
            if echo "$line" | grep -q "\.pdf" 2>/dev/null; then
                SCORE=$((SCORE + 5))
            fi

            log "Found: $TITLE (Score: $SCORE)"

            # Update best match if this score is better
            if [ $SCORE -gt $BEST_SCORE ]; then
                BEST_SCORE=$SCORE
                BEST_PATH="$PATH"
                BEST_TITLE="$TITLE"
            fi
        fi
    done <<< "$BOOK_ENTRIES"
fi

# If we didn't find a good match, try a different approach
if [ $BEST_SCORE -lt 20 ] || [ -z "$BEST_PATH" ]; then
    log "No good matches found with detailed parsing, using first result with keyword validation"

    # Get the first few results and check them
    RESULTS=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' 2>/dev/null | head -3 2>/dev/null)

    for result in $RESULTS; do
        PATH=$(echo "$result" | cut -d'"' -f2 2>/dev/null)
        if [ -n "$PATH" ]; then
            # Get context around this path to see the title
            CONTEXT=$(echo "$SEARCH_RESULTS" | grep -A 3 -B 3 "$PATH" 2>/dev/null | tr '\n' ' ')

            if [ -n "$CONTEXT" ]; then
                # Extract title-like text from context
                EXTRACTED_TITLE=$(echo "$CONTEXT" | grep -o '>[^<]*<' | head -1 | sed 's/[<>]//g' 2>/dev/null)

                if [ -n "$EXTRACTED_TITLE" ]; then
                    LOWER_TITLE=$(echo "$EXTRACTED_TITLE" | tr '[:upper:]' '[:lower:]')
                    LOWER_QUERY=$(echo "$TITLE_ONLY" | tr '[:upper:]' '[:lower:]')

                    # Check if this looks relevant
                    MATCH_FOUND=false

                    # Check query words in title
                    for word in $LOWER_QUERY; do
                        if [ ${#word} -gt 2 ] && echo "$LOWER_TITLE" | grep -q "$word" 2>/dev/null; then
                            MATCH_FOUND=true
                            break
                        fi
                    done

                    if [ "$MATCH_FOUND" = true ]; then
                        BEST_PATH="$PATH"
                        BEST_TITLE="$EXTRACTED_TITLE"
                        BEST_SCORE=25
                        break
                    fi
                fi
            fi
        fi
    done
fi

# Final fallback - just take the first result if nothing matched
if [ -z "$BEST_PATH" ]; then
    log "No matches found, using first result as fallback"
    BEST_PATH=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' 2>/dev/null | head -1 2>/dev/null | cut -d'"' -f2 2>/dev/null)
    BEST_TITLE="$QUERY"
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

log "Selected book: $CLEAN_TITLE (Score: $BEST_SCORE)"
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
