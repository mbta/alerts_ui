import { FullStory, isInitialized } from '@fullstory/browser';
import tippy from "tippy.js";

let Hooks = {};

Hooks.ActivityTracker = {
  throttled: false,
  // 30s throttle
  delay: 30 * 1000,

  pushActivity() {
    if (!this.throttled) {
      this.pushEventTo("#" + this.el.id, "activity");
      this.throttled = true;

      setTimeout(() => {
        this.throttled = false;
      }, this.delay);
    }
  },

  mounted() {
    this.pushActivity = this.pushActivity.bind(this);

    this.pushActivity();
    window.addEventListener("mousemove", this.pushActivity);
    window.addEventListener("scroll", this.pushActivity);
    window.addEventListener("keydown", this.pushActivity);
    window.addEventListener("resize", this.pushActivity);
  },

  destroyed() {
    this.pushActivity = this.pushActivity.bind(this);

    window.removeEventListener("mousemove", this.pushActivity);
    window.removeEventListener("scroll", this.pushActivity);
    window.removeEventListener("keydown", this.pushActivity);
    window.removeEventListener("resize", this.pushActivity);
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
    const dropdownSpaceNeeded =  menu.getBoundingClientRect().bottom - toggleRect.top

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
      affected_service_stop_ids: "stop_ids",
      affected_service_stop_names_and_ids: "stop_names_and_ids",
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
        const newSelections = payload[payloadKey].filter(item => item != "default");

        // If newSelections is 0, then only default is selected. Otherwise, the opposite
        if (newSelections.length != 0) {
          const defaultIndex = options.findIndex((opt) => opt.value == "default");
          options[defaultIndex].selected = false;
        }
      }
    });

    // Prevents scroll on select
    this.el.addEventListener('pointerdown', () => {
      this.el.focus({ preventScroll: true });
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

// TODO: What all should we track in FS?
// Right now, I've just got page nav
Hooks.FullStory = {
  mounted() {
    // Track initial page view
    this.trackPageView()

    // Listen for LiveView navigation events
    window.addEventListener("phx:page-loading-stop", () => {
      console.log("page load ended")
      this.trackPageView()
    })
  },

  trackPageView() {
    console.log("tracking page view")
    if (isInitialized()) {
      console.log("setting page in fullstory")
      FullStory('setProperties', {
        type: 'page',
        properties: {
          path: window.location.pathname
        }
      })
    }
    
  }
}
Hooks.Tippy = {
  mounted() {
    this.instance = tippy(this.el);
  },
  updated() {
    this.instance.setProps(
      Object.fromEntries(
        Object.entries(this.el.dataset)
          .filter(([k]) => k.startsWith("tippy"))
          .map(([k, v]) => [
            this.tippyPropName(k),
            v
          ])
      )
    );
  },
  destroyed() {
    this.instance.destroy();
  },

  tippyPropName(k) {
    const strippedName = k.replace("tippy", "");
    return strippedName.charAt(0).toLowerCase() + strippedName.slice(1);
  },
};

export default Hooks;
