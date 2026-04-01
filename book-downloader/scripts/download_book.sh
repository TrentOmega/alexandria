#!/bin/bash
set -eu
set +o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
aa_load_env "$SCRIPT_DIR/.."
aa_validate_setup || exit 1

# Usage: download_book.sh "<book query>" [output_directory]
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

ENCODED_QUERY=$(echo "$QUERY" | sed 's/ /+/g')

# Domains to try in order (Anna's Archive)
DOMAINS=("annas-archive.gl" "annas-archive.pk" "annas-archive.gd")

log "Searching for book: $QUERY"
aa_describe_request_context

SEARCH_URL=""
SEARCH_RESULTS=""

for domain in "${DOMAINS[@]}"; do
    URL="https://${domain}/search?q=${ENCODED_QUERY}"
    log "Trying domain: $domain"

    # Retry mechanism with exponential backoff
    retry_count=0
    max_retries=3
    while [[ $retry_count -lt $max_retries ]]; do
        if RESPONSE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$URL" 2>/dev/null); then
            aa_exit_on_challenge_text "$RESPONSE" "searching ${URL}"
            log "Got response from $domain (length: ${#RESPONSE} characters)"
            # Check for results indicator (file type line from search results)
            echo "$RESPONSE" | grep "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" >/dev/null 2>&1
            GREP_EXIT_CODE=$?
            if [ $GREP_EXIT_CODE -eq 0 ]; then
                SEARCH_URL="$URL"
                SEARCH_RESULTS="$RESPONSE"
                log "Found results on $domain"
                break
            else
                MATCH_COUNT=$(echo "$RESPONSE" | grep -c "line-clamp-\[2\] overflow-hidden break-words text-\[9px\] text-gray-500 font-mono" 2>/dev/null || echo "0")
                log "No results found on $domain (attempt $((retry_count+1))/$max_retries) - Found $MATCH_COUNT matches, grep exit code: $GREP_EXIT_CODE"
                break
            fi
        else
            retry_count=$((retry_count+1))
            if [[ $retry_count -lt $max_retries ]]; then
                log "Request failed, retrying in $((2**retry_count)) seconds... (attempt $retry_count/$max_retries)"
                sleep $((2**retry_count))
            else
                log "Failed to connect to $domain after $max_retries attempts"
            fi
        fi
    done

    if [[ -n "$SEARCH_URL" ]]; then
        break
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

log "Fetching book details from: $DETAIL_URL"

# Fetch detail page with retry mechanism
retry_count=0
max_retries=3
DETAIL_PAGE=""
while [[ $retry_count -lt $max_retries ]]; do
    if DETAIL_PAGE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$DETAIL_URL" 2>/dev/null); then
        aa_exit_on_challenge_text "$DETAIL_PAGE" "fetching detail page ${DETAIL_URL}"
        break
    else
        retry_count=$((retry_count+1))
        if [[ $retry_count -lt $max_retries ]]; then
            log "Failed to fetch detail page, retrying in $((2**retry_count)) seconds... (attempt $retry_count/$max_retries)"
            sleep $((2**retry_count))
        else
            log "Error: Failed to fetch detail page after $max_retries attempts."
            exit 1
        fi
    fi
done

# Extract book title for filename
BOOK_TITLE=$(echo "$DETAIL_PAGE" | grep -o '<h1[^>]*>[^<]*</h1>' | sed 's/<[^>]*>//g' | head -1 | sed 's/[<>:"/\\|?*]//g')
if [[ -z "$BOOK_TITLE" ]]; then
    BOOK_TITLE="book_$(date +%s)"
fi

# Extract member_codes link (if present) - this leads to mirror selection
MEMBER_CODES_PATH=$(echo "$DETAIL_PAGE" | grep -o 'href="/member_codes[^"]*"' | head -1 | cut -d'"' -f2)

