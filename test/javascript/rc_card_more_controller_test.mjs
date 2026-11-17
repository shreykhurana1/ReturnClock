import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = await readFile(new URL("../../app/javascript/controllers/rc_card_more_controller.js", import.meta.url), "utf8")
const { default: CardMore } = await import(`data:text/javascript,${encodeURIComponent(source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}'))}`)

test("outside clicks close More actions without interrupting clicks inside", () => {
  const controller = new CardMore()
  const inside = {}
  controller.element = { open: true, contains: target => target === inside }

  controller.dismiss({ target: inside })
  assert.equal(controller.element.open, true)

  controller.dismiss({ target: {} })
  assert.equal(controller.element.open, false)

  controller.dismiss({ target: {} })
  assert.equal(controller.element.open, false)
})
