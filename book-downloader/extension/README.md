# Book Downloader Extension for Firefox

A Firefox extension that automatically downloads books from Anna's Archive.

## What It Does

1. Accepts a list of MD5 URLs (like `https://annas-archive.gl/md5/...`)
2. Navigates to each URL in sequence
3. Automatically finds and clicks download buttons
4. Waits for downloads to complete
5. Moves to the next book
6. Shows progress in the popup UI

## Installation

### Method 1: Install from Source (Developer Mode)

1. Open Firefox
2. Go to `about:debugging`
3. Click "This Firefox" (left sidebar)
4. Click "Load Temporary Add-on..."
5. Navigate to this extension folder and select `manifest.json`

The extension will be loaded temporarily. To make it permanent, you need to submit it to Mozilla Add-ons.

### Method 2: Install via Firefox

For now, this is manual. In the future you can zip the files and submit to addons.mozilla.org.

## How to Use

1. **Open the extension:** Click the book icon in Firefox toolbar

2. **Paste MD5 links:** In the popup, paste your Anna's Archive MD5 URLs (one per line):
   ```
   https://annas-archive.gl/md5/0fadd83cfc7b73546cb124920f3d984d
   https://annas-archive.gl/md5/0b5ce2f01df83d04e16d7794533f7468
   https://annas-archive.gl/md5/5f1439becff40efa007e7e82bb0975e7
   ```

3. **Click "Start Download":** The extension will:
   - Visit each link
   - Wait for the page to load
   - Find and click the download button
   - Report progress

4. **Wait for completion:** Downloads happen automatically. The browser will save files to your default Downloads folder.

## Features

- **Queue management:** Processes books one at a time
- **Progress tracking:** Shows which book is being downloaded
- **Automatic retry:** Handles various download button types
- **Visual feedback:** Popup shows current status
- **Persistent storage:** Remembers your URL list

## How It Works

The extension uses three main components:

1. **Popup UI (`popup.html/js`):** User interface for entering links and controlling downloads
2. **Background Script (`background.js`):** Manages the queue and navigates tabs
3. **Content Script (`content.js`):** Runs on Anna's Archive pages to find and click download buttons

When you click "Start":
1. Background script opens the first MD5 URL
2. Content script detects it's on an Anna's Archive page
3. Content script finds the download button and clicks it
4. Firefox downloads the file
5. Background script moves to next URL
6. Repeat until complete

## Requirements

- Firefox (any modern version)
- Valid Anna's Archive membership with subscription (for fast downloads)

## File Structure

```
extension/
├── manifest.json      # Firefox extension manifest
├── popup.html         # User interface
├── popup.js          # UI logic
├── background.js     # Queue management
├── content.js        # Page interaction
├── icons/            # Extension icons
└── README.md         # This file
```

## Troubleshooting

**Extension not showing?**
- Make sure developer mode is enabled in `about:debugging`
- Try refreshing the extension

**Downloads not starting?**
- Ensure you're logged into Anna's Archive with an active subscription
- Check that the MD5 URLs are valid and accessible
- Try refreshing the page

**Downloads stopping?**
- Anna's Archive may have rate limiting
- The extension waits 2-3 seconds between downloads
- Check the popup status for errors

## Notes

- The extension respects Anna's Archive's terms of service
- Requires manual download button clicking (no API bypasses)
- Files save to Firefox's default download location
- Only works on MD5 detail pages (not search results)

## License

Same as the book-downloader skill project.

## Support

This is a helper tool for personal use. Make sure you comply with Anna's Archive terms and copyright laws.