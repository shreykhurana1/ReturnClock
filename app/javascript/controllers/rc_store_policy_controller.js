// 1. Switch store input modes in the browser without creating database records.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["existing", "new", "existingButton", "newButton", "existingSelect", "newName", "newDays"]
  static values = { defaultMode: String }

  connect() {
    this.setMode(this.defaultModeValue === "new" ? "new" : "existing")
  }

  showExisting() {
    this.setMode("existing")
  }

  showNew() {
    this.setMode("new")
  }

  setMode(mode) {
    const useExisting = mode === "existing"
    this.existingTarget.hidden = !useExisting
    this.newTarget.hidden = useExisting
    this.existingButtonTarget.setAttribute("aria-pressed", String(useExisting))
    this.newButtonTarget.setAttribute("aria-pressed", String(!useExisting))
    this.existingButtonTarget.classList.toggle("active", useExisting)
    this.newButtonTarget.classList.toggle("active", !useExisting)
    this.existingSelectTarget.disabled = !useExisting
    this.existingSelectTarget.required = useExisting
    this.newNameTarget.disabled = useExisting
    this.newNameTarget.required = !useExisting
    this.newDaysTarget.disabled = useExisting
    this.newDaysTarget.required = !useExisting
  }
}
