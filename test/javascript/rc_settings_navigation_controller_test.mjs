import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = await readFile(new URL("../../app/javascript/controllers/rc_settings_navigation_controller.js", import.meta.url), "utf8")
const { default: Navigation } = await import(`data:text/javascript,${encodeURIComponent(source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}'))}`)

test("hash changes keep the active section and aria-current in sync", () => {
  const originalWindow = globalThis.window
  globalThis.window = { location: { hash: "#security" } }
  try {
    const links = ["#account", "#security"].map(href => ({
      active: false, attributes: {},
      getAttribute: () => href,
      classList: { toggle(_name, active) { links.find(link => link.getAttribute() === href).active = active } },
      setAttribute(name, value) { this.attributes[name] = value },
      removeAttribute(name) { delete this.attributes[name] }
    }))
    const controller = new Navigation()
    controller.element = { querySelectorAll: () => links }
    controller.connect()
    assert.equal(links[1].attributes["aria-current"], "location")
    globalThis.window.location.hash = ""
    controller.sync()
    assert.deepEqual(links.map(link => link.active), [true, false])
    assert.equal(links[0].attributes["aria-current"], "location")
    assert.equal(links[1].attributes["aria-current"], undefined)
  } finally {
    globalThis.window = originalWindow
  }
})
