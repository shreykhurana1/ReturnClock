import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dismiss(event) {
    if (!this.element.contains(event.target)) this.element.open = false
  }
}
