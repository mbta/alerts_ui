let Hooks = {}

// This hook is put on a few <select> elements that mustn't allow
// "All XYZ" to be selected at the same time that individual items
// are selected. So, when the form change handler executes the "validate"
// check, we clean the selected data to deselect the default "All XYZ"
// value and then push that change to the client via a push_event to
// this hook. It's certainly janky and could do with a better idea!
Hooks.SelectAllAdjuster = {
  mounted() {
    // I struggled to figure out how do I match the <select> element
    // that needs updated selections to the correct field in the payload.
    // I settled on using this little lookup, but having this removed
    // from the LiveView component risks drift / errors. I'll just have
    // to make sure the tests are good, I suppose!
    const selectorIDLookup = {
      "affected_service_trip_ids": "trip_ids",
      "affected_service_stop_ids": "stop_ids"
    }

    this.handleEvent("adjustSelections", payload => {
      const options = Array.from(this.el.options)
      const payloadKey = selectorIDLookup[this.el.id]
      const newSelections = payload[payloadKey]

      // If newSelections is 0, then only default is selected. Otherwise, the opposite
      if (newSelections.length != 0) {
        const defaultIndex = options.findIndex(opt => opt.value == "default")
        options[defaultIndex].selected = false
      }
    })
  }
}

export default Hooks
