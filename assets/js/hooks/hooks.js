let Hooks = {};

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
      affected_service_trip_ids: "trip_ids",
      affected_service_stop_ids: "stop_ids",
      affected_service_stop_names_and_ids: "stop_names_and_ids",
    };

    this.handleEvent("adjustSelections", (payload) => {
      const options = Array.from(this.el.options);
      const payloadKey = selectorIDLookup[this.el.id];
      const newSelections = payload[payloadKey];

      // If newSelections is 0, then only default is selected. Otherwise, the opposite
      if (newSelections.length != 0) {
        const defaultIndex = options.findIndex((opt) => opt.value == "default");
        options[defaultIndex].selected = false;
      }
    });
  },
};

Hooks.MeasureImage = {
  mounted() {
    this.el.addEventListener("load", (event) => {
      const { naturalWidth, naturalHeight, width, height } = this.el;
      this.pushEventTo("#alert-image", "image-preview-size", {
        id: "size-of-image",
        image_preview_size: { width: naturalWidth, height: naturalHeight },
      });
    });
  },
};

Hooks.AutoDismissFlash = {
  mounted() {
    const hideElementAfter = 5000;
    const clearFlashAfter = hideElementAfter + 500;

    setTimeout(() => {
      this.el.style.transition = "opacity 0.5s";
      this.el.style.opacity = 0;
    }, hideElementAfter);
    setTimeout(() => this.pushEvent("lv:clear-flash"), clearFlashAfter);
  },
};

Hooks.ScrollToTop = {
  updated() {
    setTimeout(() => this.el.scrollTo({ top: 0, behavior: "smooth" }), 0);
  },
};

Hooks.FilterSelect = {
  mounted() {
    this.el.addEventListener("input", (e) => {
      const value = e.target.value.toLowerCase();
      if (e.target.tagName === "SELECT") return;
      this.el.querySelectorAll("option").forEach((o) => {
        o.classList.toggle(
          "hidden",
          !(value === "" || o.innerText.toLowerCase().startsWith(value))
        );
      });
    });
  },
};

Hooks.FilterCount = {
  mounted() {
    this.el.addEventListener("change", this.refresh.bind(this));
    this.refresh();
  },

  updated() {
    this.refresh();
  },

  refresh() {
    const count = `(${this.recount()})`;
    this.el.querySelectorAll("h1").forEach((h1) => {
      h1.setAttribute("data-count", count);
    });
    this.el.querySelectorAll("[data-count]").forEach((el) => {
      el.setAttribute("data-count", count);
    });
  },

  recount() {
    let count = 0;
    this.el.querySelectorAll("select").forEach((e) => {
      count += e.selectedOptions.length;
    });
    return count;
  },
};

export default Hooks;
