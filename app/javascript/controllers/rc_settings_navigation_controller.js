// Keep the highlighted account settings section aligned with the selected anchor.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.sync()
  }

  sync() {
    this.highlight(window.location.hash || "#account")
  }

  activate(event) {
    const link = event.target.closest('a[href^="#"]')
    if (link) this.highlight(link.getAttribute("href"))
  }

  highlight(hash) {
    this.element.querySelectorAll('a[href^="#"]').forEach(link => {
      const selected = link.getAttribute("href") === hash
      link.classList.toggle("active", selected)
      if (selected) {
        link.setAttribute("aria-current", "location")
      } else {
        link.removeAttribute("aria-current")
      }
    })
  }
}
