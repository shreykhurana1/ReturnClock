import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = await readFile(new URL("../../app/javascript/controllers/rc_error_focus_controller.js", import.meta.url), "utf8")
const { default: ErrorFocus } = await import(`data:text/javascript,${encodeURIComponent(source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}'))}`)

test("focuses the server-rendered error summary when present", () => {
  const alert = { tabIndex: null, focused: false, focus() { this.focused = true } }
  const controller = new ErrorFocus()
  controller.element = { querySelector() { return alert } }

  controller.connect()

  assert.equal(alert.tabIndex, -1)
  assert.equal(alert.focused, true)
})

test("leaves focus alone when there is no error summary", () => {
  const controller = new ErrorFocus()
  controller.element = { querySelector() { return null } }

  assert.doesNotThrow(() => controller.connect())
})
