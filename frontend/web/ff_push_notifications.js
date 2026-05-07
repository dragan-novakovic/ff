(function () {
  function urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  async function waitForActiveServiceWorker(registration) {
    if (registration.active) {
      return registration;
    }

    const worker = registration.installing || registration.waiting;
    if (!worker) {
      return registration;
    }

    await new Promise((resolve) => {
      worker.addEventListener('statechange', () => {
        if (worker.state === 'activated') {
          resolve();
        }
      });
    });
    return registration;
  }

  async function readyRegistration() {
    if (!('serviceWorker' in navigator)) {
      throw new Error('Service workers are not supported in this browser.');
    }
    const registration = await navigator.serviceWorker.register('ff-push-sw.js', {
      scope: './push-notifications/'
    });
    return waitForActiveServiceWorker(registration);
  }

  window.ffRequestPushSubscription = async function (vapidPublicKey) {
    if (!('Notification' in window) || !('PushManager' in window)) {
      return {
        supported: false,
        subscribed: false,
        permission: 'unsupported',
        message: 'This browser does not support Web Push notifications.'
      };
    }
    if (!window.isSecureContext) {
      return {
        supported: false,
        subscribed: false,
        permission: Notification.permission,
        message: 'Push notifications require HTTPS, except on localhost.'
      };
    }
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      return {
        supported: true,
        subscribed: false,
        permission,
        message: 'Notification permission was not granted.'
      };
    }
    if (!vapidPublicKey) {
      return {
        supported: true,
        subscribed: false,
        permission,
        message: 'The backend has not configured VAPID public keys.'
      };
    }

    const registration = await readyRegistration();
    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey)
      });
    }
    const json = subscription.toJSON();
    return {
      supported: true,
      subscribed: true,
      permission,
      endpoint: subscription.endpoint,
      p256dh: json.keys && json.keys.p256dh,
      auth: json.keys && json.keys.auth,
      userAgent: navigator.userAgent
    };
  };

  window.ffUnsubscribePushSubscription = async function () {
    if (!('serviceWorker' in navigator)) {
      return {
        supported: false,
        subscribed: false,
        permission: 'unsupported',
        message: 'Service workers are not supported in this browser.'
      };
    }
    const registration = await readyRegistration();
    const subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      return {
        supported: true,
        subscribed: false,
        permission: Notification.permission,
        message: 'No browser push subscription was found.'
      };
    }
    const endpoint = subscription.endpoint;
    await subscription.unsubscribe();
    return {
      supported: true,
      subscribed: false,
      permission: Notification.permission,
      endpoint,
      message: 'Browser push subscription removed.'
    };
  };
})();
