#!/bin/bash
# Write book findings to the download queue and push to GitHub

QUEUE_FILE="$HOME/Documents/Projects/alexandria-downloads/download-queue.md"
REPO_DIR="$HOME/Documents/Projects/alexandria-downloads"

log() {
    echo "[$(date -Iseconds)] $*" >&2
}

# Function to add a book to the queue
add_to_queue() {
    local URL="$1"
    local TITLE="$2"
    local AUTHOR="$3"
    local YEAR="$4"
    local FORMAT="${5:-PDF}"
    local STATUS="${6:-pending}"
    local ADDED="$(date -Iseconds)"
    local DOWNLOADED="${7:--}"

    # Escape pipes in title/author to not break markdown table
    TITLE=$(echo "$TITLE" | sed 's/|/\|/g')
    AUTHOR=$(echo "$AUTHOR" | sed 's/|/\|/g')

    # Build the table row
    ROW="| $URL | $TITLE | $AUTHOR | $YEAR | $FORMAT | $STATUS | $ADDED | $DOWNLOADED |"

    # Check if already in queue
    if [ -f "$QUEUE_FILE" ]; then
        if grep -q "^| $URL |" "$QUEUE_FILE"; then
            log "Book already in queue: $TITLE"
            return 0
        fi
    fi

    # Add row before the <!-- ENTRIES_END --> marker
    if [ -f "$QUEUE_FILE" ]; then
        # Create temp file with new entry
        awk "/<!-- ENTRIES_END -->/ { print \"$ROW\"; } { print; }" "$QUEUE_FILE" > "${QUEUE_FILE}.tmp"
        mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
    fi

    log "Added to queue: $TITLE by $AUTHOR"

    # Commit and push
    cd "$REPO_DIR" || exit 1

    # Configure git if needed
    git config user.email "bookdownloader@local" 2>/dev/null || true
    git config user.name "Book Downloader" 2>/dev/null || true

    # Stage, commit, push
    git add download-queue.md
    git commit -m "Add: $TITLE by $AUTHOR ($YEAR)" 2>/dev/null || true
    git push origin master 2>/dev/null || {
        log "WARNING: Failed to push to GitHub (may need manual push)"
        return 1
    }

    log "Pushed to GitHub: $TITLE"
    return 0
}

# Main entry
if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <URL> <TITLE> <AUTHOR> <YEAR> [FORMAT] [STATUS] [DOWNLOADED]"
    exit 1
fi

add_to_queue "$1" "$2" "$3" "$4" "${5:-PDF}" "${6:-pending}" "${7:--}"
