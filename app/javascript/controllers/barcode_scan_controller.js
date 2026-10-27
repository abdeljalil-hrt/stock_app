import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    debounce: { type: Number, default: 150 },
    interKeyLimit: { type: Number, default: 80 },
    minimumLength: { type: Number, default: 8 }
  }

  connect() {
    this.element.focus()
  }

  disconnect() {
    clearTimeout(this.submitTimer)
  }

  keydown(event) {
    if (event.key === "Enter") {
      this.resetBurst()
      return
    }

    if (event.key.length !== 1 || event.ctrlKey || event.metaKey || event.altKey || event.repeat) {
      this.resetBurst()
      return
    }

    const now = performance.now()
    if (this.lastKeyAt && now - this.lastKeyAt <= this.interKeyLimitValue) {
      this.keyCount += 1
    } else {
      this.keyCount = 1
    }
    this.lastKeyAt = now

    clearTimeout(this.submitTimer)
    if (this.keyCount >= this.minimumLengthValue) {
      this.submitTimer = setTimeout(() => {
        if (this.element.value.trim().length >= this.minimumLengthValue) {
          this.element.form.requestSubmit()
        }
        this.resetBurst()
      }, this.debounceValue)
    }
  }

  resetBurst() {
    clearTimeout(this.submitTimer)
    this.submitTimer = null
    this.lastKeyAt = null
    this.keyCount = 0
  }
}
