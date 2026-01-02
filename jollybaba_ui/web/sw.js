// JollyBaba Service Worker - Online-Only PWA
// Provides fast loading and install prompts, but requires internet for functionality

const CACHE_NAME = 'jollybaba-v1';
const OFFLINE_URL = '/offline.html';

// Files to cache for faster loading (app shell only)
const APP_SHELL = [
    '/',
    '/index.html',
    '/manifest.json',
    '/favicon.png',
    '/icons/Icon-192.png',
    '/icons/Icon-512.png',
];

// Install event - cache app shell
self.addEventListener('install', (event) => {
    console.log('[SW] Installing service worker...');
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => {
            console.log('[SW] Caching app shell');
            return cache.addAll(APP_SHELL);
        })
    );
    self.skipWaiting(); // Activate immediately
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
    self.clients.claim(); // Take control immediately
});

// Fetch event - NETWORK-FIRST strategy (online-only)
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = new URL(request.url);

    // Skip chrome-extension and non-http requests
    if (!url.protocol.startsWith('http')) {
        return;
    }

    event.respondWith(
        // ALWAYS try network first (online-only requirement)
        fetch(request)
            .then((response) => {
                // If successful, update cache for next time
                if (response && response.status === 200) {
                    const responseClone = response.clone();
                    caches.open(CACHE_NAME).then((cache) => {
                        cache.put(request, responseClone);
                    });
                }
                return response;
            })
            .catch((error) => {
                console.log('[SW] Network request failed:', request.url);

                // For navigation requests (pages), show offline page
                if (request.mode === 'navigate') {
                    return caches.match(OFFLINE_URL).then((cachedResponse) => {
                        if (cachedResponse) {
                            return cachedResponse;
                        }
                        // Fallback: return basic offline HTML
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
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    text-align: center;
                    padding: 20px;
                  }
                  .container {
                    max-width: 400px;
                  }
                  h1 {
                    font-size: 48px;
                    margin-bottom: 16px;
                  }
                  p {
                    font-size: 18px;
                    margin-bottom: 24px;
                    opacity: 0.9;
                  }
                  button {
                    background: white;
                    color: #667eea;
                    border: none;
                    padding: 12px 32px;
                    font-size: 16px;
                    font-weight: 600;
                    border-radius: 8px;
                    cursor: pointer;
                    transition: transform 0.2s;
                  }
                  button:hover {
                    transform: scale(1.05);
                  }
                </style>
              </head>
              <body>
                <div class="container">
                  <h1>📡</h1>
                  <h2>You're Offline</h2>
                  <p>JollyBaba requires an internet connection to work. Please check your connection and try again.</p>
                  <button onclick="window.location.reload()">Retry</button>
                </div>
              </body>
              </html>`,
                            {
                                headers: { 'Content-Type': 'text/html' },
                            }
                        );
                    });
                }

                // For other requests (API, images, etc.), DON'T serve from cache
                // This ensures the app doesn't work offline (as requested)
                return new Response(
                    JSON.stringify({ error: 'Network error - Internet required' }),
                    {
                        status: 503,
                        statusText: 'Service Unavailable',
                        headers: { 'Content-Type': 'application/json' },
                    }
                );
            })
    );
});

// Background sync (for future enhancement)
self.addEventListener('sync', (event) => {
    console.log('[SW] Background sync:', event.tag);
    // Can be used later for queuing failed requests
});

// Push notifications (for future enhancement)
self.addEventListener('push', (event) => {
    console.log('[SW] Push notification received');
    // Can be used later for real-time updates
});

console.log('[SW] Service worker loaded');
