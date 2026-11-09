// Filter history cards in the browser without accessing or modifying backend data.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "button", "empty"]

  filter(event) {
    const status = event.currentTarget.dataset.rcPurchaseFilterValue
    let visible = 0

    this.buttonTargets.forEach(button => {
      const active = button.dataset.rcPurchaseFilterValue === status
      button.classList.toggle("active", active)
      button.setAttribute("aria-pressed", String(active))
    })

    this.cardTargets.forEach(card => {
      const show = status === "all" || card.dataset.status === status
      card.hidden = !show
      if (show) visible += 1
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible !== 0
  }
}
