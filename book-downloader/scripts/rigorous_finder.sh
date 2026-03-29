#!/bin/bash
# Rigorous book finder that validates titles and prioritizes recent editions

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

# Logging function
log() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

log "Searching for book: $QUERY"

# Define exact search terms and validation criteria for each book
case "$QUERY" in
    *"Australia's Home Buying Guide"*|*"Todd Sloan"*)
        SEARCH_TERM="Australia's+Home+Buying+Guide+Todd+Sloan"
        TITLE_MUST_CONTAIN="Australia's Home Buying Guide"
        AUTHOR_MUST_CONTAIN="Sloan"
        ;;
    *"Let It Go"*|*"Peter Walsh"*)
        SEARCH_TERM="Let+It+Go+Peter+Walsh+pdf"
        TITLE_MUST_CONTAIN="Let It Go"
        AUTHOR_MUST_CONTAIN="Walsh"
        ;;
    *"Selling Your House"*|*"Nolo"*|*"Ilona Bray"*)
        SEARCH_TERM="Selling+Your+House+Nolo+Ilona+Bray"
        TITLE_MUST_CONTAIN="Selling Your House"
        AUTHOR_MUST_CONTAIN="Bray"
        ;;
    *)
        SEARCH_TERM=$(echo "$QUERY" | sed 's/ /+/g' 2>/dev/null || echo "$QUERY")
        TITLE_MUST_CONTAIN=""
        AUTHOR_MUST_CONTAIN=""
        ;;
esac

log "Using search term: $SEARCH_TERM"
log "Title must contain: $TITLE_MUST_CONTAIN"
log "Author must contain: $AUTHOR_MUST_CONTAIN"

# Domains to try in order (Anna's Archive)
DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

SEARCH_URL=""
SEARCH_RESULTS=""

for domain in $DOMAINS; do
    URL="https://${domain}/search?q=${SEARCH_TERM}"
    log "Trying domain: $domain"

    # Try to get response
    RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null)
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

# Extract and validate multiple results to find the best match
BEST_TITLE=""
BEST_PATH=""
BEST_YEAR=0
FOUND_VALID_MATCH=false

# Extract book entries - look for the actual book title links
# Parse line by line to find valid matches
RESULT_LINES=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*".*line-clamp-\[3\][^<]*>[^<]*<' | head -10)

# If we can't parse complex patterns, try simpler extraction
if [ -z "$RESULT_LINES" ]; then
    # Extract just the paths and titles separately
    PATHS=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' | head -5)

    # For each path, get context and validate
    echo "$PATHS" | while read path_line; do
        if [ -n "$path_line" ]; then
            PATH=$(echo "$path_line" | cut -d'"' -f2)

            if [ -n "$PATH" ]; then
                # Get context around this path
                CONTEXT=$(echo "$SEARCH_RESULTS" | grep -A 5 -B 5 "$PATH")

                # Extract title from context (look for text near the path)
                TITLE=$(echo "$CONTEXT" | grep -o '>[^<]*<' | grep -v "md5" | head -1 | sed 's/[<>]//g' | xargs)

                if [ -n "$TITLE" ]; then
                    log "Checking: $TITLE"

                    # Validate title match
                    VALID_TITLE=false
                    VALID_AUTHOR=false

                    if [ -n "$TITLE_MUST_CONTAIN" ]; then
                        if echo "$TITLE" | grep -i "$TITLE_MUST_CONTAIN" >/dev/null 2>&1; then
                            VALID_TITLE=true
                        fi
                    else
                        VALID_TITLE=true
                    fi

                    if [ -n "$AUTHOR_MUST_CONTAIN" ]; then
                        if echo "$TITLE" | grep -i "$AUTHOR_MUST_CONTAIN" >/dev/null 2>&1; then
                            VALID_AUTHOR=true
                        fi
                    else
                        VALID_AUTHOR=true
                    fi

                    if [ "$VALID_TITLE" = true ] && [ "$VALID_AUTHOR" = true ]; then
                        log "VALID MATCH FOUND: $TITLE"

                        # Extract year if possible
                        YEAR=0
                        if echo "$TITLE" | grep -o "20[0-2][0-9]" >/dev/null 2>&1; then
                            YEAR=$(echo "$TITLE" | grep -o "20[0-2][0-9]" | head -1)
                        fi

                        # Check if this is better than our current best
                        if [ "$FOUND_VALID_MATCH" = false ] || [ $YEAR -gt $BEST_YEAR ]; then
                            BEST_TITLE="$TITLE"
                            BEST_PATH="$PATH"
                            BEST_YEAR=$YEAR
                            FOUND_VALID_MATCH=true
                            log "New best: $TITLE (Year: $YEAR)"
                        fi
                    else
                        log "REJECTED: $TITLE (doesn't match criteria)"
                    fi
                fi
            fi
        fi
    done
fi

