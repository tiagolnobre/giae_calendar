import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    publicKey: String,
    isSubscribed: Boolean
  }

  async connect() {
    if (!("Notification" in window) || !("serviceWorker" in navigator)) {
      this.element.classList.add("hidden")
      return
    }

    this.updateButton()
  }

  async subscribe(event) {
    event.preventDefault()

    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      return
    }

    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.urlBase64ToUint8Array(this.publicKeyValue)
    })

    const response = await fetch("/push_subscriptions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken()
      },
      body: JSON.stringify({ subscription: subscription.toJSON() })
    })

    if (response.ok) {
      this.isSubscribedValue = true
      this.updateButton()
    }
  }

  async unsubscribe(event) {
    event.preventDefault()

    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.getSubscription()

    if (subscription) {
      await subscription.unsubscribe()
      await fetch(`/push_subscriptions?endpoint=${encodeURIComponent(subscription.endpoint)}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": this.getCSRFToken()
        }
      })
    }

    this.isSubscribedValue = false
    this.updateButton()
  }

  updateButton() {
    const subscribeBtn = this.element.querySelector("[data-push-subscribe-target='button']")
    if (subscribeBtn) {
      if (this.isSubscribedValue) {
        subscribeBtn.textContent = "Notifications: ON"
        subscribeBtn.classList.remove("bg-blue-500", "hover:bg-blue-600")
        subscribeBtn.classList.add("bg-green-500", "hover:bg-green-600")
        subscribeBtn.removeEventListener("click", this.subscribe.bind(this))
        subscribeBtn.addEventListener("click", this.unsubscribe.bind(this))
      } else {
        subscribeBtn.textContent = "Enable Notifications"
        subscribeBtn.classList.remove("bg-green-500", "hover:bg-green-600")
        subscribeBtn.classList.add("bg-blue-500", "hover:bg-blue-600")
        subscribeBtn.removeEventListener("click", this.unsubscribe.bind(this))
        subscribeBtn.addEventListener("click", this.subscribe.bind(this))
      }
    }
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }
    return outputArray
  }

  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }
}
