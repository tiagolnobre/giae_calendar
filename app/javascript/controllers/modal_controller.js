import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Prevent body scroll when modal is open
    this.preventBodyScroll()
  }

  disconnect() {
    // Restore body scroll when modal is closed
    this.restoreBodyScroll()
  }

  preventBodyScroll() {
    // Calculate scrollbar width to prevent layout shift
    const scrollbarWidth = window.innerWidth - document.documentElement.clientWidth
    
    // Store original styles
    this.originalOverflow = document.body.style.overflow
    this.originalPaddingRight = document.body.style.paddingRight
    
    // Hide overflow and add padding to compensate for scrollbar
    document.body.style.overflow = "hidden"
    if (scrollbarWidth > 0) {
      document.body.style.paddingRight = `${scrollbarWidth}px`
    }
  }

  restoreBodyScroll() {
    // Restore original styles
    document.body.style.overflow = this.originalOverflow || ""
    document.body.style.paddingRight = this.originalPaddingRight || ""
  }

  close() {
    // Restore body scroll first
    this.restoreBodyScroll()
    // Clear the turbo frame content to close the modal
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