if [[ -n "$MEMBER_CODES_PATH" ]]; then
    log "Following mirror selection..."
    # Follow member_codes to get mirror list
    MEMBER_CODES_URL="https://${DOMAIN}${MEMBER_CODES_PATH}"

    retry_count=0
    MIRRORS_PAGE=""
    while [[ $retry_count -lt $max_retries ]]; do
        if MIRRORS_PAGE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$MEMBER_CODES_URL" 2>/dev/null); then
            aa_exit_on_challenge_text "$MIRRORS_PAGE" "fetching mirror selection page ${MEMBER_CODES_URL}"
            break
        else
            retry_count=$((retry_count+1))
            if [[ $retry_count -lt $max_retries ]]; then
                log "Failed to fetch mirrors page, retrying in $((2**retry_count)) seconds... (attempt $retry_count/$max_retries)"
                sleep $((2**retry_count))
            else
                log "Error: Failed to fetch mirrors page after $max_retries attempts."
                exit 1
            fi
        fi
    done

    # Extract download links from mirrors page
    # Look for direct download links (prefer PDF text, then PDF image, then EPUB)
    # First try to find the best quality download options
    PDF_TEXT_LINK=$(echo "$MIRRORS_PAGE" | grep -o 'href="[^"]*[^_]\.pdf"' | head -1 | cut -d'"' -f2)
    PDF_IMAGE_LINK=$(echo "$MIRRORS_PAGE" | grep -o 'href="[^"]*\.pdf"' | head -1 | cut -d'"' -f2)
    EPUB_LINK=$(echo "$MIRRORS_PAGE" | grep -o 'href="[^"]*\.epub"' | head -1 | cut -d'"' -f2)

    DOWNLOAD_LINK=""
    FILE_EXTENSION=""

    if [[ -n "$PDF_TEXT_LINK" ]]; then
        DOWNLOAD_LINK="$PDF_TEXT_LINK"
        FILE_EXTENSION=".pdf"
        log "Found text-based PDF"
    elif [[ -n "$PDF_IMAGE_LINK" ]]; then
        DOWNLOAD_LINK="$PDF_IMAGE_LINK"
        FILE_EXTENSION=".pdf"
        log "Found PDF"
    elif [[ -n "$EPUB_LINK" ]]; then
        DOWNLOAD_LINK="$EPUB_LINK"
        FILE_EXTENSION=".epub"
        log "Found EPUB"
    fi

    if [[ -n "$DOWNLOAD_LINK" ]]; then
        # Make absolute if relative
        if [[ "$DOWNLOAD_LINK" == /* ]]; then
            DOWNLOAD_URL="https://${DOMAIN}${DOWNLOAD_LINK}"
        else
            DOWNLOAD_URL="${DETAIL_URL%/*}/${DOWNLOAD_LINK}"
        fi

        FILENAME="${BOOK_TITLE}${FILE_EXTENSION}"
        OUTPUT_PATH="${OUTPUT_DIR}/${FILENAME}"

        log "Downloading file to: $OUTPUT_PATH"
        # Add a small delay before download to be respectful to the server
        sleep 2
        retry_count=0
        while [[ $retry_count -lt $max_retries ]]; do
            if aa_curl -L --connect-timeout 60 --max-time 300 -o "$OUTPUT_PATH" "$DOWNLOAD_URL" >/dev/null 2>&1; then
                if aa_is_challenge_file "$OUTPUT_PATH"; then
                    rm -f "$OUTPUT_PATH"
                    aa_print_challenge_help "downloading ${DOWNLOAD_URL}"
                    exit 2
                fi
                # Check if we actually downloaded a file (not an error page)
                FILE_SIZE=$(stat -c%s "$OUTPUT_PATH" 2>/dev/null || echo "0")
                if [[ $FILE_SIZE -gt 1000 ]]; then
                    log "Download completed successfully! File size: $FILE_SIZE bytes"
                    echo "$OUTPUT_PATH"
                    exit 0
                else
                    log "Download appeared to succeed but file is too small ($FILE_SIZE bytes), likely an error page"
                    rm -f "$OUTPUT_PATH"
                fi
            else
                retry_count=$((retry_count+1))
                if [[ $retry_count -lt $max_retries ]]; then
                    log "Download failed, retrying in $((2**retry_count)) seconds... (attempt $retry_count/$max_retries)"
                    sleep $((2**retry_count))
                else
                    log "Error: Failed to download file after $max_retries attempts."
log "This is likely due to anti-bot protection on the site."
log "You can manually download the book from: $DETAIL_URL"
echo "Manual download link: $DETAIL_URL"
exit 1
                fi
            fi
        done
    else
        log "Could not find direct download links, checking for alternative download methods..."
    fi
fi

# Fallback: look for direct PDF/EPUB links in detail page
# Look for more specific patterns that might work
PDF_LINK=""
EPUB_LINK=""

# Try different patterns for PDF links
for pattern in 'href="[^"]*\.pdf"' 'href="[^"]*/md5/[^"]*\.pdf"' 'href="/downloads/[^"]*\.pdf"'; do
    PDF_LINK=$(echo "$DETAIL_PAGE" | grep -o "$pattern" | head -1 | cut -d'"' -f2)
    if [[ -n "$PDF_LINK" ]]; then
        log "Found PDF link with pattern: $pattern"
        break
    fi
done

# Try different patterns for EPUB links
for pattern in 'href="[^"]*\.epub"' 'href="[^"]*/md5/[^"]*\.epub"' 'href="/downloads/[^"]*\.epub"'; do
    EPUB_LINK=$(echo "$DETAIL_PAGE" | grep -o "$pattern" | head -1 | cut -d'"' -f2)
    if [[ -n "$EPUB_LINK" ]]; then
        log "Found EPUB link with pattern: $pattern"
        break
    fi
done

DOWNLOAD_LINK=""
FILE_EXTENSION=""

if [[ -n "$PDF_LINK" ]]; then
    # Check if this is a member_codes link or a direct download link
    if [[ "$PDF_LINK" == /member_codes* ]]; then
        log "PDF link is a member_codes link, following redirect process..."
        MEMBER_CODES_PATH="$PDF_LINK"
        # Handle this like we do for the main member_codes path
        if [[ "$MEMBER_CODES_PATH" == /* ]]; then
            MEMBER_CODES_URL="https://${DOMAIN}${MEMBER_CODES_PATH}"
        else
            MEMBER_CODES_URL="${DETAIL_URL%/*}/${MEMBER_CODES_PATH}"
        fi

        retry_count=0
        MIRRORS_PAGE=""
        while [[ $retry_count -lt $max_retries ]]; do
            if MIRRORS_PAGE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$MEMBER_CODES_URL" 2>/dev/null); then
                aa_exit_on_challenge_text "$MIRRORS_PAGE" "fetching mirror selection page ${MEMBER_CODES_URL}"
                break
            else
                retry_count=$((retry_count+1))
                if [[ $retry_count -lt $max_retries ]]; then
                    log "Failed to fetch mirrors page, retrying in $((2**retry_count)) seconds... (attempt $retry_count/$max_retries)"
                    sleep $((2**retry_count))
                else
                    log "Error: Failed to fetch mirrors page after $max_retries attempts."
                    exit 1
                fi
            fi
        done

        # Now try to extract actual download links from the mirrors page
        ACTUAL_DOWNLOAD_LINK=$(echo "$MIRRORS_PAGE" | grep -o 'href="[^"]*\.pdf"' | head -1 | cut -d'"' -f2)
        if [[ -n "$ACTUAL_DOWNLOAD_LINK" ]]; then
            DOWNLOAD_LINK="$ACTUAL_DOWNLOAD_LINK"
            FILE_EXTENSION=".pdf"
            log "Found actual PDF download link: $DOWNLOAD_LINK"
        else
            log "Could not find actual download link after following member_codes"
        fi
    else
        DOWNLOAD_LINK="$PDF_LINK"
        FILE_EXTENSION=".pdf"
        log "Found direct PDF on detail page: $PDF_LINK"
    fi
elif [[ -n "$EPUB_LINK" ]]; then
    # Similar handling for EPUB links
    if [[ "$EPUB_LINK" == /member_codes* ]]; then
        log "EPUB link is a member_codes link, following redirect process..."
        MEMBER_CODES_PATH="$EPUB_LINK"
        # Handle this like we do for the main member_codes path
        if [[ "$MEMBER_CODES_PATH" == /* ]]; then
            MEMBER_CODES_URL="https://${DOMAIN}${MEMBER_CODES_PATH}"
        else
            MEMBER_CODES_URL="${DETAIL_URL%/*}/${MEMBER_CODES_PATH}"
        fi

        retry_count=0
        MIRRORS_PAGE=""
        while [[ $retry_count -lt $max_retries ]]; do
            if MIRRORS_PAGE=$(aa_curl -sS --connect-timeout 10 --max-time 30 "$MEMBER_CODES_URL" 2>/dev/null); then
                aa_exit_on_challenge_text "$MIRRORS_PAGE" "fetching mirror selection page ${MEMBER_CODES_URL}"
                break
            else
                retry_count=$((retry_count+1))
                if [[ $retry_count -lt $max_retries ]]; then
                    log "Failed to fetch mirrors page, retrying in $((2**retry_count)) seconds... (attempt $retry_count/$max_retries)"
                    sleep $((2**retry_count))
                else
                    log "Error: Failed to fetch mirrors page after $max_retries attempts."
                    exit 1
                fi
            fi
        done

        # Now try to extract actual download links from the mirrors page
        ACTUAL_DOWNLOAD_LINK=$(echo "$MIRRORS_PAGE" | grep -o 'href="[^"]*\.epub"' | head -1 | cut -d'"' -f2)
        if [[ -n "$ACTUAL_DOWNLOAD_LINK" ]]; then
            DOWNLOAD_LINK="$ACTUAL_DOWNLOAD_LINK"
            FILE_EXTENSION=".epub"
            log "Found actual EPUB download link: $DOWNLOAD_LINK"
        else
            log "Could not find actual download link after following member_codes"
        fi
    else
        DOWNLOAD_LINK="$EPUB_LINK"
        FILE_EXTENSION=".epub"
        log "Found direct EPUB on detail page: $EPUB_LINK"
    fi
else
    # Debug: show what links were found
    ALL_LINKS=$(echo "$DETAIL_PAGE" | grep -o 'href="[^"]*"' | cut -d'"' -f2 | head -10)
    log "No direct download links found. First 10 links on page:"
    echo "$ALL_LINKS" | while read link; do
        log "  $link"
    done
fi

if [[ -n "$DOWNLOAD_LINK" ]]; then
    # Make absolute if relative
    if [[ "$DOWNLOAD_LINK" == /* ]]; then
        DOWNLOAD_URL="https://${DOMAIN}${DOWNLOAD_LINK}"
    else
        DOWNLOAD_URL="${DETAIL_URL%/*}/${DOWNLOAD_LINK}"
    fi

    FILENAME="${BOOK_TITLE}${FILE_EXTENSION}"
    OUTPUT_PATH="${OUTPUT_DIR}/${FILENAME}"

    log "Downloading file to: $OUTPUT_PATH"
    retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        if aa_curl -L --connect-timeout 30 --max-time 300 -o "$OUTPUT_PATH" "$DOWNLOAD_URL" >/dev/null 2>&1; then
            if aa_is_challenge_file "$OUTPUT_PATH"; then
                rm -f "$OUTPUT_PATH"
                aa_print_challenge_help "downloading ${DOWNLOAD_URL}"
                exit 2
            fi
            log "Download completed successfully!"
            echo "$OUTPUT_PATH"
            exit 0
        else
            retry_count=$((retry_count+1))
            if [[ $retry_count -lt $max_retries ]]; then
                log "Download failed, retrying in $((2**retry_count)) seconds... (attempt $retry_count/$max_retries)"
                sleep $((2**retry_count))
            else
                log "Error: Failed to download file after $max_retries attempts."
                rm -f "$OUTPUT_PATH"  # Remove partial download
                exit 1
            fi
        fi
    done
fi

# If we get here, no download link was found
log "Error: Could not extract download link from detail page."
exit 1
