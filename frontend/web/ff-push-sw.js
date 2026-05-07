self.addEventListener('push', (event) => {
  let payload = {};
  if (event.data) {
    try {
      payload = event.data.json();
    } catch (_) {
      payload = { body: event.data.text() };
    }
  }

  const title = payload.title || 'FF update';
  const options = {
    body: payload.body || 'You have a new game notification.',
    icon: payload.icon || '/icons/Icon-192.png',
    badge: payload.badge || '/icons/Icon-192.png',
    tag: payload.tag || 'ff-update',
    data: payload.data || { url: '/activity' }
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || '/activity';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
      return undefined;
    })
  );
});
