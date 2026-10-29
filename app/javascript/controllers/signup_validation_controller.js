import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "confirmation", "passwordError", "confirmationError", "serverErrors"]

  validate() {
    const password = this.passwordTarget.value
    const confirmation = this.confirmationTarget.value
    let message = ""

    if (password && Array.from(password).length < 8) {
      message = "Use at least 8 characters."
    } else if (new TextEncoder().encode(password).length > 72) {
      message = "Password is too long. Use a shorter password."
    } else if (password && !(/[A-Z]/.test(password) && /[a-z]/.test(password) && /[0-9]/.test(password) && /[^A-Za-z0-9 \t\r\n\f\v]/.test(password))) {
      message = "Include uppercase and lowercase letters, a number, and a symbol."
    }

    this.serverErrorsTargets.forEach(element => { element.hidden = true })
    this.setValidity(this.passwordTarget, this.passwordErrorTarget, message)
    this.passwordTarget.setAttribute("aria-describedby", "password-hint password-client-error")
    this.setValidity(this.confirmationTarget, this.confirmationErrorTarget,
      confirmation && confirmation !== password ? "Passwords do not match." : "")
    this.confirmationTarget.setAttribute("aria-describedby", "confirmation-client-error")
  }

  submit(event) {
    this.validate()
    if (!this.element.checkValidity()) {
      event.preventDefault()
      this.element.reportValidity()
    }
  }

  setValidity(input, output, message) {
    input.setCustomValidity(message)
    input.setAttribute("aria-invalid", String(message !== ""))
    output.textContent = message
    output.hidden = message === ""
  }
}
