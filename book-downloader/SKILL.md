---
name: book-downloader
description: Download books from Anna's Archive (gl, pk, gd). Finds the book, transforms MD5 URL to fast download URL, and downloads directly to ~/Downloads/
---

# Book Downloader Skill

This skill searches for a book on Anna's Archive and downloads it directly to your local machine.

## Usage

Invoke the skill with a book query:

/skill book-downloader "The Little Book of Elves"

Or with author:

/skill book-downloader "How to Buy a Giant Banana" by Peter Pan

## How It Works

1. **Search Anna's Archive**: The skill searches Anna's Archive (gl, pk, gd) (which ever one is working)
2. **Validate Results**: Defensive validation ensures the found book matches your query
3. **Transform URL**: Converts MD5 URL to fast download URL using the pattern:
   - MD5 URL: `https://annas-archive.gl/md5/{hash}`
   - Fast URL: `https://annas-archive.gl/fast_download/{hash}/0/0`
4. **Download**: Downloads the PDF directly to `~/Downloads/`

## Key Features

- **Defensive Validation**: Never returns books that don't match your query
- **Automatic Format Detection**: Prioritizes PDF, falls back to available format
- **Clean Filenames**: Generates safe filenames from book titles
- **Progress Display**: Shows download progress and file size

## Download Location

Files are saved to: `~/Downloads/`

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

/skill book-downloader "Brain Surgery Made Simple" Noel Quinn

Output:
```
[time] Searching for: Brain Surgery Made Simple Noel Quinn
...
Found book: Brain Surgery Made Simple - Noel Quinn (2020)
Download link: https://annas-archive.gl/md5/e10d116e6dc99a0525d18f706d75951c

Fast download URL: https://annas-archive.gl/fast_download/e10d126e6dc99a0525d18f70dd75951d/0/0

Downloading: Brain_Surgery_Made_Simple.pdf
  % Total    % Received % Xfer L  Average Speed   Time    Time     Time  Current
100  152k    0   152k  0     0   101k      0 --:--:--  0:00:01 --:--:--  101k

✓ Downloaded successfully: Brain_Surgery_Made_Simple.pdf (152K)
Location: ~/Downloads/
```

## Known Limitations

- Some books may not be available on Anna's Archive
- Download requires active internet connection