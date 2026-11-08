import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "editorTitle", "fields", "statusSection", "submitButton", "labels", "statusDialog", "statusItem", "statusSelect", "deleteDialog", "deleteMessage"]

  connect() {
    this.fieldsTargets.forEach(fieldset => { fieldset.disabled = false })
  }

  new(event) {
    event.preventDefault()
    this.editorTarget.querySelector("form").reset()
    const policy = this.editorTarget.querySelector('[data-controller="rc-store-policy"]')
    this.application.getControllerForElementAndIdentifier(policy, "rc-store-policy").setMode(policy.dataset.rcStorePolicyDefaultModeValue)
    this.statusSectionTarget.hidden = true
    this.editorTitleTarget.textContent = this.labelsTarget.dataset.add
    this.submitButtonTarget.value = this.labelsTarget.dataset.add
    this.open(this.editorTarget, event)
  }

  edit(event) {
    const purchase = this.purchase(event)
    this.editorTarget.querySelector("form").reset()
    for (const [field, value] of Object.entries(purchase)) {
      const input = this.editorTarget.querySelector(`[name="purchase[${field}]"]`)
      if (input) input.value = value
    }
    const policy = this.editorTarget.querySelector('[data-controller="rc-store-policy"]')
    const storePolicy = this.application.getControllerForElementAndIdentifier(policy, "rc-store-policy")
    if (purchase.store_policy_id) {
      storePolicy.showExisting()
    } else {
      storePolicy.showNew()
      policy.querySelector('[name="store_policy[store_name]"]').value = purchase.store_name
      policy.querySelector('[name="store_policy[window_days]"]').value = purchase.window_days
    }
    this.statusSectionTarget.hidden = false
    this.editorTitleTarget.textContent = this.labelsTarget.dataset.edit
    this.submitButtonTarget.value = this.labelsTarget.dataset.save
    this.open(this.editorTarget, event)
  }

  status(event) {
    const purchase = this.purchase(event)
    this.statusItemTarget.textContent = purchase.item_name
    this.statusSelectTarget.value = purchase.status
    this.open(this.statusDialogTarget, event)
  }

  delete(event) {
    this.deleteMessageTarget.textContent = this.labelsTarget.dataset.delete.replace("%{item}", this.purchase(event).item_name)
    this.open(this.deleteDialogTarget, event)
  }

  purchase(event) {
    return JSON.parse(event.currentTarget.closest(".purchase-card").dataset.purchasePreview)
  }

  open(dialog, event) {
    event.preventDefault()
    const menu = event.currentTarget.closest("details")
    this.returnFocus = menu ? menu.querySelector("summary") : event.currentTarget
    if (menu) menu.open = false
    dialog.querySelector("[data-preview-message]").hidden = true
    dialog.showModal()
  }

  pending(event) {
    event.preventDefault()
    const message = event.currentTarget.closest("dialog").querySelector("[data-preview-message]")
    message.hidden = false
    message.focus()
  }

  close(event) {
    event.preventDefault()
    event.currentTarget.closest("dialog").close()
  }

  backdrop(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }

  restoreFocus() {
    this.returnFocus?.focus()
  }
}
