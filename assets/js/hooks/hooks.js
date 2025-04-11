let Hooks = {}
Hooks.SelectAllAdjuster = {
  mounted() {
    this.el.addEventListener("change", () => {
      const options = Array.from(this.el.options)
      const selected = options.filter(opt => opt.selected).map(opt => opt.value)

      if (selected.includes("default") && selected.length > 1) {
        const defaultIndex = options.findIndex(opt => opt.value == "default")
        options[defaultIndex].selected = false
      } else if (selected.includes("default")) {
        options.forEach(opt => {
          if (opt.value != "default") opt.selected = false
        })
      }
    })
  }
}

export default Hooks
