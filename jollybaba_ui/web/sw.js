// JollyBaba Service Worker - Fast Loading PWA
// Uses CACHE-FIRST for static assets, NETWORK-FIRST for API calls

const CACHE_VERSION = 'v3';
const CACHE_NAME = `jollybaba-${CACHE_VERSION}`;

// Static assets to pre-cache during install
const PRECACHE_ASSETS = [
    '/',
    '/index.html',
    '/manifest.json',
    '/favicon.png',
    '/icons/Icon-192.png',
    '/icons/Icon-512.png',
    '/flutter_bootstrap.js',
];

// Patterns for different caching strategies
const CACHE_FIRST_PATTERNS = [
    // Flutter compiled assets (these have content hashes, safe to cache)
    /\.js$/,
    /\.css$/,
    /\.woff2?$/,
    /\.ttf$/,
    /\.otf$/,
    /\.png$/,
    /\.jpg$/,
    /\.jpeg$/,
    /\.gif$/,
    /\.svg$/,
    /\.ico$/,
    /\.webp$/,
    // Google Fonts
    /fonts\.googleapis\.com/,
    /fonts\.gstatic\.com/,
];

const NETWORK_FIRST_PATTERNS = [
    // API calls - always fetch fresh data
    /\/api\//,
    // External services
    /cloudinary\.com/,
    /googleapis\.com\/oauth/,
    /accounts\.google\.com/,
];

const NEVER_CACHE_PATTERNS = [
    // Service worker itself
    /sw\.js/,
    // Chrome extensions
    /^chrome-extension/,
];

// Install event - pre-cache essential assets
self.addEventListener('install', (event) => {
    console.log('[SW] Installing service worker...');
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('[SW] Pre-caching app shell');
                return cache.addAll(PRECACHE_ASSETS);
            })
            .catch((err) => {
                console.log('[SW] Pre-cache failed (non-critical):', err);
            })
    );
    // Activate immediately for faster updates
    self.skipWaiting();
});

// Activate event - clean old caches
self.addEventListener('activate', (event) => {
    console.log('[SW] Activating service worker...');
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheName !== CACHE_NAME) {
                        console.log('[SW] Deleting old cache:', cacheName);
                        return caches.delete(cacheName);
                    }
                })
            );
        })
    );
    // Take control of all pages immediately
    self.clients.claim();
});

// Helper: Check if URL matches any pattern in array
function matchesPattern(url, patterns) {
    return patterns.some((pattern) => pattern.test(url));
}

// Helper: CACHE-FIRST strategy (fast for static assets)
async function cacheFirst(request) {
    const cached = await caches.match(request);
    if (cached) {
        // Return cached version immediately, update cache in background
        fetch(request)
            .then((response) => {
                if (response && response.status === 200) {
                    const responseClone = response.clone();
                    caches.open(CACHE_NAME).then((cache) => {
                        cache.put(request, responseClone);
                    });
                }
            })
            .catch(() => { }); // Ignore background update errors
        return cached;
    }

    // Not in cache, fetch and cache
    const response = await fetch(request);
    if (response && response.status === 200) {
        const responseClone = response.clone();
        caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseClone);
        });
    }
    return response;
}

// Helper: NETWORK-FIRST strategy (for API calls)
async function networkFirst(request) {
    try {
        const response = await fetch(request);
        return response;
    } catch (error) {
        // Network failed, try cache as fallback
        const cached = await caches.match(request);
        if (cached) {
            return cached;
        }
        throw error;
    }
}

// Fetch event - route requests to appropriate strategy
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = request.url;

    // Skip non-http requests
    if (!url.startsWith('http')) {
        return;
    }

    // Never cache these
    if (matchesPattern(url, NEVER_CACHE_PATTERNS)) {
        return;
    }

    // Network-first for API calls (always get fresh data)
    if (matchesPattern(url, NETWORK_FIRST_PATTERNS)) {
        event.respondWith(networkFirst(request));
        return;
    }

    // Cache-first for static assets (fast loading)
    if (matchesPattern(url, CACHE_FIRST_PATTERNS)) {
        event.respondWith(cacheFirst(request));
        return;
    }

    // For navigation requests (HTML pages), use cache-first with network fallback
    if (request.mode === 'navigate') {
        event.respondWith(
            caches.match(request)
                .then((cached) => {
                    if (cached) {
                        // Update cache in background
                        fetch(request)
                            .then((response) => {
                                if (response && response.status === 200) {
                                    caches.open(CACHE_NAME).then((cache) => {
                                        cache.put(request, response);
                                    });
                                }
                            })
                            .catch(() => { });
                        return cached;
                    }
                    return fetch(request);
                })
                .catch(() => {
                    // Offline fallback
                    return new Response(
                        `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Offline - JollyBaba</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      display: flex; align-items: center; justify-content: center;
      min-height: 100vh;
      background: linear-gradient(135deg, #6D5DF6, #8A8EFF);
      color: white; text-align: center; padding: 20px;
    }
    h1 { font-size: 48px; margin-bottom: 16px; }
    p { font-size: 16px; margin-bottom: 24px; opacity: 0.9; }
    button {
      background: white; color: #6D5DF6; border: none;
      padding: 12px 32px; font-size: 16px; font-weight: 600;
      border-radius: 12px; cursor: pointer;
    }
  </style>
</head>
<body>
  <div>
    <h1>📡</h1>
    <h2>You're Offline</h2>
    <p>Please check your internet connection and try again.</p>
    <button onclick="window.location.reload()">Retry</button>
  </div>
</body>
</html>`,
                        { headers: { 'Content-Type': 'text/html' } }
                    );
                })
        );
        return;
    }

    // Default: try cache first, fallback to network
    event.respondWith(cacheFirst(request));
});

// Handle messages from the page
self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'SKIP_WAITING') {
        console.log('[SW] Received SKIP_WAITING, activating...');
        self.skipWaiting();
    }
});

console.log('[SW] Service worker loaded - Cache-First strategy enabled');
