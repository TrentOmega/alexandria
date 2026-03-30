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

## GitHub Token Setup (for Private Repos)

If your download queue is in a private GitHub repository, you need a Fine-grained personal access token:

1. Go to https://github.com/settings/personal-access-tokens/new
2. **Token name:** Book Downloader Extension
3. **Expiration:** Choose your preferred expiration (e.g., 90 days)
4. **Repository access:** Select "Only select repositories" and choose your `alexandria-downloads` repo
5. **Permissions:**
   - Under "Repository permissions" → "Contents" → Select **"Read-only"**
   - Metadata will be automatically added as Read-only
6. Click **"Generate token"**
7. Copy the token (starts with `github_pat_`)

**In the extension:**
1. Open the extension popup
2. Paste the token in the "GitHub Token (for private repo)" field
3. Click **"Save Token"**
4. Click **"Load From GitHub Queue"** to fetch pending books

This uses a Fine-grained token with only read access to your specific repository, which is more secure than classic tokens that grant broader permissions.

## How to Use

1. **Open the extension:** Click the book icon in Firefox toolbar

2. **Load from queue (optional):** If you have a GitHub queue, click **"Load From GitHub Queue"** to auto-populate the list

3. **Or paste MD5 links:** In the popup, paste your Anna's Archive MD5 URLs (one per line):
   ```
   https://annas-archive.gl/md5/0fadd83cfc7b73546cb124920f3d984d
   https://annas-archive.gl/md5/0b5ce2f01df83d04e16d7794533f7468
   https://annas-archive.gl/md5/5f1439becff40efa007e7e82bb0975e7
   ```

4. **Click "Start Download":** The extension will:
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

## Token Security Note

The GitHub token is stored in the extension's local storage (not synced). It never leaves your browser except to make authenticated requests to GitHub's API. The token only has read access to your specific repository's contents.

## License

Same as the book-downloader skill project.

## Support

This is a helper tool for personal use. Make sure you comply with Anna's Archive terms and copyright laws.