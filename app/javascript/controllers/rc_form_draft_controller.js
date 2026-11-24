import { Controller } from "@hotwired/stimulus"

const EXPIRY_MS = 24 * 60 * 60 * 1000
const STATUS_DELAY_MS = 400
const STATUS_VISIBLE_MS = 2000
const IGNORED_INPUT_TYPES = new Set([ "hidden", "submit", "button", "file", "reset", "image" ])

export default class extends Controller {
  static targets = ["notice", "noticeText", "discard", "status"]
  static values = { key: String, restored: Boolean }

  connect() {
    this.save = this.save.bind(this)
    this.handleSubmitStart = this.handleSubmitStart.bind(this)
    this.handleSubmitEnd = this.handleSubmitEnd.bind(this)
    this.handleBeforeVisit = this.handleBeforeVisit.bind(this)
    this.handleBeforeUnload = this.handleBeforeUnload.bind(this)
    this.submitting = false
    this.completed = false

    document.addEventListener("turbo:submit-start", this.handleSubmitStart)
    document.addEventListener("turbo:submit-end", this.handleSubmitEnd)
    document.addEventListener("turbo:before-visit", this.handleBeforeVisit)
    window.addEventListener("beforeunload", this.handleBeforeUnload)

    if (this.restoredValue) {
      this.persist()
      this.showNotice("Unsaved changes restored.", true)
    } else {
      this.restore()
    }
  }

  disconnect() {
    document.removeEventListener("turbo:submit-start", this.handleSubmitStart)
    document.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
    document.removeEventListener("turbo:before-visit", this.handleBeforeVisit)
    window.removeEventListener("beforeunload", this.handleBeforeUnload)
    this.hideDraftStatus()
  }

  save() {
    if (!this.keyValue || this.submitting || this.completed) return
    if (this.persist()) this.queueDraftStatus()
  }

  persist() {
    if (!this.storageAvailable) {
      this.showNotice("Draft recovery is unavailable in this browser.", false)
      return false
    }

    const values = this.formValues()
    if (!Object.keys(values).length) return false

    try {
      sessionStorage.setItem(this.storageKey, JSON.stringify({ savedAt: Date.now(), values }))
      return true
    } catch (_) {
      this.showNotice("Draft recovery is unavailable in this browser.", false)
      return false
    }
  }

  restore() {
    if (!this.keyValue || this.hasServerErrors()) return

    const draft = this.readDraft()
    if (!draft) return

    let restored = false
    this.fields.forEach(field => {
      if (!Object.prototype.hasOwnProperty.call(draft.values, field.name)) return
      if (field.value === draft.values[field.name]) return
      field.value = draft.values[field.name]
      restored = true
    })
    if (restored) this.showNotice("Unsaved changes restored.", true)
  }

  discard(event) {
    event?.preventDefault()
    this.clearDraft()
    this.element.reset()
    this.hideNotice()
    this.hideDraftStatus()
  }

  handleSubmitStart(event) {
    if (this.submittedForm(event) !== this.element) return

    this.submitting = true
    this.handoffSubmission = Boolean(event.detail?.formSubmission?.submitter?.hasAttribute("formaction"))
    this.hideDraftStatus()
  }

  handleSubmitEnd(event) {
    if (this.submittedForm(event) !== this.element) return

    this.submitting = false
    if (event.detail?.success) {
      this.completed = true
      if (!this.handoffSubmission && !this.redirectedToSignIn(event)) this.clearDraft()
      this.hideNotice()
      this.hideDraftStatus()
    } else {
      this.save()
    }
  }

  redirectedToSignIn(event) {
    const response = event.detail?.fetchResponse?.response
    if (!response?.redirected) return false

    try {
      return new URL(response.url).pathname.startsWith("/session")
    } catch (_) {
      return false
    }
  }

  handleBeforeVisit() {
    if (!this.completed && !this.submitting) this.save()
  }

  handleBeforeUnload() {
    if (!this.completed && !this.submitting) this.save()
  }

  submittedForm(event) {
    return event.detail?.formSubmission?.formElement || event.target
  }

  hasServerErrors() {
    return Boolean(this.element.querySelector("[role='alert']"))
  }

  get fields() {
    return Array.from(this.element.querySelectorAll("input, select, textarea")).filter(field => {
      if (!field.name || field.disabled) return false
      if (IGNORED_INPUT_TYPES.has(field.type)) return false
      if ((field.type === "radio" || field.type === "checkbox") && !field.checked) return false
      return true
    })
  }

  formValues() {
    const values = {}
    this.fields.forEach(field => {
      values[field.name] = field.value
    })
    return values
  }

  readDraft() {
    if (!this.storageAvailable) {
      this.showNotice("Draft recovery is unavailable in this browser.", false)
      return null
    }

    try {
      const raw = sessionStorage.getItem(this.storageKey)
      if (!raw) return null

      const draft = JSON.parse(raw)
      if (!draft?.values || !draft.savedAt) {
        this.clearDraft()
        return null
      }
      if (Date.now() - draft.savedAt > EXPIRY_MS) {
        this.clearDraft()
        this.showNotice("Your saved draft expired. Start fresh.", false)
        return null
      }
      return draft
    } catch (_) {
      this.clearDraft()
      return null
    }
  }

  showNotice(text, canDiscard) {
    if (!this.hasNoticeTarget) return

    if (this.hasNoticeTextTarget) this.noticeTextTarget.textContent = text
    if (this.hasDiscardTarget) this.discardTarget.hidden = !canDiscard
    this.noticeTarget.hidden = false
  }

  hideNotice() {
    if (this.hasNoticeTarget) this.noticeTarget.hidden = true
  }

  queueDraftStatus() {
    if (!this.hasStatusTarget) return

    clearTimeout(this.statusTimer)
    this.statusTimer = setTimeout(() => {
      this.statusTarget.textContent = "Draft saved"
      this.statusTarget.hidden = false
      clearTimeout(this.statusHideTimer)
      this.statusHideTimer = setTimeout(() => this.hideDraftStatus(), STATUS_VISIBLE_MS)
    }, STATUS_DELAY_MS)
  }

  hideDraftStatus() {
    clearTimeout(this.statusTimer)
    clearTimeout(this.statusHideTimer)
    if (this.hasStatusTarget) {
      this.statusTarget.hidden = true
      this.statusTarget.textContent = ""
    }
  }

  clearDraft() {
    try {
      sessionStorage.removeItem(this.storageKey)
    } catch (_) {}
  }

  get storageAvailable() {
    try {
      return typeof sessionStorage !== "undefined" && sessionStorage !== null
    } catch (_) {
      return false
    }
  }

  get storageKey() {
    return `returnclock:draft:${this.keyValue}`
  }
}
