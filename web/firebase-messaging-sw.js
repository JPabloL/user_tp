// Service Worker FCM — Tochito Pro (PWA / Chrome en segundo plano)
// build: %%PWA_BUILD_ID%% | version: %%PWA_APP_VERSION%%

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

self.addEventListener('message', function (event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

firebase.initializeApp({
  apiKey: 'AIzaSyA3JW74IM8sdaj0KKvqP2sqZYqXkqKu0EU',
  appId: '1:1048381349716:web:4508eb9dd36d532241b2c1',
  messagingSenderId: '1048381349716',
  projectId: 'tochito-pro',
  authDomain: 'tochito-pro.firebaseapp.com',
  storageBucket: 'tochito-pro.firebasestorage.app',
});

const messaging = firebase.messaging();

function buildNotificationFromPayload(payload) {
  const notification = payload.notification || {};
  const data = payload.data || {};
  const title =
    notification.title || data.title || 'Tochito Pro';
  const body =
    notification.body || data.body || '';
  return {
    title,
    options: {
      body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: data,
      tag: data.tipo || data.type || 'tochito-alert',
      renotify: true,
      requireInteraction: false,
    },
  };
}

// Mensajes con app en segundo plano / pestaña oculta
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw] onBackgroundMessage', payload);
  const { title, options } = buildNotificationFromPayload(payload);
  return self.registration.showNotification(title, options);
});

// Respaldo Web Push nativo (FCM data-only o "Push" de DevTools)
self.addEventListener('push', (event) => {
  if (!event.data) {
    console.log('[firebase-messaging-sw] push sin payload (test DevTools)');
    event.waitUntil(
      self.registration.showNotification('Tochito Pro (test)', {
        body: 'El service worker está activo',
        icon: '/icons/Icon-192.png',
        tag: 'devtools-test',
      }),
    );
    return;
  }
  let payload = {};
  try {
    payload = event.data.json();
  } catch (e) {
    payload = { notification: { title: 'Tochito Pro', body: event.data.text() } };
  }
  console.log('[firebase-messaging-sw] push event', payload);
  const { title, options } = buildNotificationFromPayload(payload);
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const params = new URLSearchParams();
  Object.keys(data).forEach((key) => {
    params.set(key, String(data[key] ?? ''));
  });
  const url = `${self.location.origin}/?push=1&${params.toString()}`;
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.navigate(url);
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    }),
  );
});
