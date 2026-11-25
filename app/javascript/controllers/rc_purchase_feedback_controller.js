// Shows, as the shopper types, what the purchase form would save and what it would reject.
// It never submits anything: the purchase is only saved when the form itself is submitted.
import { Controller } from "@hotwired/stimulus"

const DAY = 86400000
const NO_DAYS_LEFT = ["keeping", "refunded"]

export default class extends Controller {
  static targets = ["itemName", "price", "purchaseDate", "policy", "status", "store", "savedPrice", "returnBy", "daysLeft", "daysLeftLabel", "error"]
  static values = { today: String, savedDate: String, savedPolicy: String, savedReturnBy: String }

  connect() {
    this.touched = new Set()
    this.render()
  }

  // Errors only show for fields the shopper has already used, so a fresh form starts quiet.
  refresh(event) {
    const field = event.target.name?.match(/\[(\w+)\]$/)?.[1]
    if (field) this.touched.add(field)
    this.render()
  }

  render() {
    const price = this.priceResult()
    this.renderErrors(price)
    this.savedPriceTarget.textContent = price.error ? "Fix the price to save" : this.currency(price.amount)
    this.renderStore()
    this.renderDeadline()
  }

  renderErrors(price) {
    const problems = {
      item_name: this.itemNameTarget.value.trim() === "" ? "Item name can't be blank" : null,
      price: price.error || null,
      purchase_date: this.purchaseDateTarget.value === "" ? "Purchase date can't be blank" : null,
      store_policy_id: this.hasPolicyTarget && this.policyTarget.value === "" ? "Store policy must exist" : null
    }

    this.errorTargets.forEach(element => {
      const message = this.touched.has(element.dataset.field) ? problems[element.dataset.field] : null
      element.textContent = message || ""
      this.markInvalid(element, Boolean(message))
    })
  }

  // Flags the field for assistive tech without disturbing errors the server already rendered.
  markInvalid(error, invalid) {
    const input = this.inputFor(error.dataset.field)
    if (!input) return

    const ids = (input.getAttribute("aria-describedby") || "").split(" ").filter(id => id && id !== error.id)
    if (invalid) {
      input.setAttribute("aria-invalid", "true")
      input.setAttribute("aria-describedby", [...ids, error.id].join(" "))
    } else {
      if (input.dataset.liveInvalid) input.removeAttribute("aria-invalid")
      ids.length ? input.setAttribute("aria-describedby", ids.join(" ")) : input.removeAttribute("aria-describedby")
    }
    input.dataset.liveInvalid = invalid ? "true" : ""
  }

  inputFor(field) {
    return { item_name: this.itemNameTarget, price: this.priceTarget, purchase_date: this.purchaseDateTarget, store_policy_id: this.hasPolicyTarget ? this.policyTarget : null }[field]
  }

  // A blank price is saved as $0.00.
  priceResult() {
    const input = this.priceTarget
    const value = input.value.trim()
    if (input.validity.badInput) return { error: "Price is not a number" }
    if (value === "") return { amount: 0 }

    const amount = Number(value)
    if (!Number.isFinite(amount)) return { error: "Price is not a number" }
    if (amount < 0) return { error: "Price must be greater than or equal to 0" }
    return { amount }
  }

  renderStore() {
    if (!this.hasPolicyTarget) return

    const option = this.policyTarget.selectedOptions[0]
    this.storeTarget.textContent = this.policyTarget.value ? option.textContent : "Choose a store policy"
  }

  renderDeadline() {
    const returnBy = this.returnByMs()
    this.returnByTarget.textContent = returnBy === null ? "Choose a purchase date and store policy" : this.longDate(returnBy)
    this.daysLeftTarget.textContent = returnBy === null ? "—" : Math.round((returnBy - this.parseDate(this.todayValue)) / DAY)

    // Like the purchase card, decided purchases show no countdown.
    this.daysLeftLabelTarget.hidden = this.daysLeftTarget.hidden = NO_DAYS_LEFT.includes(this.statusTarget.value)
  }

  // Mirrors Purchase: a saved deadline stands until the date or policy changes, then it is recalculated.
  returnByMs() {
    const date = this.purchaseDateTarget.value
    if (!date) return null

    const policyId = this.hasPolicyTarget ? this.policyTarget.value : ""
    if (this.savedReturnByValue && date === this.savedDateValue && policyId === this.savedPolicyValue) {
      return this.parseDate(this.savedReturnByValue)
    }

    const window = this.hasPolicyTarget ? Number(this.policyTarget.selectedOptions[0]?.dataset.windowDays) : NaN
    return policyId && Number.isFinite(window) ? this.parseDate(date) + window * DAY : null
  }

  parseDate(value) {
    const [year, month, day] = value.split("-").map(Number)
    return Date.UTC(year, month - 1, day)
  }

  longDate(ms) {
    return new Intl.DateTimeFormat(document.documentElement.lang || "en", { dateStyle: "long", timeZone: "UTC" }).format(ms)
  }

  currency(amount) {
    return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(amount)
  }
}
