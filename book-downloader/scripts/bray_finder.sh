#!/bin/bash
# Specific finder for Ilona Bray's Nolo book - targets 2023 5th edition

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

log() {
    echo "[$(date 2>/dev/null || echo "time")] $*" >&2
}

log "Searching for Ilona Bray's Nolo book: 5th edition 2023"

# Known good link for 2023 5th edition
KNOWN_2023_LINK="https://annas-archive.gl/md5/5f1439becff40efa007e7e82bb0975e7"

# Verify it's still the right book
log "Verifying known 2023 edition link..."
TITLE_CHECK=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$KNOWN_2023_LINK" 2>/dev/null | grep -i "<title>")

if echo "$TITLE_CHECK" | grep -i "nolo.*essential\|selling.*house" >/dev/null 2>&1; then
    log "Verified: 2023 5th edition is correct"
    log "Details: $TITLE_CHECK"

    # Also check for author
    AUTHOR_CHECK=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$KNOWN_2023_LINK" 2>/dev/null | grep -i "bray")

    if echo "$AUTHOR_CHECK" | grep -i "bray" >/dev/null 2>&1; then
        log "Author verified: Ilona Bray"

        echo "Found book: Selling Your House: Nolo's Essential Guide - Ilona Bray (5th edition, 2023)"
        echo "Download link: $KNOWN_2023_LINK"
        echo "Please visit the link above to manually download the book."

        echo "$KNOWN_2023_LINK" > "${OUTPUT_DIR}/Selling_Your_House_Nolo_Essential_Guide_Ilona_Bray_2023_download_link.txt" 2>/dev/null || true

        log "SUCCESS: Found 2023 5th edition"
        exit 0
    fi
fi

# If verification fails, try searching
log "Known link verification failed, trying search..."

SEARCH_TERM="Selling+Your+House+Nolo+5th+edition+Bray"
DOMAINS="annas-archive.gl annas-archive.pk annas-archive.gd"

for domain in $DOMAINS; do
    URL="https://${domain}/search?q=${SEARCH_TERM}"
    log "Searching: $URL"

    RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL" 2>/dev/null)

    # Look for "5th edition" in the results and extract that specific link
    if echo "$RESPONSE" | grep "5th edition" >/dev/null 2>&1; then
        log "Found 5th edition in search results"

        # Get the path associated with 5th edition
        # Look for the specific pattern we found earlier
        FIFTH_ED_MD5=$(echo "$RESPONSE" | grep -B2 -A2 "5th edition" | grep -o 'href="/md5/[^"]*"' | head -1 | cut -d'"' -f2)

        if [ -n "$FIFTH_ED_MD5" ]; then
            DETAIL_URL="https://${domain}${FIFTH_ED_MD5}"

            # Verify
            TITLE_VERIFY=$(curl -sS --connect-timeout 10 --max-time 30 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$DETAIL_URL" 2>/dev/null | grep -i "<title>")

            if echo "$TITLE_VERIFY" | grep -i "nolo" >/dev/null 2>&1; then
                log "Found and verified 5th edition"
                echo "Found book: Selling Your House: Nolo's Essential Guide - Ilona Bray (5th edition, 2023)"
                echo "Download link: $DETAIL_URL"
                echo "$DETAIL_URL" > "${OUTPUT_DIR}/Selling_Your_House_Nolo_Essential_Guide_Ilona_Bray_2023_download_link.txt" 2>/dev/null || true
                exit 0
            fi
        fi
    fi
done

# Fall back to 2017 2nd edition if 2023 not found
log "2023 5th edition not found, falling back to 2017 2nd edition"
FALLBACK_URL="https://annas-archive.gl/md5/c43bbbcb67a31fba4a959951e4919db6"

echo "Found book: Selling Your House: Nolo's Essential Guide - Ilona Bray (2nd edition, 2017)"
echo "Download link: $FALLBACK_URL"
echo "Note: This is the 2017 2nd edition. The 2023 5th edition may not be available."
echo "$FALLBACK_URL" > "${OUTPUT_DIR}/Selling_Your_House_Nolo_Essential_Guide_Ilona_Bray_2017_download_link.txt" 2>/dev/null || true

log "Returned 2017 edition as fallback"