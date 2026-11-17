import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = await readFile(new URL("../../app/javascript/controllers/rc_tooltip_controller.js", import.meta.url), "utf8")
const { default: Tooltip } = await import(`data:text/javascript,${encodeURIComponent(source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}'))}`)

test("tooltip appears synchronously, closes, and can immediately reopen", () => {
  const controller = new Tooltip()
  controller.tooltipTarget = { hidden: true }
  controller.show()
  assert.equal(controller.tooltipTarget.hidden, false)
  controller.hide()
  assert.equal(controller.tooltipTarget.hidden, true)
  controller.show()
  assert.equal(controller.tooltipTarget.hidden, false)
})
