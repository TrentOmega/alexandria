#!/bin/bash
# Recent edition finder - prioritizes most recent versions

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

log() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

log "Searching for MOST RECENT edition of: $QUERY"

# Define search strategies for recent editions
case "$QUERY" in
    *"Australia's Home Buying Guide"*)
        log "ERROR: Todd Sloan's book not available on Anna's Archive"
        exit 1
        ;;
    *"Let It Go"*)
        # Try multiple search terms to find the most recent
        SEARCH_TERMS=("Let+It+Go+Peter+Walsh+2022" "Let+It+Go+Peter+Walsh+2021" "Let+It+Go+Peter+Walsh+2020" "Let+It+Go+Peter+Walsh")
        BOOK_TITLE="Let It Go - Peter Walsh"
        ;;
    *"Selling Your House"*)
        # Try year-specific searches
        SEARCH_TERMS=("Selling+Your+House+Nolo+Ilona+Bray+2023" "Selling+Your+House+Nolo+Ilona+Bray+2022" "Selling+Your+House+Nolo+Ilona+Bray+2021" "Selling+Your+House+Nolo+Ilona+Bray")
        BOOK_TITLE="Selling Your House - Nolo's Essential Guide - Ilona Bray"
        ;;
    *)
        SEARCH_TERMS=("$(echo "$QUERY" | sed 's/ /+/g')")
        BOOK_TITLE="$QUERY"
        ;;
esac

DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

# Try each search term in order of recency
for SEARCH_TERM in "${SEARCH_TERMS[@]}"; do
    log "Trying search: $SEARCH_TERM"
    
    for domain in $DOMAINS; do
        URL="https://${domain}/search?q=${SEARCH_TERM}"
        
        RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null)
        
        if echo "$RESPONSE" | grep "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" >/dev/null 2>&1; then
            # Get first result
            DETAIL_PATH=$(echo "$RESPONSE" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
            
            if [ -n "$DETAIL_PATH" ]; then
                log "Found match with: $SEARCH_TERM"
                DETAIL_URL="https://${domain}${DETAIL_PATH}"
                
                # Check the year on the detail page
                DETAIL_PAGE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$DETAIL_URL" 2>/dev/null)
                YEAR=$(echo "$DETAIL_PAGE" | grep -o "20[0-2][0-9]" | sort -u | tail -1)
                
                log "Book year detected: $YEAR"
                
                echo "Found book: $BOOK_TITLE"
                echo "Edition year: $YEAR"
                echo "Download link: $DETAIL_URL"
                echo "$DETAIL_URL" > "${OUTPUT_DIR}/${BOOK_TITLE}_${YEAR}_download_link.txt" 2>/dev/null || true
                exit 0
            fi
        fi
    done
done

log "ERROR: Could not find the requested book"
exit 1
