const CACHE_NAME = 'otic-studio-v1';

const PRECACHE_URLS = [
  './',
  './index.html',
  './main.dart.js',
  './flutter.js',
  './flutter_bootstrap.js',
  './manifest.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
  './assets/AssetManifest.bin',
  './assets/AssetManifest.bin.json',
  './assets/FontManifest.json',
  './assets/fonts/MaterialIcons-Regular.otf',
  './assets/shaders/ink_sparkle.frag',
  './assets/shaders/stretch_effect.frag',
  './assets/assets/branding/otic-studio-logo.png',
  './assets/assets/branding/otic-logo.jpeg',
  './assets/assets/branding/otic_logo.png',
  './assets/assets/fonts/PlusJakartaSans-Regular.ttf',
  './assets/assets/fonts/PlusJakartaSans-Medium.ttf',
  './assets/assets/fonts/PlusJakartaSans-SemiBold.ttf',
  './assets/assets/fonts/PlusJakartaSans-Bold.ttf',
  './assets/assets/curriculum/mathematics.json',
  './assets/assets/curriculum/physics.json',
  './assets/assets/curriculum/biology.json',
  './assets/assets/curriculum/chemistry.json',
  './assets/assets/curriculum/programming.json',
  './assets/assets/curriculum/ai_and_data.json',
  './assets/assets/curriculum/entrepreneurship.json',
  './assets/assets/curriculum/agriculture.json',
  './assets/assets/curriculum/history.json',
  './assets/assets/curriculum/geography.json',
  './assets/assets/curriculum/english_writing.json',
  './assets/assets/curriculum/economics.json',
  './assets/assets/curriculum/arts.json',
  './assets/assets/curriculum/web_development.json',
  './assets/assets/curriculum/app_development.json',
  './assets/assets/curriculum/ignite_ai.json',
  './assets/assets/templates/bakery.html',
  './assets/assets/templates/church.html',
  './assets/assets/templates/fitness.html',
  './assets/assets/templates/hotel.html',
  './assets/assets/templates/ngo.html',
  './assets/assets/templates/portfolio.html',
  './assets/assets/templates/realtor.html',
  './assets/assets/templates/salon.html',
  './assets/assets/templates/school.html',
  './assets/assets/templates/techstartup.html',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_URLS);
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((names) => {
      return Promise.all(
        names.filter((name) => name !== CACHE_NAME).map((name) => caches.delete(name))
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((response) => {
        if (!response || response.status !== 200) return response;
        const clone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        return response;
      }).catch(() => {
        if (event.request.destination === 'document') {
          return caches.match('./index.html');
        }
      });
    })
  );
});
