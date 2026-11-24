import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "returnclock:pagination-scroll"
const MAX_AGE_MS = 10000

export default class extends Controller {
  connect() {
    this.restore()
  }

  save(event) {
    const link = event.target.closest("a")
    if (!link) return

    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify({
        y: window.scrollY,
        path: window.location.pathname,
        savedAt: Date.now()
      }))
    } catch (_) {
      // Storage can be unavailable in private browsing modes.
    }
  }

  restore() {
    let saved

    try {
      saved = JSON.parse(sessionStorage.getItem(STORAGE_KEY))
      sessionStorage.removeItem(STORAGE_KEY)
    } catch (_) {
      return
    }

    if (!saved || saved.path !== window.location.pathname || Date.now() - saved.savedAt > MAX_AGE_MS) return

    const scroll = () => window.scrollTo(0, saved.y)
    requestAnimationFrame(() => requestAnimationFrame(scroll))
    setTimeout(scroll, 0)
  }
}
