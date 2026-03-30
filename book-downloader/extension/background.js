:// Background script for Firefox extension
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

// Process next book in queue
async function processNext() {
  if (!isRunning || currentIndex >= downloadQueue.length) {
    isRunning = false;
    notifyPopup('complete', {});
    return;
  }

  const url = downloadQueue[currentIndex];
  currentIndex++;

  notifyPopup('progress', {
    current: currentIndex,
    total: downloadQueue.length,
    url: url,
    bookTitle: 'Loading...',
    status: `Navigating to book ${currentIndex}/${downloadQueue.length}...`
  });

  try {
    // Create or navigate to tab
    if (currentTabId) {
      await browser.tabs.update(currentTabId, { url: url, active: true });
    } else {
      const tab = await browser.tabs.create({ url: url, active: true });
      currentTabId = tab.id;
    }

    // Wait for page to load and content script to report
    // Content script will handle the actual download button clicking
  } catch (error) {
    console.error('Navigation error:', error);
    notifyPopup('error', { message: error.message });
    // Continue to next
    setTimeout(processNext, 2000);
  }
}

// Listen for messages from content script
browser.runtime.onMessage.addListener((message, sender) => {
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
    setTimeout(processNext, 3000);
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