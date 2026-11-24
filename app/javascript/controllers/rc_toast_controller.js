import { Controller } from "@hotwired/stimulus"

const VISIBLE_MS = 2200
const EXIT_MS = 180

export default class extends Controller {
  connect() {
    this.enterFrame = requestAnimationFrame(() => this.element.classList.add("rc-toast-visible"))
    this.dismissTimer = setTimeout(() => this.dismiss(), VISIBLE_MS)
  }

  disconnect() {
    cancelAnimationFrame(this.enterFrame)
    clearTimeout(this.dismissTimer)
    clearTimeout(this.removeTimer)
  }

  dismiss() {
    this.element.classList.remove("rc-toast-visible")
    this.element.classList.add("rc-toast-leaving")
    this.removeTimer = setTimeout(() => this.element.remove(), EXIT_MS)
  }
}
