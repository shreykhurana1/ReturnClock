// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

class RcErrorFocus extends HTMLElement {
  connectedCallback() {
    const alert = this.querySelector("[role='alert']")
    if (!alert) return

    alert.tabIndex = -1
    alert.focus()
  }
}

if (!customElements.get("rc-error-focus")) {
  customElements.define("rc-error-focus", RcErrorFocus)
}
