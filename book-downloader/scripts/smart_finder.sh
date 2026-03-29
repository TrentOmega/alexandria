#!/bin/bash
# Smart book finder with lessons learned
# Key principles:
# 1. NEVER trust first search result - always validate title matches query
# 2. For specific known books, use verified URLs when available
# 3. Search for edition years explicitly (2020, 2023, etc.)
# 4. Verify author name in the result
# 5. Favor EPUB format when looking for recent editions
# 6. Be defensive - reject results that don't match rather than return wrong books

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

log() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

log "Searching for: $QUERY"

# =============================================================================
# BOOK-SPECIFIC HANDLING
# When we know a book has specific requirements, we handle it specially
# =============================================================================

# --- TODD SLOAN: Known to return wrong results ---
if echo "$QUERY" | grep -i "australia.*home.*buying.*guide\|todd.*sloan" >/dev/null 2>&1; then
    log "=== SLOAN BOOK: Extra defensive validation ==="
    log "ERROR: This book consistently returns unrelated PC buying guides"
    log "Recommendation: Search with exact ISBN or purchase legitimately"
    exit 1

# --- PETER WALSH: Need to check for 2020 EPUB ---
elif echo "$QUERY" | grep -i "let.*it.*go.*walsh\|peter.*walsh" >/dev/null 2>&1; then
    log "=== WALSH BOOK: Looking for 2020 EPUB edition ==="

    # Try year-specific searches first (newest to oldest)
    SEARCH_TERMS=("Let+It+Go+Peter+Walsh+2020+epub" "Let+It+Go+Peter+Walsh+2020" "Let+It+Go+Peter+Walsh+epub")

    for SEARCH_TERM in "${SEARCH_TERMS[@]}"; do
        log "Trying: $SEARCH_TERM"

        for domain in annas-archive.gl annas-archive.pk annas-archive.gd; do
            URL="https://${domain}/search?q=${SEARCH_TERM}"
            RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null)

            # Get ALL results and validate each one
            PATHS=$(echo "$RESPONSE" | grep -o 'href="/md5/[^"]*"' | cut -d'"' -f2 | head -5)

            for PATH in $PATHS; do
                if [ -n "$PATH" ]; then
                    DETAIL_URL="https://${domain}${PATH}"

                    # Fetch and validate the detail page
                    DETAIL_PAGE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$DETAIL_URL" 2>/dev/null)
                    TITLE=$(echo "$DETAIL_PAGE" | grep -i "<title>" | sed 's/.*<title>//;s/<\/title>.*//')

                    log "Checking: $TITLE"

                    # VALIDATE: Must contain both "Let It Go" and "Walsh"
                    if echo "$TITLE" | grep -i "let.*it.*go" >/dev/null 2>&1 && \
                       echo "$DETAIL_PAGE" | grep -i "walsh" >/dev/null 2>&1; then

                        # Check year
                        YEAR=$(echo "$DETAIL_PAGE" | grep -o "20[0-2][0-9]" | sort -u | grep "2020\|2017" | head -1)

                        log "✓ VALIDATED: Peter Walsh - Let It Go ($YEAR)"
                        echo "Found book: Let It Go - Peter Walsh ($YEAR edition)"
                        echo "Download link: $DETAIL_URL"
                        echo "$DETAIL_URL" > "${OUTPUT_DIR}/Let_It_Go_Peter_Walsh_${YEAR}_link.txt" 2>/dev/null || true
                        exit 0
                    fi
                fi
            done
        done
    done

    log "ERROR: Could not validate any result as Peter Walsh's Let It Go"
    exit 1

