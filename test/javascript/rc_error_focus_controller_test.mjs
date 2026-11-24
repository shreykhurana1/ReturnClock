import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = await readFile(new URL("../../app/javascript/controllers/rc_error_focus_controller.js", import.meta.url), "utf8")
const { default: ErrorFocus } = await import(`data:text/javascript,${encodeURIComponent(source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}'))}`)

test("focuses the error summary itself, including summaries outside a form", () => {
  const controller = new ErrorFocus()
  let focused = false
  controller.element = { focus() { focused = true } }
  controller.connect()
  assert.equal(focused, true)
})
