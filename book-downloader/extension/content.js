// Content script for Firefox extension
// Runs on Anna's Archive MD5 pages
// Finds and clicks download buttons automatically

(function() {
  'use strict';

  // Prevent multiple injections
  if (window.bookDownloaderInjected) return;
  window.bookDownloaderInjected = true;

  console.log('Book Downloader: Content script loaded on', window.location.href);

  // Extract MD5 from URL
  function getMd5FromUrl() {
    const match = window.location.href.match(/\/md5\/([a-f0-9]+)/);
    return match ? match[1] : null;
  }

  // Construct fast download URL from MD5 (user discovered pattern)
  function getFastDownloadUrl(md5) {
    const domain = window.location.hostname;
    return `https://${domain}/fast_download/${md5}/0/0`;
  }

  // Wait for page to be fully loaded and stable
  async function waitForStablePage() {
    // Wait for document ready
    if (document.readyState !== 'complete') {
      await new Promise(resolve => {
        window.addEventListener('load', resolve, { once: true });
      });
    }

    // Additional wait for any dynamic content
    await new Promise(resolve => setTimeout(resolve, 2500));

    return true;
  }

  // Extract book title from page
  function getBookTitle() {
    // Try various selectors for the title
    const selectors = [
      'h1.text-3xl',
      'h1.font-bold',
      'h1',
      '.book-title',
      'title'
    ];

    for (const selector of selectors) {
      const el = document.querySelector(selector);
      if (el) {
        const text = el.textContent.trim().replace(/\s+/g, ' ');
        // Clean up common suffixes
        return text.replace(/ - Anna's Archive$/i, '').substring(0, 100);
      }
    }
    return 'Unknown Title';
  }

  // Check if current URL is a direct file download
  function isDirectDownloadUrl(url) {
    return url.endsWith('.pdf') || url.endsWith('.epub') ||
           url.includes('.pdf?') || url.includes('.epub?');
  }

  // Strategy: Navigate directly to fast download URL
  async function tryFastDownload(md5, bookTitle) {
    const fastUrl = getFastDownloadUrl(md5);
    console.log('Book Downloader: Trying fast download URL:', fastUrl);

    // Navigate to fast download URL
    window.location.href = fastUrl;

    // Wait for redirect to actual file or download page
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Check if we're now on a direct download
    if (isDirectDownloadUrl(window.location.href)) {
      console.log('Book Downloader: Fast download successful - on direct file URL');
      return reportDownload(bookTitle);
    }

    // If still on fast_download page, look for actual download link
    return await findDownloadOnCurrentPage(bookTitle, true);
  }

  // Find and click download links on current page
  async function findDownloadOnCurrentPage(bookTitle, preferPdf = true) {
    console.log('Book Downloader: Looking for download links on current page');

    // Strategy 1: Look for Anna's Archive specific download sections
    // Check for format-specific links first (PDF before EPUB)
    const formatSelectors = preferPdf ? [
      'a[href$=".pdf"]',           // Direct PDF links
      'a[href$=".pdf?download=1"]',
      'a[href*=".pdf"]',
      'a[href$=".epub"]',          // EPUB links
      'a[href$=".epub?download=1"]',
    ] : [
      'a[href$=".epub"]',
      'a[href$=".epub?download=1"]',
      'a[href$=".pdf"]',
      'a[href$=".pdf?download=1"]',
    ];

    for (const selector of formatSelectors) {
      const links = document.querySelectorAll(selector);
      for (const link of links) {
        const href = link.href || link.getAttribute('href');
        if (href) {
          console.log('Book Downloader: Found format link:', href);

          // Check if it's a direct file link
          if (href.endsWith('.pdf') || href.endsWith('.epub') ||
              href.includes('.pdf?') || href.includes('.epub?')) {
            console.log('Book Downloader: Clicking format link:', href);
            clickLink(link);
            return reportDownload(bookTitle);
          }
        }
      }
    }

    // Strategy 2: Look for fast download sections/buttons
    const fastDownloadSelectors = [
      'a[href*="/fast_download/"]',
      'a[href*="/fast"]',
      'button:contains("Fast")',
      '[class*="fast"] a',
      'a[class*="fast"]'
    ];

    for (const selector of fastDownloadSelectors) {
      const links = document.querySelectorAll(selector);
      for (const link of links) {
        const href = link.href || link.getAttribute('href');
        if (href && href.includes('/fast')) {
          console.log('Book Downloader: Clicking fast download link:', href);
          clickLink(link);
          return reportDownload(bookTitle);
        }
      }
    }

    // Strategy 3: Look for member codes link (redirects to mirrors)
    const memberCodesLink = document.querySelector('a[href*="/member_codes"]');
    if (memberCodesLink) {
      console.log('Book Downloader: Clicking member codes link');
      clickLink(memberCodesLink);

      // Wait for redirect to codes page
      await new Promise(resolve => setTimeout(resolve, 4000));

      // On codes page, look for actual download
      return await findDownloadOnCodesPage(bookTitle);
    }

    // Strategy 4: Generic download links (last resort)
    const genericSelectors = [
      'a[href*="/download"]',
      'button[id*="download"]',
      'a[id*="download"]',
      '.download-button a',
      'a.btn-download',
      'a[download]'
    ];

    for (const selector of genericSelectors) {
      const links = document.querySelectorAll(selector);
      for (const link of links) {
        const href = link.href || link.getAttribute('href');
        if (href) {
          console.log('Book Downloader: Clicking generic download link:', href);
          clickLink(link);
          return reportDownload(bookTitle);
        }
      }
    }

    // Nothing found
    return false;
  }

  // Handle codes/mirrors page
  async function findDownloadOnCodesPage(bookTitle) {
    console.log('Book Downloader: On codes page, looking for download options');

    // Wait for page to fully load
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Look for fast download links first
    const links = document.querySelectorAll('a[href*="/fast"], a[href*="/download"], [data-download]');

    for (const link of links) {
      const href = link.href || link.getAttribute('href');
      // Prefer fast download if available
      if (href && href.includes('/fast')) {
        console.log('Book Downloader: Clicking fast mirror:', href);
        clickLink(link);
        return reportDownload(bookTitle);
      }
    }

    // If no fast option, look for any download link
    for (const link of links) {
      const href = link.href || link.getAttribute('href');
      if (href && (href.includes('/download') || href.endsWith('.pdf') || href.endsWith('.epub'))) {
        console.log('Book Downloader: Clicking mirror link:', href);
        clickLink(link);
        return reportDownload(bookTitle);
      }
    }

    // If still nothing, click first available link that looks like a download
    const allLinks = document.querySelectorAll('a');
    for (const link of allLinks) {
      const text = link.textContent.toLowerCase();
      if (text.includes('download') || text.includes('get') || text.includes('fast')) {
        console.log('Book Downloader: Clicking link with download text:', text);
        clickLink(link);
        return reportDownload(bookTitle);
      }
    }

    return false;
  }

  // Helper to click a link properly
  function clickLink(link) {
    // Try multiple methods to ensure the click works
    try {
      // Method 1: Standard click
      link.click();

      // Method 2: Dispatch events
      const clickEvent = new MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        view: window
      });
      link.dispatchEvent(clickEvent);

      // Method 3: If it's an anchor tag with href, try direct navigation
      if (link.tagName === 'A' && link.href && !link.href.startsWith('javascript:')) {
        // Wait a moment then check if navigation happened
        setTimeout(() => {
          if (window.location.href === link.href) {
            console.log('Book Downloader: Navigation confirmed');
          }
        }, 1000);
      }
    } catch (error) {
      console.error('Book Downloader: Error clicking link:', error);
    }
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

  // Main download logic
  async function findAndClickDownload() {
    const bookTitle = getBookTitle();
    const md5 = getMd5FromUrl();
    console.log('Book Downloader: Processing', bookTitle, 'MD5:', md5);

    // If we have an MD5, try the fast download URL pattern first
    if (md5) {
      const result = await tryFastDownload(md5, bookTitle);
      if (result) {
        console.log('Book Downloader: Fast download strategy succeeded');
        return true;
      }
      console.log('Book Downloader: Fast download failed, falling back to page scraping');
    }

    // Fall back to finding download buttons on current page
    return await findDownloadOnCurrentPage(bookTitle, true);
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
      setTimeout(main, 2500);
    }
  }).observe(document, { subtree: true, childList: true });

})();