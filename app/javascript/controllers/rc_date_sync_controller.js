// Keeps Purchase Date, Return Window and Return By in step as the shopper types.
import { Controller } from "@hotwired/stimulus"

const DAY_MS = 86400000
const toTime = value => Date.parse(`${value}T00:00:00Z`)

export default class extends Controller {
  static targets = ["purchaseDate", "window", "returnBy"]

  // A new purchase date or window moves the deadline; without a window, the window follows the deadline.
  startOrWindowChanged() {
    const start = toTime(this.purchaseDateTarget.value)
    const days = parseInt(this.windowTarget.value, 10)

    if (!isNaN(start) && days >= 0) {
      this.returnByTarget.value = new Date(start + days * DAY_MS).toISOString().slice(0, 10)
    } else {
      this.returnByChanged()
    }
  }

  returnByChanged() {
    const start = toTime(this.purchaseDateTarget.value)
    const end = toTime(this.returnByTarget.value)

    if (!isNaN(start) && !isNaN(end)) this.windowTarget.value = end >= start ? (end - start) / DAY_MS : ""
  }
}
