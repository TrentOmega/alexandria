#!/bin/bash
# Simple downloader that works with limited commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
aa_load_env "$SCRIPT_DIR/.."
aa_validate_setup || exit 1

QUERY="$1"
OUTPUT_DIR="${2:-$HOME/.claude/downloads}"

mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

echo "[$(date)] Searching for: $QUERY"

if [ -z "${ANNAS_ARCHIVE_KEY:-}" ]; then
    echo "ERROR: Add ANNAS_ARCHIVE_KEY to $SCRIPT_DIR/../.env"
    exit 1
fi

aa_describe_request_context

# Search for the book
SEARCH_TERM=$(echo "$QUERY" | sed 's/ /+/g')

for domain in annas-archive.gl annas-archive.gd; do
    URL="https://${domain}/search?q=${SEARCH_TERM}"
    echo "Trying: $domain"

    RESPONSE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$URL" 2>/dev/null)
    aa_exit_on_challenge_text "$RESPONSE" "searching ${URL}"

    # Try to get first result
    DETAIL_PATH=$(echo "$RESPONSE" | sed -n 's/.*href="\/md5\/\([^"]*\)".*/\1/p' | head -1)

    if [ -n "$DETAIL_PATH" ]; then
        DETAIL_URL="https://${domain}/md5/${DETAIL_PATH}"
        echo "Found detail page: $DETAIL_URL"

        # Get title
        DETAIL_PAGE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$DETAIL_URL" 2>/dev/null)
        aa_exit_on_challenge_text "$DETAIL_PAGE" "fetching detail page ${DETAIL_URL}"
        TITLE=$(echo "$DETAIL_PAGE" | sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p')

        echo "Book title: $TITLE"

        # Save link
        echo "$DETAIL_URL" > "$OUTPUT_DIR/last_book_link.txt"

        # Try to download directly using known patterns
        # Anna's Archive fast download with key
        FAST_URL="https://${domain}/fast_download/${DETAIL_PATH}"
        echo "Attempting fast download..."

        OUTPUT_FILE="$OUTPUT_DIR/book_${DETAIL_PATH}.pdf"
        aa_curl -L --connect-timeout 30 --max-time 300 \
            -o "$OUTPUT_FILE" \
            "$FAST_URL" 2>/dev/null

        # Check if it worked
        if [ -f "$OUTPUT_FILE" ]; then
            if aa_is_challenge_file "$OUTPUT_FILE"; then
                rm -f "$OUTPUT_FILE"
                aa_print_challenge_help "downloading ${FAST_URL}"
                exit 2
            fi
            SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "0")
            if [ "$SIZE" -gt 100000 ]; then
                echo "✓ Downloaded: $OUTPUT_FILE ($SIZE bytes)"

                # Rename with better name
                SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/:*?"<>|]/_/g' | cut -c1-50)
                FINAL_NAME="$OUTPUT_DIR/${SAFE_TITLE}.pdf"
                mv "$OUTPUT_FILE" "$FINAL_NAME"
                echo "Saved as: $FINAL_NAME"
                exit 0
            else
                echo "Download too small, may be error page"
                rm -f "$OUTPUT_FILE"
            fi
        fi

        # If fast download failed, provide manual link
        echo ""
        echo "Download link: $DETAIL_URL"
        echo "Please visit to download manually"
        exit 0
    fi
done

echo "ERROR: Book not found"
exit 1
