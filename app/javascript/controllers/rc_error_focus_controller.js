import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const alert = this.element.querySelector("[role='alert']")
    if (!alert) return

    alert.tabIndex = -1
    alert.focus()
  }
}
