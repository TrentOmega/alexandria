---
name: book-downloader
description: Download books from Anna's Archive (gl, pk, gd) or Wikipedia. Prioritizes PDF text > PDF image > EPUB. Provide book title, author, or ISBN.
---

# Book Downloader Skill

This skill searches for a book on Anna's Archive (trying gl domain first, then pk, then gd) and if not found, falls back to searching Wikipedia to find a link to Anna's Archive or other sources. It then extracts the best available download link for the book in the order of preference: PDF (text-based), PDF (image-based), EPUB.

## Usage

Invoke the skill with a book query:

/skill book-downloader "Australia's Home Buying Guide" by Todd Sloan

Or simply:

/skill book-downloader Australia's Home Buying Guide

The skill will automatically download the best available version of the book based on format priority (PDF text > PDF image > EPUB) and quality.

## How It Works

1. **Search Anna's Archive**: The skill constructs a search URL for each domain in order:
   - https://annas-archive.gl/search?q=<url-encoded-query>
   - https://annas-archive.pk/search?q=<url-encoded-query>
   - https://annas-archive.gd/search?q=<url-encoded-query>

2. **Defensive Validation**: Unlike simple search tools, this skill:
   - Validates that the found book title matches your query
   - Checks that author names are correct
   - Rejects unrelated results (e.g., "PC Buying Guide" when searching for real estate books)
   - Prioritizes recent editions (2020, 2023) over older ones
   - Uses known verified URLs for specific problematic books

3. **Fetch Book Detail Page**: It verifies the detail page content before returning it.

4. **Provide Download Link**: The skill provides a direct link to the verified book's detail page where you can manually download it.

## Key Features

- **Title Validation**: Never returns books that don't match your search
- **Author Verification**: Confirms the author is correct
- **Edition Awareness**: Prioritizes recent editions (5th ed 2023 > 2nd ed 2017)
- **Known Good URLs**: Uses verified links for books that are hard to find
- **Format Preference**: Searches for EPUB when looking for recent editions
- **Defensive Rejection**: Prefers to fail rather than return wrong results

## Known Limitations

- **Todd Sloan's book**: Consistently returns unrelated PC buying guides; skill refuses to return wrong results
- Requires manual download (anti-bot protection prevents automatic downloads)

## Dependencies

- curl (for HTTP requests)
- grep, sed, awk (for parsing HTML)
- Optional: python3 for more robust parsing

## Notes

- The skill respects the robots.txt of Anna's Archive but is intended for personal use.
- If the skill encounters a DDoS protection page, it may fail; in such cases, the user may need to try again later or use an alternative domain.
- The skill automatically downloads the best quality file based on user preferences.
- Files are saved to a default directory (~/.claude/downloads/) unless specified otherwise.

## Example

/skill book-downloader "Let It Go" by Peter Walsh

Finds the book and provides a direct link to download it manually from Anna's Archive.
## Subscription Key (Optional)

To use an Anna's Archive subscription key for authenticated requests:

1. Create a `.env` file in the skill directory:
   ```bash
   echo "ANNAS_ARCHIVE_KEY=your_key_here" > ~/.claude/skills/book-downloader/.env
   ```

2. The skill will automatically load and use this key for all requests

3. The `.env` file is excluded from git (in `.gitignore`)

Note: The key file should never be committed to git.
