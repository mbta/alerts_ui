let Hooks = {};
Hooks.ActivityTracker = {
  throttled: false,
  // 5s throttle
  delay: 5 * 1000,
  // 30s window for autologout on inactivity
  autologoutWindow: 30 * 1000,

  pushThrottledActivity() {
    if (!this.throttled) {
      this.pushEventTo("#" + this.el.id, "activity");
      this.throttled = true;

      setTimeout(() => {
        this.throttled = false;
      }, this.delay);
    }
  },

  pushActivity() {
    this.pushEventTo("#" + this.el.id, "activity");
  },

  pushInactivity() {
    this.pushEventTo("#" + this.el.id, "inactivity");
    setTimeout(() => { this.pushInactivity() }, this.autologoutWindow);
  },

  mounted() {
    this.pushInactivity = this.pushInactivity.bind(this);
    this.pushActivity = this.pushActivity.bind(this);
    this.pushThrottledActivity = this.pushThrottledActivity.bind(this);

    this.pushInactivity();
    this.pushActivity();
    this.pushThrottledActivity();

    // types of activity that fire a lot and so are throttled
    window.addEventListener("mousemove", this.pushThrottledActivity);
    window.addEventListener("scroll", this.pushThrottledActivity);
    window.addEventListener("touchmove", this.pushThrottledActivity);
    window.addEventListener("resize", this.pushThrottledActivity);

    // types of activity that happen once
    window.addEventListener("click", this.pushActivity);
    window.addEventListener("keydown", this.pushActivity);
    window.addEventListener("touchstart", this.pushActivity);
  },

  destroyed() {
    this.pushThrottledActivity = this.pushThrottledActivity.bind(this);
    this.pushActivity = this.pushActivity.bind(this);

    window.removeEventListener("mousemove", this.pushThrottledActivity);
    window.removeEventListener("scroll", this.pushThrottledActivity);
    window.removeEventListener("touchmove", this.pushThrottledActivity);
    window.removeEventListener("resize", this.pushThrottledActivity);

    window.removeEventListener("click", this.pushActivity);
    window.removeEventListener("keydown", this.pushActivity);
    window.removeEventListener("touchstart", this.pushActivity);
  }
}

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
      ? document.getElementById(menu.dataset.containerId).getBoundingClientRect().bottom
      // fallback to viewport edge if container not provided
      : window.innerHeight;
    const dropdownSpaceNeeded = menu.getBoundingClientRect().bottom - toggleRect.top

    // Space between the toggle button and edge of the container (aka room for the dropdown)
    const spaceBelow = containerHeight - toggleRect.bottom;

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

Hooks.AutoScroll = {
  mounted() {
    this.handleEvent("scrollToItemOnMobile", (payload) => {
      const element = document.getElementById(payload.item_id);
      if ((element !== null) && window.screen.width <= 640) {
        element.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }
    })
  }
}

// This hook covers 2 behaviors on <select> elements.
//
// 1. Some select elements that mustn't allow "All XYZ" to be selected
// at the same time that individual items are selected.
// So, when the form change handler executes the "validate" check,
// we clean the selected data to deselect the default "All XYZ"
// value and then push that change to the client via a push_event to
// this hook. It's certainly janky and could do with a better idea!
//
// 2. When a select element takes focus, the viewport should not scroll
Hooks.Selector = {
  mounted() {
    // I struggled to figure out how do I match the <select> element
    // that needs updated selections to the correct field in the payload.
    // I settled on using this little lookup, but having this removed
    // from the LiveView component risks drift / errors. I'll just have
    // to make sure the tests are good, I suppose!
    const selectorIDLookup = {
      affected_service_trip_ids: "trip_ids",
      affected_service_stop_names_and_ids: "stop_names_and_ids",
      alert_data_trip_ids: "trip_ids",
      alert_data_stop_names_and_ids: "stop_names_and_ids",
      view_alerts_live_service_type: "service_type",
      view_alerts_live_routes: "routes",
      view_alerts_live_effects: "effects"
    };

    this.handleEvent("adjustSelections", (payload) => {
      const options = Array.from(this.el.options);
      const payloadKey = selectorIDLookup[this.el.id];

      // Only apply to a subset of selectors found in the lookup table
      if (payloadKey) {
        // If "default" hasn't already been filtered out, do so
        const newSelections = (payload[payloadKey] || []).filter(item => item != "default");

        if (newSelections.length != 0) {
          // Other options are selected — deselect the prompt "default" option
          const defaultIndex = options.findIndex((opt) => opt.value == "default");
          if (defaultIndex >= 0) options[defaultIndex].selected = false;
        }
      }
    });

    this.handleEvent("adjustOptgroupColor", (payload) => {
      // adds a "disabled" color to optgroup titles
      // used for Skate detours when all the options under it are disabled.
      if (this.el.id == "alert_data_skate_detour_id" &&
        this.el.children.length > 0 &&
        this.el.children.item(0).value !== "No active detours in Skate") {
        for (let element of this.el.children) {
          if (payload.data.includes(element.label)) {
            element.classList.add("text-[#6d6d6d]");
          }
        }
      }
    });

    this.el.addEventListener('pointerdown', (e) => {
      // save the current scroll top so we can return after rerender
      this.savedScrollTop = this.el.scrollTop;
      // prevents scroll on select
      this.el.focus({ preventScroll: true });
    });
  },

  updated() {
    // return to where we were before the update
    this.el.scrollTop = this.savedScrollTop;
  }
};

// Pushes an event only when focus leaves the whole hooked element, not when
// it merely moves between two focusable children inside it (e.g. a filter
// text input and its listbox) — phx-blur can't express that distinction,
// since it fires per-element rather than per-container.
Hooks.FocusOutPush = {
  mounted() {
    this.el.addEventListener("focusout", (e) => {
      if (!this.el.contains(e.relatedTarget)) {
        this.pushEvent(this.el.dataset.focusoutEvent, {});
      }
    });
  }
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
    if (this.el.dataset.scrollToTop === "true") {
      setTimeout(() => this.el.scrollTo({ top: 0 }), 0);
    }
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

export default Hooks;
