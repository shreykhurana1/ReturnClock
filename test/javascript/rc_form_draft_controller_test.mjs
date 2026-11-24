import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = await readFile(new URL("../../app/javascript/controllers/rc_form_draft_controller.js", import.meta.url), "utf8")
const { default: FormDraft } = await import(`data:text/javascript,${encodeURIComponent(source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}'))}`)

const storage = new Map()
globalThis.sessionStorage = {
  getItem(key) { return storage.has(key) ? storage.get(key) : null },
  setItem(key, value) { storage.set(key, String(value)) },
  removeItem(key) { storage.delete(key) }
}

function field(name, value, type = "text") {
  return { name, value, type, disabled: false, checked: true }
}

function buildController(fields = [ field("purchase[item_name]", ""), field("purchase[price]", "") ], serverError = false, withStatus = false) {
  const controller = new FormDraft()
  controller.keyValue = "purchase|new|1"
  controller.submitting = false
  controller.completed = false
  controller.noticeTarget = { hidden: true }
  controller.noticeTextTarget = { textContent: "" }
  controller.discardTarget = { hidden: false }
  controller.hasNoticeTarget = true
  controller.hasNoticeTextTarget = true
  controller.hasDiscardTarget = true
  controller.hasStatusTarget = withStatus
  if (withStatus) controller.statusTarget = { hidden: true, textContent: "" }
  controller.element = {
    reset() { this.resetCalled = true },
    querySelector() { return serverError ? {} : null },
    querySelectorAll() { return fields }
  }
  return controller
}

function draftValues(controller, values) {
  controller.formValues = () => values
}

test("saves visible fields and restores them with a notice", () => {
  const fields = [ field("purchase[item_name]", ""), field("purchase[price]", ""), field("authenticity_token", "secret", "hidden") ]
  const first = buildController(fields)
  draftValues(first, { "purchase[item_name]": "Notebook", "purchase[price]": "12.50" })
  first.save()

  const second = buildController(fields)
  second.restore()

  assert.equal(fields[0].value, "Notebook")
  assert.equal(fields[1].value, "12.50")
  assert.equal(second.noticeTarget.hidden, false)
  assert.equal(second.noticeTextTarget.textContent, "Unsaved changes restored.")
  assert.equal(second.discardTarget.hidden, false)
})

test("does not restore over server validation errors", () => {
  const fields = [ field("purchase[item_name]", "") ]
  const first = buildController(fields)
  draftValues(first, { "purchase[item_name]": "Draft value" })
  first.save()

  const second = buildController(fields, true)
  second.restore()

  assert.equal(fields[0].value, "")
  assert.equal(second.noticeTarget.hidden, true)
})

test("ignores and clears an expired draft with an explanation", () => {
  const fields = [ field("purchase[item_name]", "") ]
  const first = buildController(fields)
  draftValues(first, { "purchase[item_name]": "Old value" })
  first.save()

  const raw = JSON.parse(sessionStorage.getItem(first.storageKey))
  raw.savedAt = Date.now() - 25 * 60 * 60 * 1000
  sessionStorage.setItem(first.storageKey, JSON.stringify(raw))

  const second = buildController(fields)
  second.restore()

  assert.equal(fields[0].value, "")
  assert.equal(sessionStorage.getItem(first.storageKey), null)
  assert.equal(second.noticeTarget.hidden, false)
  assert.match(second.noticeTextTarget.textContent, /expired/)
  assert.equal(second.discardTarget.hidden, true)
})

test("discarding clears the draft, resets the form, and hides the notice", () => {
  const fields = [ field("purchase[item_name]", "Typed") ]
  const controller = buildController(fields)
  draftValues(controller, { "purchase[item_name]": "Typed" })
  controller.save()
  controller.noticeTarget.hidden = false

  controller.discard({ preventDefault() {} })

  assert.equal(sessionStorage.getItem(controller.storageKey), null)
  assert.equal(controller.element.resetCalled, true)
  assert.equal(controller.noticeTarget.hidden, true)
})

test("shows a quiet draft-saved status after a pause", async () => {
  const fields = [ field("purchase[item_name]", "Typed") ]
  const controller = buildController(fields, false, true)
  draftValues(controller, { "purchase[item_name]": "Typed" })

  controller.save()
  await new Promise(resolve => setTimeout(resolve, 450))

  assert.equal(controller.statusTarget.hidden, false)
  assert.equal(controller.statusTarget.textContent, "Draft saved")
  controller.hideDraftStatus()
})

test("successful saves clear the draft, failures keep a copy, and policy handoffs keep it", () => {
  const fields = [ field("purchase[item_name]", "Typed") ]

  const saving = buildController(fields)
  draftValues(saving, { "purchase[item_name]": "Typed" })
  saving.save()
  saving.handleSubmitEnd({ detail: { formSubmission: { formElement: saving.element }, success: true } })
  assert.equal(sessionStorage.getItem(saving.storageKey), null)

  const failing = buildController(fields)
  draftValues(failing, { "purchase[item_name]": "Still typed" })
  failing.handleSubmitStart({ detail: { formSubmission: { formElement: failing.element, submitter: { hasAttribute: () => false } } } })
  failing.handleSubmitEnd({ detail: { formSubmission: { formElement: failing.element }, success: false } })
  assert.notEqual(sessionStorage.getItem(failing.storageKey), null)

  const handoff = buildController(fields)
  draftValues(handoff, { "purchase[item_name]": "Keep me" })
  handoff.save()
  handoff.handleSubmitStart({ detail: { formSubmission: { formElement: handoff.element, submitter: { hasAttribute: () => true } } } })
  handoff.handleSubmitEnd({ detail: { formSubmission: { formElement: handoff.element }, success: true } })
  assert.notEqual(sessionStorage.getItem(handoff.storageKey), null)
})
