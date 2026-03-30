---
name: book-downloader
description: Download books from Anna's Archive (gl, pk, gd). Finds the book, transforms MD5 URL to fast download URL, and downloads directly to ~/Downloads/
---

# Book Downloader Skill

This skill searches for a book on Anna's Archive and downloads it directly to your local machine.

## Usage

Invoke the skill with a book query:

/skill book-downloader "The Happy Home Loan Handbook"

Or with author:

/skill book-downloader "Buying a Property For Dummies" by Nicola McDougall

## How It Works

1. **Search Anna's Archive**: The skill searches across multiple domains (gl, pk, gd)
2. **Validate Results**: Defensive validation ensures the found book matches your query
3. **Transform URL**: Converts MD5 URL to fast download URL using the pattern:
   - MD5 URL: `https://annas-archive.gl/md5/{hash}`
   - Fast URL: `https://annas-archive.gl/fast_download/{hash}/0/0`
4. **Download**: Downloads the PDF directly to `~/Downloads/`

## Key Features

- **Direct Download**: No browser extension or queue needed
- **Defensive Validation**: Never returns books that don't match your query
- **Automatic Format Detection**: Prioritizes PDF, falls back to available format
- **Clean Filenames**: Generates safe filenames from book titles
- **Progress Display**: Shows download progress and file size
- **Optional Extension Support**: Still writes to GitHub queue if you also use the Firefox extension

## Download Location

Files are saved to: `~/Downloads/`

## Firefox Extension (Optional)

The Firefox extension still exists for users who prefer browser-based downloads or need to queue multiple books. However, the skill now downloads directly without requiring the extension.

**Extension location**: `/book-downloader/extension/`

**Note**: The extension has known bugs and is considered a secondary/fallback method.

## Dependencies

- curl (for HTTP requests and downloads)
- Standard Unix tools (grep, sed, awk)
- Optional subscription key for authenticated requests (see below)

## Subscription Key (Optional)

To use an Anna's Archive subscription key for authenticated requests:

1. Create a `.env` file:
   ```bash
   echo "ANNAS_ARCHIVE_KEY=your_key_here" > ~/.claude/skills/book-downloader/.env
   ```

2. The skill will automatically load and use this key

## Example

/skill book-downloader "Retirement Made Simple" Noel Whittaker

Output:
```
[time] Searching for: Retirement Made Simple Noel Whittaker
...
Found book: Retirement Made Simple - Noel Whittaker (2020)
Download link: https://annas-archive.gl/md5/e10d116e6dc99a0525d18f706d75951c

Fast download URL: https://annas-archive.gl/fast_download/e10d116e6dc99a0525d18f706d75951c/0/0

Downloading: Retirement_Made_Simple.pdf
  % Total    % Received % Xfer L  Average Speed   Time    Time     Time  Current
100  152k    0   152k  0     0   101k      0 --:--:--  0:00:01 --:--:--  101k

✓ Downloaded successfully: Retirement_Made_Simple.pdf (152K)
Location: ~/.claude/downloads/
```

## Known Limitations

- **Todd Sloan's Australia Home Buying Guide**: Consistently returns unrelated results; skill will refuse to return wrong results
- Some books may not be available on Anna's Archive
- Download requires active internet connection

## License

Personal use only. Respect Anna's Archive terms and copyright laws.