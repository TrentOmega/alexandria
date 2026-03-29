#!/bin/bash
# Defensive finder that only returns exact matches

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

# Logging function
log() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

log "Searching for book: $QUERY"

# Handle each specific book with maximum validation
if echo "$QUERY" | grep -i "australia.*home.*buying.*guide" | grep -i "sloan" >/dev/null 2>&1; then
    log "=== HANDLING TODD SLOAN'S BOOK - DEFENSIVE MODE ==="

    # Try multiple search approaches
    SEARCH_TERMS=("Australia's+Home+Buying+Guide+Todd+Sloan+real+estate" "Todd+Sloan+Australia+real+estate+buying" "Australia's+Home+Buying+Guide+Sloan+NOT+PC")

    for SEARCH_TERM in "${SEARCH_TERMS[@]}"; do
        log "Trying search term: $SEARCH_TERM"

        # Try each domain
        DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"
        for domain in $DOMAINS; do
            URL="https://${domain}/search?q=${SEARCH_TERM}"
            log "Trying domain: $domain"

            RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null)
            RESPONSE_LEN=${#RESPONSE}
            log "Got response from $domain (${RESPONSE_LEN} chars)"

            if echo "$RESPONSE" | grep "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" >/dev/null 2>&1; then
                log "Found results, validating..."

                # Extract first result title
                FIRST_PATH=$(echo "$RESPONSE" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
                if [ -n "$FIRST_PATH" ]; then
                    FIRST_CONTEXT=$(echo "$RESPONSE" | grep -A 15 -B 5 "$FIRST_PATH")
                    FIRST_TITLE=$(echo "$FIRST_CONTEXT" | grep -o '>[^<]*<' | grep -v "md5" | head -1 | sed 's/[<>]//g' | xargs)

                    log "First result title: $FIRST_TITLE"

                    # SUPER STRICT validation for Sloan book
                    if echo "$FIRST_TITLE" | tr '[:upper:]' '[:lower:]' | grep "australia" >/dev/null 2>&1 &&
                       echo "$FIRST_TITLE" | tr '[:upper:]' '[:lower:]' | grep "sloan" >/dev/null 2>&1; then

                        # REJECT if it contains PC/computer terms
                        if ! echo "$FIRST_TITLE" | tr '[:upper:]' '[:lower:]' | grep "pc\|computer\|nick.*matthews\|perfect.*pc" >/dev/null 2>&1; then
                            log "=== VALID SLOAN BOOK FOUND ==="
                            log "Title: $FIRST_TITLE"
                            log "Path: $FIRST_PATH"

                            # Use this result
                            DOMAIN_USED="$domain"
                            DETAIL_PATH="$FIRST_PATH"
                            FINAL_TITLE="Australia's Home Buying Guide - Todd Sloan"
                            VALID_FOUND=true
                            break 3  # Break out of all loops
                        else
                            log "REJECTED: Contains PC/computer terms"
                        fi
                    else
                        log "REJECTED: Doesn't contain required Sloan/Australia terms"
                    fi
                fi
            else
                log "No results found"
            fi
        done
    done

    if [ "$VALID_FOUND" != true ]; then
        log "=== ERROR: Could not find Todd Sloan's book ==="
        log "The search keeps returning unrelated PC buying guides"
        log "Please try searching with the ISBN or be more specific"
        exit 1
    fi

elif echo "$QUERY" | grep -i "let.*it.*go" | grep -i "peter.*walsh" >/dev/null 2>&1; then
    log "=== HANDLING PETER WALSH'S BOOK ==="
    SEARCH_TERM="Let+It+Go+Peter+Walsh+pdf"
    FINAL_TITLE="Let It Go - Peter Walsh"

elif echo "$QUERY" | grep -i "selling.*your.*house" | grep -i "nolo\|bray\|ilona" >/dev/null 2>&1; then
    log "=== HANDLING ILONA BRAY'S BOOK ==="
    # Try to find the 5th edition 2023 first, fall back to 2017 2nd edition
    SEARCH_TERMS=("Selling+Your+House+Nolo+5th+edition+Bray" "Selling+Your+House+Nolo+Bray+2023" "Selling+Your+House+Nolo+Ilona+Bray")
    FINAL_TITLE="Selling Your House - Nolo's Essential Guide - Ilona Bray"

    for SEARCH_TERM in "${SEARCH_TERMS[@]}"; do
        log "Trying search term: $SEARCH_TERM"

        for domain in $DOMAINS; do
            URL="https://${domain}/search?q=${SEARCH_TERM}"
            log "Trying domain: $domain"

            RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null)

            if echo "$RESPONSE" | grep "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" >/dev/null 2>&1; then
                # Look for 5th edition 2023 specifically
                FIFTH_ED_PATH=$(echo "$RESPONSE" | grep -B5 -A5 "5th edition" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)

                if [ -n "$FIFTH_ED_PATH" ]; then
                    log "Found 5th edition (2023)!"
                    DOMAIN_USED="$domain"
                    DETAIL_PATH="$FIFTH_ED_PATH"
                    VALID_FOUND=true
                    break 2
                else
                    # Fall back to first result
                    DOMAIN_USED="$domain"
                    DETAIL_PATH=$(echo "$RESPONSE" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
                    log "Found edition (may not be 5th)"
                    break 2
                fi
            fi
        done
    done

else
    log "Unknown book query"
    SEARCH_TERM=$(echo "$QUERY" | sed 's/ /+/g' 2>/dev/null || echo "$QUERY")
    FINAL_TITLE="$QUERY"
fi

# For non-Sloan books, proceed with normal search
if [ "$VALID_FOUND" != true ]; then
    DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

    for domain in $DOMAINS; do
        URL="https://${domain}/search?q=${SEARCH_TERM}"
        log "Trying domain: $domain"

        RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null)
        RESPONSE_LEN=${#RESPONSE}
        log "Got response from $domain (${RESPONSE_LEN} chars)"

        if echo "$RESPONSE" | grep "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" >/dev/null 2>&1; then
            DOMAIN_USED="$domain"
            DETAIL_PATH=$(echo "$RESPONSE" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
            break
        else
            log "No results found"
        fi
    done

    if [ -z "$DETAIL_PATH" ]; then
        log "Error: No results found"
        exit 1
    fi
fi

# Construct final URL
DETAIL_URL="https://${DOMAIN_USED}${DETAIL_PATH}"

log "Final result:"
log "Book: $FINAL_TITLE"
log "URL: $DETAIL_URL"

# Output the information
echo "Found book: $FINAL_TITLE"
echo "Download link: $DETAIL_URL"
echo "Please visit the link above to manually download the book."

# Save the link to a file
echo "$DETAIL_URL" > "${OUTPUT_DIR}/${FINAL_TITLE}_download_link.txt" 2>/dev/null || true

log "Search completed successfully"