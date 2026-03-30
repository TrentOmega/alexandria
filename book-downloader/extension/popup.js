// Popup script for Firefox extension

const linksTextarea = document.getElementById('links');
const startBtn = document.getElementById('startBtn');
const stopBtn = document.getElementById('stopBtn');
const clearBtn = document.getElementById('clearBtn');
const statusDiv = document.getElementById('status');
const progressDiv = document.getElementById('progress');

let isRunning = false;

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