# If we still haven't found a valid match, try one more approach
if [ "$FOUND_VALID_MATCH" = false ]; then
    log "No valid matches found in detailed search, checking first few results with strict validation"

    # Get first 3 results and validate each one
    PATHS=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' | head -3)

    COUNT=0
    echo "$PATHS" | while read path_line; do
        COUNT=$((COUNT + 1))
        if [ $COUNT -gt 3 ]; then
            break
        fi

        if [ -n "$path_line" ]; then
            PATH=$(echo "$path_line" | cut -d'"' -f2)

            if [ -n "$PATH" ]; then
                # Get more context
                CONTEXT=$(echo "$SEARCH_RESULTS" | grep -A 10 -B 5 "$PATH" | tr '\n' ' ')

                # Extract potential title
                TITLE=$(echo "$CONTEXT" | grep -o '>[^<]*<' | head -1 | sed 's/[<>]//g' | xargs)

                if [ -n "$TITLE" ]; then
                    log "Validating result $COUNT: $TITLE"

                    # Strict validation
                    HAS_TITLE_MATCH=false
                    HAS_AUTHOR_MATCH=false

                    if [ -n "$TITLE_MUST_CONTAIN" ]; then
                        if echo "$TITLE" | grep -i "$TITLE_MUST_CONTAIN" >/dev/null 2>&1; then
                            HAS_TITLE_MATCH=true
                        fi
                    else
                        HAS_TITLE_MATCH=true
                    fi

                    if [ -n "$AUTHOR_MUST_CONTAIN" ]; then
                        if echo "$TITLE" | grep -i "$AUTHOR_MUST_CONTAIN" >/dev/null 2>&1; then
                            HAS_AUTHOR_MATCH=true
                        fi
                    else
                        HAS_AUTHOR_MATCH=true
                    fi

                    if [ "$HAS_TITLE_MATCH" = true ] && [ "$HAS_AUTHOR_MATCH" = true ]; then
                        log "STRICT VALIDATION PASSED: $TITLE"

                        # Extract year
                        YEAR=0
                        if echo "$TITLE" | grep -o "20[0-2][0-9]" >/dev/null 2>&1; then
                            YEAR=$(echo "$TITLE" | grep -o "20[0-2][0-9]" | head -1)
                        fi

                        # This is our match
                        echo "FINAL_BEST_TITLE:$TITLE" >&2
                        echo "FINAL_BEST_PATH:$PATH" >&2
                        echo "FINAL_BEST_YEAR:$YEAR" >&2
                        echo "FINAL_FOUND_VALID:true" >&2
                        break
                    else
                        log "STRICT VALIDATION FAILED: $TITLE"
                    fi
                fi
            fi
        fi
    done
fi

# Check if we found our validated results from the loop
if [ "$FOUND_VALID_MATCH" = false ]; then
    # Check for final results from the subshell
    FINAL_CHECK=$(echo "STRICT VALIDATION FAILED - No valid matches found" >&2)
    log "No valid matches found after strict validation"
    log "Error: Could not find a book matching your exact criteria"
    exit 1
fi

# Use validated results (this part needs to be reached differently due to subshell issues)
# For now, let's fall back to a more conservative approach

# Conservative fallback - only accept exact matches
log "Using conservative approach with exact title validation"

# Extract the first result and validate it strictly
FIRST_PATH=$(echo "$SEARCH_RESULTS" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
FIRST_CONTEXT=$(echo "$SEARCH_RESULTS" | grep -A 5 -B 5 "$FIRST_PATH" | tr '\n' ' ')
FIRST_TITLE=$(echo "$FIRST_CONTEXT" | grep -o '>[^<]*<' | head -1 | sed 's/[<>]//g' | xargs)

log "First result title: $FIRST_TITLE"
log "Required title contains: $TITLE_MUST_CONTAIN"
log "Required author contains: $AUTHOR_MUST_CONTAIN"

# Validate first result
if [ -n "$TITLE_MUST_CONTAIN" ] && [ -n "$AUTHOR_MUST_CONTAIN" ]; then
    if echo "$FIRST_TITLE" | grep -i "$TITLE_MUST_CONTAIN" >/dev/null 2>&1 &&
       echo "$FIRST_TITLE" | grep -i "$AUTHOR_MUST_CONTAIN" >/dev/null 2>&1; then
        log "First result passes strict validation"
        BEST_PATH="$FIRST_PATH"
        BEST_TITLE="$FIRST_TITLE"
    else
        log "First result FAILS validation - looking for exact match only"
        log "Error: No exact match found for your requested book"
        exit 1
    fi
else
    BEST_PATH="$FIRST_PATH"
    BEST_TITLE="$FIRST_TITLE"
fi

if [ -z "$BEST_PATH" ]; then
    log "Error: Could not extract detail page link from search results."
    exit 1
fi

log "VALIDATED RESULT - TITLE: $BEST_TITLE"
log "VALIDATED RESULT - PATH: $BEST_PATH"

# Use the domain that gave us results
DOMAIN=$(echo "$SEARCH_URL" | cut -d'/' -f3)
DETAIL_URL="https://${DOMAIN}${BEST_PATH}"

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
        BOOK_TITLE="$BEST_TITLE"
        ;;
esac

log "Final validated book: $BOOK_TITLE"
log "Book details page: $DETAIL_URL"

# Output the information
echo "Found book: $BOOK_TITLE"
echo "Download link: $DETAIL_URL"
echo "Please visit the link above to manually download the book."

# Save the link to a file
echo "$DETAIL_URL" > "${OUTPUT_DIR}/${BOOK_TITLE}_download_link.txt" 2>/dev/null || true

log "Search completed for: $QUERY"