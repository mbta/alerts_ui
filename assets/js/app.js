// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Hooks from "./hooks/hooks"

import "./fullstory";

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket(
  "/live",
  Socket,
  {
    heartbeatIntervalMs: 3000,
    longPollFallbackMs: 3000,
    hooks: Hooks,
    params: { _csrf_token: csrfToken },
    dom: {
      // So that resizing a textarea does not undo itself 
      // https://github.com/phoenixframework/phoenix_live_view/issues/1011
      onBeforeElUpdated: (fromEl, toEl) => {
        if (fromEl.tagName === "TEXTAREA") {
          toEl.style.height = fromEl.style.height;
        }
      }
    }
  }
)
sessionStorage.setItem("phx:fallback:LongPoll", false);

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Copy contents of target to the clipboard
window.addEventListener("phx:copy_input", (event) => {
  handleCopy(event, event.target.value)
})

// Copy given text to the clipboard
window.addEventListener("phx:copy", (event) => {
  handleCopy(event, event["detail"]["text"])
})

// Handle copying and setting a timer of showing a 'copied state'
// Requires that there be two children element, one with state-default, and one with state-copied
// to represent the two states.
const handleCopy = (event, textToCopy) => {
  const button = event.detail.dispatcher;
  const buttonDefaultState = button.querySelector(".state-default")
  const buttonCopiedState = button.querySelector(".state-copied")

  if ("clipboard" in navigator) {
    navigator.clipboard.writeText(textToCopy).then(() => {
      // Swap the 'copied' state with the 'default' state
      buttonDefaultState.classList.add("hidden")
      buttonDefaultState.setAttribute("aria-hidden", "true");
      buttonCopiedState.classList.remove("hidden")
      buttonCopiedState.removeAttribute("aria-hidden");

      setTimeout(() => {
        // Revert back to the original state after 2 seconds
        buttonDefaultState.classList.remove("hidden");
        buttonDefaultState.removeAttribute("aria-hidden");
        buttonCopiedState.classList.add("hidden");
        buttonCopiedState.setAttribute("aria-hidden", "true");
      }, 2000);
    })
  }
}

window.addEventListener("phx:show-modal", (e) => {

  let el = document.getElementById(e.detail.id)
  if (el) {
    liveSocket.execJS(el, el.getAttribute("data-show"))
  }
})
