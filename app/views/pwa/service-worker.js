// Push notification handling
self.addEventListener("push", async (event) => {
  const { title, body, url, icon } = await event.data.json()
  const options = {
    body: body,
    icon: icon || "/icon.png",
    badge: "/icon.png",
    data: { url: url || "/" },
    vibrate: [200, 100, 200],
    requireInteraction: true
  }
  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener("notificationclick", function(event) {
  event.notification.close()
  const url = event.notification.data.url || "/"
  event.waitUntil(
    clients.matchAll({ type: "window" }).then((clientList) => {
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i]
        let clientPath = new URL(client.url).pathname
        if (clientPath === new URL(url).pathname && "focus" in client) {
          return client.focus()
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(url)
      }
    })
  )
})
