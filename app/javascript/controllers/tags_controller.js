import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "chips", "hidden"]
  static values = { initial: String }

  connect() {
    this.tags = []
    this.loadInitial()
    this.render()

    this.inputTarget.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault()
        this.add()
      }
    })
  }

  loadInitial() {
    const s = (this.initialValue || "").trim()
    if (!s) return
    s.split(/\s+/).forEach((t) => this.pushTag(t))
  }

  add() {
    const raw = (this.inputTarget.value || "").trim()
    if (!raw) return
    this.pushTag(raw)
    this.inputTarget.value = ""
    this.render()
  }

  remove(e) {
    const name = e.params.name
    this.tags = this.tags.filter((t) => t !== name)
    this.render()
  }

  pushTag(raw) {
    const name = raw.replace(/^[#＃]/, "").trim()
    if (!name) return
    if (!this.tags.includes(name)) this.tags.push(name)
  }

  render() {
    this.chipsTarget.innerHTML = ""
    this.tags.forEach((name) => {
      const chip = document.createElement("span")
      chip.className = "post-chip"
      chip.innerHTML = `#${this.escape(name)} <button type="button" class="post-chip__x">×</button>`
      chip.querySelector("button").dataset.action = "tags#remove"
      chip.querySelector("button").dataset.tagsNameParam = name
      this.chipsTarget.appendChild(chip)
    })

    this.hiddenTarget.value = this.tags.join(" ")
  }

  escape(s) {
    return s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
  }
}