let Hooks = {};

Hooks.DropdownPosition = {
  // The dropdown doesn't have a size (height/width) until the first time
  // we show it. So running `getBoundingClientRect` before then fails.
  // We use a MutationObserver to watch for the moment it first receives a style
  // because then we can determine its size and reposition it.
  mounted() {
    this.positionDropdown = this.positionDropdown.bind(this);

    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.attributeName === "style") {
          if (this.el.style.display === "block") {
            this.positionDropdown();
          }
        }
      });
    });

    this.observer.observe(this.el, { attributes: true });
  },

  positionDropdown() {
    const menu = this.el;
    const toggle = document.getElementById(menu.dataset.toggleId);

    // Size of toggle button, provided container, dropdown
    const toggleRect = toggle.getBoundingClientRect();
    const containerHeight = menu.dataset.containerId
      ? document.getElementById(menu.dataset.containerId).getBoundingClientRect()
      // fallback to viewport edge if container not provided
      : window.innerHeight;
    const dropdownSpaceNeeded =  menu.getBoundingClientRect().bottom - toggleRect.top  
    
    // Space between the toggle button and edge of the container (aka room for the dropdown)
    const spaceBelow = containerHeight.bottom - toggleRect.bottom;
    
    const shouldDropUp = spaceBelow < dropdownSpaceNeeded

    if (shouldDropUp) {
      menu.classList.add(
        "bottom-[34px]",
        "before:top-full",
        "before:border-t-border-primary",
        "after:top-full",
        "after:border-t-bg-input-default",
      );
      menu.classList.remove(
        "top-[34px]",
        "before:bottom-full",
        "before:border-b-border-primary",
        "after:bottom-full",
        "after:border-b-bg-input-default"
      );
    }
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
}

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
    const openingAlert = !!this.el.dataset.showingAlertId;
    const closingAlert = this.showingAlert && !openingAlert;
    if (!(openingAlert || closingAlert)) {
      setTimeout(() => this.el.scrollTo({ top: 0, behavior: "smooth" }), 0);
    }
    this.showingAlert = openingAlert;
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
