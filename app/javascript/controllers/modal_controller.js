import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Prevent body scroll when modal is open
    document.body.style.overflow = "hidden"
  }

  disconnect() {
    // Restore body scroll when modal is closed
    document.body.style.overflow = ""
  }

  close() {
    this.element.closest("turbo-frame").innerHTML = ""
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  // Close on Escape key
  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}