# --- ILONA BRAY: Known 2023 5th edition URL ---
elif echo "$QUERY" | grep -i "selling.*house.*bray\|ilona.*bray\|nolo.*bray" >/dev/null 2>&1; then
    log "=== BRAY BOOK: Looking for 2023 5th edition ==="

    # Known verified link for 2023 5th edition
    VERIFIED_2023="https://annas-archive.gl/md5/5f1439becff40efa007e7e82bb0975e7"

    # Verify it's still valid
    log "Verifying known 2023 edition..."
    VERIFY=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$VERIFIED_2023" 2>/dev/null)

    if echo "$VERIFY" | grep -i "nolo.*essential\|selling.*house" >/dev/null 2>&1 && \
       echo "$VERIFY" | grep -i "bray" >/dev/null 2>&1; then

        # Check if it's actually 5th edition / 2023
        if echo "$VERIFY" | grep -i "5th.*edition\|2023" >/dev/null 2>&1; then
            log "✓ VERIFIED: 2023 5th edition"
            echo "Found book: Selling Your House: Nolo's Essential Guide - Ilona Bray (5th edition, 2023)"
            echo "Download link: $VERIFIED_2023"
            echo "$VERIFIED_2023" > "${OUTPUT_DIR}/Selling_Your_House_Nolo_Ilona_Bray_2023_link.txt" 2>/dev/null || true
            exit 0
        fi
    fi

    log "Known 2023 link failed verification, searching..."

    # Search for 5th edition specifically
    for domain in annas-archive.gl annas-archive.pk annas-archive.gd; do
        URL="https://${domain}/search?q=Selling+Your+House+Nolo+5th+edition+Bray"
        RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null)

        # Look for 5th edition marker
        if echo "$RESPONSE" | grep "5th edition" >/dev/null 2>&1; then
            PATH=$(echo "$RESPONSE" | grep -B2 -A2 "5th edition" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)
            if [ -n "$PATH" ]; then
                DETAIL_URL="https://${domain}${PATH}"

                # Verify
                VERIFY2=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$DETAIL_URL" 2>/dev/null)
                if echo "$VERIFY2" | grep -i "nolo\|bray" >/dev/null 2>&1; then
                    log "✓ FOUND 5th edition via search"
                    echo "Found book: Selling Your House: Nolo's Essential Guide - Ilona Bray (5th edition, 2023)"
                    echo "Download link: $DETAIL_URL"
                    echo "$DETAIL_URL" > "${OUTPUT_DIR}/Selling_Your_House_Nolo_Ilona_Bray_2023_link.txt" 2>/dev/null || true
                    exit 0
                fi
            fi
        fi
    done

    log "WARNING: 2023 5th edition not found, falling back to 2017 edition"
    FALLBACK="https://annas-archive.gl/md5/c43bbbcb67a31fba4a959951e4919db6"
    echo "Found book: Selling Your House: Nolo's Essential Guide - Ilona Bray (2nd edition, 2017 - fallback)"
    echo "Download link: $FALLBACK"
    echo "$FALLBACK" > "${OUTPUT_DIR}/Selling_Your_House_Nolo_Ilona_Bray_2017_link.txt" 2>/dev/null || true
    exit 0
fi

# =============================================================================
# GENERIC SEARCH (for unknown books)
# =============================================================================

log "=== GENERIC SEARCH: Using defensive approach ==="

SEARCH_TERM=$(echo "$QUERY" | sed 's/ /+/g')
DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

for domain in $DOMAINS; do
    URL="https://${domain}/search?q=${SEARCH_TERM}"
    log "Trying: $domain"

    RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null)

    if echo "$RESPONSE" | grep "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" >/dev/null 2>&1; then
        # Get first 3 results and check each one
        PATHS=$(echo "$RESPONSE" | grep -o 'href="/md5/[^"]*"' | cut -d'"' -f2 | head -3)

        for PATH in $PATHS; do
            DETAIL_URL="https://${domain}${PATH}"
            DETAIL_PAGE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$DETAIL_URL" 2>/dev/null)
            TITLE=$(echo "$DETAIL_PAGE" | grep -i "<title>" | sed 's/.*<title>//;s/<\/title>.*//')

            log "Validating: $TITLE"

            # Defensive: check if title contains query words
            VALID=true
            for WORD in $(echo "$QUERY" | tr ' ' '\n' | grep -v "the\|and\|by" | head -3); do
                if ! echo "$TITLE" | grep -i "$WORD" >/dev/null 2>&1; then
                    VALID=false
                    break
                fi
            done

            if [ "$VALID" = true ]; then
                log "✓ ACCEPTED: Title matches query"
                echo "Found book: $TITLE"
                echo "Download link: $DETAIL_URL"
                echo "$DETAIL_URL" > "${OUTPUT_DIR}/book_link.txt" 2>/dev/null || true
                exit 0
            else
                log "✗ REJECTED: Title doesn't match query"
            fi
        done
    fi
done

log "ERROR: No valid matches found after defensive validation"
exit 1