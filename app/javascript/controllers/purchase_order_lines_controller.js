import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "template", "goodsTotal"]

  connect() {
    this.updateTotal()
  }

  add() {
    const index = this.rowsTarget.children.length
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", index)
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this.updateTotal()
  }

  remove(event) {
    event.target.closest("[data-line-row]").remove()
    this.updateTotal()
  }

  updateTotal() {
    const total = [...this.rowsTarget.querySelectorAll("[data-line-row]")].reduce((sum, row) => {
      const quantity = Number(row.querySelector("[data-quantity]")?.value || 0)
      const price = Number(row.querySelector("[data-price]")?.value || 0)
      return sum + quantity * price
    }, 0)
    this.goodsTotalTarget.textContent = `${new Intl.NumberFormat("fr-FR").format(total)} DH`
  }
}
