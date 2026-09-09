importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBdwxJ6yBzWVWo62hcovFf-5bSOX-sO3xA",
  appId: "1:760012649488:web:e1e4cb7024e248e084c695",
  messagingSenderId: "760012649488",
  projectId: "zxcv-e1dd5",
  authDomain: "zxcv-e1dd5.firebaseapp.com",
  storageBucket: "zxcv-e1dd5.appspot.com"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload);
  const data = payload.data || {};
  const notificationTitle = data.title || (payload.notification && payload.notification.title) || 'BackSpace';
  const notificationOptions = {
    body: data.body || (payload.notification && payload.notification.body) || 'New message received',
    icon: '/favicon.png',
    badge: '/favicon.png',
    data: data,
    tag: data.senderId || 'backspace-chat'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
