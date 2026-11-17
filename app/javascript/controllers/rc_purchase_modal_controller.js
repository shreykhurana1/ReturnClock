import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["frame", "title"]

  open() {
    if (!this.frameTarget.querySelector("form")) return
    this.titleTarget.textContent = this.frameTarget.querySelector("h1").textContent
    if (!this.element.open) {
      this.previousOverflow = document.body.style.overflow
      this.element.showModal()
      document.body.style.overflow = "hidden"
    }
    const field = this.frameTarget.querySelector("[role='alert'], input:not([type='hidden']):not([disabled]), select")
    if (field) {
      if (field.matches("[role='alert']")) field.tabIndex = -1
      field.focus()
    }
  }

  dismiss(event) {
    if (event.target === this.element || event.target.closest("[data-modal-dismiss]")) {
      event.preventDefault()
      this.close()
    }
  }

  close() {
    this.element.close()
  }

  reset() {
    document.body.style.overflow = this.previousOverflow || ""
    this.frameTarget.removeAttribute("src")
    this.frameTarget.replaceChildren()
  }

  navigate(event) {
    event.preventDefault()
    this.close()
    event.detail.visit(event.detail.response)
  }

  async saved(event) {
    const response = event.detail.fetchResponse.response
    if (response.ok && response.redirected && event.target.matches("form") && (event.target.querySelector("[name='purchase[item_name]']") || event.target.dataset.modalSave === "true")) {
      event.preventDefault()
      // Reuse the followed redirect's HTML: another GET would consume its flash notice.
      const responseHTML = await event.detail.fetchResponse.responseHTML
      this.close()
      Turbo.cache.clear()
      Turbo.visit(response.url, {
        shouldCacheSnapshot: false,
        response: { statusCode: response.status, redirected: response.redirected, responseHTML }
      })
    }
  }
}
