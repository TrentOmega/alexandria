// Background script for Firefox extension
// Manages the download queue and navigation

let downloadQueue = [];
let currentIndex = 0;
let isRunning = false;
let currentTabId = null;

// Listen for messages from popup
browser.runtime.onMessage.addListener(async (message, sender, sendResponse) => {
  if (message.action === 'startDownloads') {
    downloadQueue = message.links;
    currentIndex = 0;
    isRunning = true;
    processNext();
    return true;
  }

  if (message.action === 'stopDownloads') {
    isRunning = false;
    return true;
  }
});

// Extract MD5 from URL
function getMd5FromUrl(url) {
  const match = url.match(/\/md5\/([a-f0-9]+)/);
  return match ? match[1] : null;
}

// Construct fast download URL from MD5 (user discovered pattern)
function getFastDownloadUrl(md5, domain) {
  return `https://${domain}/fast_download/${md5}/0/0`;
}

// Process next book in queue
async function processNext() {
  if (!isRunning || currentIndex >= downloadQueue.length) {
    isRunning = false;
    notifyPopup('complete', {});
    return;
  }

  const url = downloadQueue[currentIndex];
  const md5 = getMd5FromUrl(url);
  const domain = new URL(url).hostname;
  currentIndex++;

  notifyPopup('progress', {
    current: currentIndex,
    total: downloadQueue.length,
    url: url,
    bookTitle: 'Loading...',
    status: `Navigating to book ${currentIndex}/${downloadQueue.length}...`
  });

  try {
    // If we have an MD5, try the fast download URL pattern first
    // The user's discovery: /md5/{hash} -> /fast_download/{hash}/0/0
    let navigationUrl = url;
    if (md5) {
      navigationUrl = getFastDownloadUrl(md5, domain);
      console.log('Background: Using fast download URL:', navigationUrl);
    }

    // Create or navigate to tab
    if (currentTabId) {
      await browser.tabs.update(currentTabId, { url: navigationUrl, active: true });
    } else {
      const tab = await browser.tabs.create({ url: navigationUrl, active: true });
      currentTabId = tab.id;
    }

    // Content script will handle the actual download
    // It will check if we're on a fast_download page and handle accordingly
  } catch (error) {
    console.error('Navigation error:', error);
    notifyPopup('error', { message: error.message });
    // Continue to next
    setTimeout(processNext, 2000);
  }
}

// Listen for messages from content script
browser.runtime.onMessage.addListener((message, sender) => {
  if (message.action === 'isActive') {
    // Content script asking if it should be active
    return Promise.resolve(isRunning);
  }

  if (message.action === 'downloaded') {
    // Content script reports successful download
    notifyPopup('progress', {
      current: currentIndex,
      total: downloadQueue.length,
      url: downloadQueue[currentIndex - 1],
      bookTitle: message.bookTitle,
      status: `Downloaded: ${message.bookTitle}`
    });

    // Wait a bit then process next
    setTimeout(processNext, 4000);
  }

  if (message.action === 'downloadFailed') {
    // Content script reports download failure
    notifyPopup('progress', {
      current: currentIndex,
      total: downloadQueue.length,
      url: downloadQueue[currentIndex - 1],
      bookTitle: 'Download Failed',
      status: `Failed: ${message.error}`
    });

    setTimeout(processNext, 2000);
  }
});

// Helper to notify popup
function notifyPopup(action, data) {
  browser.runtime.sendMessage({ action: action, ...data }).catch(() => {
    // Popup might be closed, ignore error
  });
}

// Clean up when extension updates or browser closes
browser.runtime.onSuspend.addListener(() => {
  isRunning = false;
});