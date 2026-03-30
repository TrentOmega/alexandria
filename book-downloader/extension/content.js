// Content script for Firefox extension
// Runs on Anna's Archive MD5 pages
// Finds and clicks download buttons automatically

(function() {
  'use strict';

  // Prevent multiple injections
  if (window.bookDownloaderInjected) return;
  window.bookDownloaderInjected = true;

  console.log('Book Downloader: Content script loaded on', window.location.href);

  // Wait for page to be fully loaded and stable
  async function waitForStablePage() {
    // Wait for document ready
    if (document.readyState !== 'complete') {
      await new Promise(resolve => {
        window.addEventListener('load', resolve, { once: true });
      });
    }

    // Additional wait for any dynamic content
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Check if we're on a download selection page
    return document.querySelector('.download-button, [href*="/download"], [id*="download"]') !== null;
  }

  // Extract book title from page
  function getBookTitle() {
    const titleEl = document.querySelector('h1, title');
    if (titleEl) {
      return titleEl.textContent.trim().replace(/\s+/g, ' ').substring(0, 100);
    }
    return 'Unknown Title';
  }

  // Find and click download links
  async function findAndClickDownload() {
    const bookTitle = getBookTitle();
    console.log('Book Downloader: Processing', bookTitle);

    // Strategy 1: Look for direct download buttons/links
    const downloadSelectors = [
      'a[href*="/download"]',
      'a[href$=".pdf"]',
      'a[href$=".epub"]',
      'button[id*="download"]',
      'a[id*="download"]',
      '.download-button a',
      'a.btn-download'
    ];

    for (const selector of downloadSelectors) {
      const links = document.querySelectorAll(selector);
      for (const link of links) {
        const href = link.href;
        if (href && (href.endsWith('.pdf') || href.endsWith('.epub') || href.includes('/download'))) {
          console.log('Book Downloader: Clicking download link', href);

          // Click the link
          link.click();

          // Report success
          browser.runtime.sendMessage({
            action: 'downloaded',
            bookTitle: bookTitle,
            url: href
          });

          return true;
        }
      }
    }

    // Strategy 2: Look for member codes link (redirects to mirrors)
    const memberCodesLink = document.querySelector('a[href*="/member_codes"]');
    if (memberCodesLink) {
      console.log('Book Downloader: Clicking member codes link');
      memberCodesLink.click();

      // Wait for redirect to codes page
      await new Promise(resolve => setTimeout(resolve, 3000));

      // On codes page, look for fast download
      return await findDownloadOnCodesPage(bookTitle);
    }

    // Strategy 3: Look for "fast download" or "slow download" sections
    const fastDownload = document.querySelector('a[href*="fast"], button:contains("Fast")');
    if (fastDownload) {
      console.log('Book Downloader: Clicking fast download');
      fastDownload.click();
      return reportDownload(bookTitle);
    }

    // Nothing found
    return false;
  }

  // Handle codes/mirrors page
  async function findDownloadOnCodesPage(bookTitle) {
    // Wait for codes page to load
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Look for fast download links
    const links = document.querySelectorAll('a[href*="/fast"], a[href*="/download"], [data-download]');

    for (const link of links) {
      // Prefer fast download if available
      if (link.textContent.toLowerCase().includes('fast') ||
          link.href.includes('/fast')) {
        console.log('Book Downloader: Clicking fast mirror');
        link.click();
        return reportDownload(bookTitle);
      }
    }

    // If no fast option, click first available
    if (links.length > 0) {
      console.log('Book Downloader: Clicking first mirror');
      links[0].click();
      return reportDownload(bookTitle);
    }

    return false;
  }

  // Report successful download
  function reportDownload(bookTitle) {
    browser.runtime.sendMessage({
      action: 'downloaded',
      bookTitle: bookTitle,
      url: window.location.href
    });
    return true;
  }

  // Main execution
  async function main() {
    try {
      // Check if we should be running (message from background)
      const isActive = await browser.runtime.sendMessage({ action: 'isActive' });
      if (!isActive) {
        console.log('Book Downloader: Not active, skipping');
        return;
      }

      await waitForStablePage();
      const result = await findAndClickDownload();

      if (!result) {
        console.log('Book Downloader: Could not find download link');
        browser.runtime.sendMessage({
          action: 'downloadFailed',
          error: 'No download link found',
          url: window.location.href
        });
      }

    } catch (error) {
      console.error('Book Downloader Error:', error);
      browser.runtime.sendMessage({
        action: 'downloadFailed',
        error: error.message,
        url: window.location.href
      });
    }
  }

  // Run on page load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', main);
  } else {
    main();
  }

  // Also handle URL changes (SPA navigation)
  let lastUrl = location.href;
  new MutationObserver(() => {
    const url = location.href;
    if (url !== lastUrl) {
      lastUrl = url;
      console.log('Book Downloader: URL changed to', url);
      setTimeout(main, 2000);
    }
  }).observe(document, { subtree: true, childList: true });

})();