import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

globalThis.document = { documentElement: { lang: "en" } }

const source = await readFile(new URL("../../app/javascript/controllers/rc_purchase_feedback_controller.js", import.meta.url), "utf8")
const { default: Feedback } = await import(`data:text/javascript,${encodeURIComponent(source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}'))}`)

function field(value = "", extra = {}) {
  const attributes = {}
  return {
    value, dataset: {}, validity: { badInput: false }, ...extra,
    getAttribute: name => attributes[name] ?? null,
    setAttribute: (name, text) => { attributes[name] = text },
    removeAttribute: name => { delete attributes[name] }
  }
}

function option(text, windowDays) {
  return { textContent: text, dataset: { windowDays: String(windowDays) } }
}

function build({ values = {}, policies = true, status = "active", saved = {} } = {}) {
  const controller = new Feedback()
  const campus = option("Campus Store — 30 days", 30)
  const prompt = { textContent: "Select a store policy", dataset: {} }
  const policy = field(values.policy ?? "")
  Object.defineProperty(policy, "selectedOptions", { get: () => [ policy.value ? campus : prompt ] })
  const errors = [ "item_name", "price", "purchase_date", "store_policy_id" ].map(name => ({ id: `${name}-live`, dataset: { field: name }, textContent: "" }))

  Object.assign(controller, {
    itemNameTarget: field(values.item ?? ""), priceTarget: field(values.price ?? ""), purchaseDateTarget: field(values.date ?? ""),
    hasPolicyTarget: policies, policyTarget: policy, statusTarget: field(status),
    storeTarget: { textContent: "" }, savedPriceTarget: { textContent: "" }, returnByTarget: { textContent: "" },
    daysLeftTarget: { textContent: "", hidden: false }, daysLeftLabelTarget: { hidden: false }, errorTargets: errors,
    todayValue: "2026-11-08", savedDateValue: saved.date ?? "", savedPolicyValue: saved.policy ?? "", savedReturnByValue: saved.returnBy ?? ""
  })
  controller.connect()
  return controller
}

const message = (controller, name) => controller.errorTargets.find(error => error.dataset.field === name).textContent

test("starts quiet: no errors before the shopper touches a field, and a blank price saves as $0.00", () => {
  const controller = build()
  assert.deepEqual(controller.errorTargets.map(error => error.textContent), [ "", "", "", "" ])
  assert.equal(controller.savedPriceTarget.textContent, "$0.00")
  assert.equal(controller.storeTarget.textContent, "Choose a store policy")
  assert.equal(controller.returnByTarget.textContent, "Choose a purchase date and store policy")
  assert.equal(controller.daysLeftTarget.textContent, "—")
})

test("reports the server's validation messages for a field once it has been used", () => {
  const controller = build({ values: { item: "  ", price: "-1" } })
  controller.refresh({ target: { name: "purchase[item_name]" } })
  controller.refresh({ target: { name: "purchase[price]" } })
  controller.refresh({ target: { name: "purchase[purchase_date]" } })
  controller.refresh({ target: { name: "purchase[store_policy_id]" } })

  assert.equal(message(controller, "item_name"), "Item name can't be blank")
  assert.equal(message(controller, "price"), "Price must be greater than or equal to 0")
  assert.equal(message(controller, "purchase_date"), "Purchase date can't be blank")
  assert.equal(message(controller, "store_policy_id"), "Store policy must exist")
  assert.equal(controller.savedPriceTarget.textContent, "Fix the price to save")
  assert.equal(controller.itemNameTarget.getAttribute("aria-invalid"), "true")
  assert.equal(controller.itemNameTarget.getAttribute("aria-describedby"), "item_name-live")
})

test("clears an error and its aria flags once the field is valid again", () => {
  const controller = build({ values: { item: "" } })
  controller.refresh({ target: { name: "purchase[item_name]" } })
  controller.itemNameTarget.value = "Coat"
  controller.refresh({ target: { name: "purchase[item_name]" } })

  assert.equal(message(controller, "item_name"), "")
  assert.equal(controller.itemNameTarget.getAttribute("aria-invalid"), null)
  assert.equal(controller.itemNameTarget.getAttribute("aria-describedby"), null)
})

test("keeps an invalid flag the server rendered", () => {
  const controller = build({ values: { item: "Coat" } })
  controller.itemNameTarget.setAttribute("aria-invalid", "true")
  controller.refresh({ target: { name: "purchase[item_name]" } })
  assert.equal(controller.itemNameTarget.getAttribute("aria-invalid"), "true")
})

test("shows the price that will be saved, and flags text the browser could not read as a number", () => {
  const controller = build({ values: { price: "1234.5" } })
  assert.equal(controller.savedPriceTarget.textContent, "$1,234.50")

  controller.priceTarget.value = ""
  controller.priceTarget.validity.badInput = true
  controller.refresh({ target: { name: "purchase[price]" } })
  assert.equal(message(controller, "price"), "Price is not a number")
})

test("calculates the return-by date and days left from the purchase date and the policy window", () => {
  const controller = build({ values: { date: "2026-11-01", policy: "7" } })
  assert.equal(controller.storeTarget.textContent, "Campus Store — 30 days")
  assert.match(controller.returnByTarget.textContent, /December 1, 2026/)
  assert.equal(controller.daysLeftTarget.textContent, 23)
})

test("shows a negative count once the calculated deadline has passed", () => {
  const controller = build({ values: { date: "2026-09-01", policy: "7" } })
  assert.equal(controller.daysLeftTarget.textContent, -38)
})

test("keeps a saved deadline until the date or policy changes", () => {
  const saved = { date: "2026-11-01", policy: "7", returnBy: "2026-11-20" }
  const controller = build({ values: { date: "2026-11-01", policy: "7" }, saved })
  assert.match(controller.returnByTarget.textContent, /November 20, 2026/)

  controller.purchaseDateTarget.value = "2026-11-02"
  controller.refresh({ target: { name: "purchase[purchase_date]" } })
  assert.match(controller.returnByTarget.textContent, /December 2, 2026/)
})

test("hides days left for purchases that are already decided", () => {
  const controller = build({ values: { date: "2026-11-01", policy: "7" }, status: "keeping" })
  assert.equal(controller.daysLeftTarget.hidden, true)
  assert.equal(controller.daysLeftLabelTarget.hidden, true)
})

test("works when there are no store policies to choose from", () => {
  const controller = build({ policies: false, values: { date: "2026-11-01" } })
  assert.equal(controller.returnByTarget.textContent, "Choose a purchase date and store policy")
  controller.refresh({ target: { name: "purchase[purchase_date]" } })
  assert.equal(message(controller, "store_policy_id"), "")
})
