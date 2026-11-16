// Saves an existing purchase as the shopper edits it, without leaving the page.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), 600)
  }

  async save() {
    const body = new FormData(this.element)
    body.append("autosave", "1")
    this.show("Saving…")

    try {
      const response = await fetch(this.element.action, { method: "POST", body, headers: { Accept: "application/json" } })
      if (response.redirected) return this.show("Please sign in again to save changes.", true)
      if (response.ok) return this.show("All changes saved")

      const { errors } = await response.json()
      this.show(`Not saved: ${errors.join(" ")}`, true)
    } catch {
      this.show("Not saved. Check your connection.", true)
    }
  }

  show(message, failed = false) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("rc-autosave-failed", failed)
  }
}
