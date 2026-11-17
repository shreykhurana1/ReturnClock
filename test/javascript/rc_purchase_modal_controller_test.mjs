import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = await readFile(new URL("../../app/javascript/controllers/rc_purchase_modal_controller.js", import.meta.url), "utf8")
const { default: Modal, visits, cacheClears } = await import(`data:text/javascript,${encodeURIComponent(source
  .replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
  .replace('import { Turbo } from "@hotwired/turbo-rails"', 'export const visits = []; export const cacheClears = []; const Turbo = { cache: { clear: () => cacheClears.push(true) }, visit: (...args) => visits.push(args) }'))}`)

test("successful purchase, policy, and delete forms render the already-fetched redirect", async () => {
  for (const purchaseForm of [true, false]) {
    const controller = new Modal()
    let closed = false
    let prevented = false
    controller.close = () => { closed = true }
    const responseHTML = "<main>Saved successfully.</main>"
    const response = { ok: true, redirected: true, status: 200, url: "http://example.test/dashboard" }
    const previousClears = cacheClears.length
    await controller.saved({
      preventDefault: () => { prevented = true },
      target: { matches: () => true, querySelector: () => purchaseForm, dataset: { modalSave: String(!purchaseForm) } },
      detail: { fetchResponse: { response, responseHTML: Promise.resolve(responseHTML) } }
    })
    assert.equal(prevented, true)
    assert.equal(closed, true)
    assert.equal(cacheClears.length, previousClears + 1)
    assert.deepEqual(visits.at(-1), [response.url, { shouldCacheSnapshot: false, response: { statusCode: 200, redirected: true, responseHTML } }])
  }
})

test("validation failures and policy-to-purchase redirects remain in the frame", async () => {
  const controller = new Modal()
  controller.close = () => assert.fail("the modal must remain open")
  for (const [ok, redirected, modalSave] of [[false, false, "true"], [true, true, "false"]]) {
    const visitCount = visits.length
    await controller.saved({
      preventDefault: () => assert.fail("Turbo must handle this frame response"),
      target: { matches: () => true, querySelector: () => false, dataset: { modalSave } },
      detail: { fetchResponse: { response: { ok, redirected } } }
    })
    assert.equal(visits.length, visitCount)
  }
})

test("frame-missing navigation reuses the Response rather than fetching its URL again", () => {
  const controller = new Modal()
  let closed = false
  controller.close = () => { closed = true }
  const response = { url: "http://example.test/history" }
  controller.navigate({ preventDefault() {}, detail: { response, visit: value => assert.equal(value, response) } })
  assert.equal(closed, true)
})
