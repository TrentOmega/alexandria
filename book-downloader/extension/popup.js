// Popup script for Firefox extension

const linksTextarea = document.getElementById('links');
const startBtn = document.getElementById('startBtn');
const stopBtn = document.getElementById('stopBtn');
const clearBtn = document.getElementById('clearBtn');
const loadQueueBtn = document.getElementById('loadQueueBtn');
const statusDiv = document.getElementById('status');
const progressDiv = document.getElementById('progress');

let isRunning = false;

// GitHub queue configuration
const GITHUB_QUEUE_URL = 'https://raw.githubusercontent.com/1dropa/alexandria-downloads/refs/heads/master/download-queue.md';

// Update status display
function updateStatus(message) {
  statusDiv.innerHTML = message;
}

// Get links from textarea
function getLinks() {
  return linksTextarea.value
    .split('\n')
    .map(link => link.trim())
    .filter(link => link.length > 0 && link.includes('/md5/'));
}

// Start downloading
startBtn.addEventListener('click', async () => {
  const links = getLinks();

  if (links.length === 0) {
    updateStatus('Error: No valid MD5 links found');
    return;
  }

  isRunning = true;
  startBtn.disabled = true;
  stopBtn.disabled = false;

  // Send message to background script
  browser.runtime.sendMessage({
    action: 'startDownloads',
    links: links
  });

  updateStatus(`Started: Processing ${links.length} books...`);
});

// Stop downloading
stopBtn.addEventListener('click', () => {
  isRunning = false;
  browser.runtime.sendMessage({ action: 'stopDownloads' });
  startBtn.disabled = false;
  stopBtn.disabled = true;
  updateStatus('Stopped by user');
});

// Clear list
clearBtn.addEventListener('click', () => {
  linksTextarea.value = '';
  updateStatus('List cleared');
});

// Listen for progress updates from background
browser.runtime.onMessage.addListener((message) => {
  if (message.action === 'progress') {
    progressDiv.innerHTML = `
      Progress: ${message.current}/${message.total}<br>
      <span class="current">Current: ${message.bookTitle || message.url}</span>
    `;
    updateStatus(`Status: ${message.status}<br>Completed: ${message.current}/${message.total}`);
  }

  if (message.action === 'complete') {
    isRunning = false;
    startBtn.disabled = false;
    stopBtn.disabled = true;
    updateStatus('Complete: All downloads finished!');
  }

  if (message.action === 'error') {
    updateStatus(`Error: ${message.message}`);
  }
});

// Restore saved links if any
browser.storage.local.get('savedLinks').then((result) => {
  if (result.savedLinks) {
    linksTextarea.value = result.savedLinks.join('\n');
  }
});

// Save links when changed
linksTextarea.addEventListener('change', () => {
  browser.storage.local.set({ savedLinks: getLinks() });
});

// Load queue from GitHub
loadQueueBtn.addEventListener('click', async () => {
  updateStatus('Loading queue from GitHub...');
  loadQueueBtn.disabled = true;

  try {
    const response = await fetch(GITHUB_QUEUE_URL);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const text = await response.text();
    const pendingLinks = parseQueueFile(text);

    if (pendingLinks.length === 0) {
      updateStatus('No pending books found in queue');
      loadQueueBtn.disabled = false;
      return;
    }

    // Add to textarea (avoid duplicates)
    const existingLinks = new Set(getLinks());
    const newLinks = pendingLinks.filter(url => !existingLinks.has(url));

    if (newLinks.length > 0) {
      const currentText = linksTextarea.value.trim();
      linksTextarea.value = currentText
        ? currentText + '\n' + newLinks.join('\n')
        : newLinks.join('\n');

      // Save to storage
      browser.storage.local.set({ savedLinks: getLinks() });
      updateStatus(`Added ${newLinks.length} pending book(s) from GitHub queue${existingLinks.size > 0 ? ` (${existingLinks.size} already in list)` : ''}`);
    } else {
      updateStatus('All ${pendingLinks.length} pending book(s) already in your list');
    }
  } catch (error) {
    updateStatus(`Error loading queue: ${error.message}`);
  } finally {
    loadQueueBtn.disabled = false;
  }
});

// Parse the markdown queue file to extract pending URLs
function parseQueueFile(text) {
  const pendingLinks = [];
  const lines = text.split('\n');

  for (const line of lines) {
    const trimmed = line.trim();
    // Look for table rows with pending status
    // Format: | URL | Title | Author | Year | Format | Status | Added | Downloaded |
    if (trimmed.startsWith('|') && trimmed.includes('/md5/') && trimmed.includes('pending')) {
      // Extract URL from first column
      const parts = trimmed.split('|').map(p => p.trim()).filter(p => p);
      if (parts.length >= 2) {
        const url = parts[0];
        const status = parts[5] || '';
        if (url.includes('/md5/') && status === 'pending') {
          pendingLinks.push(url);
        }
      }
    }
  }

  return pendingLinks;
}