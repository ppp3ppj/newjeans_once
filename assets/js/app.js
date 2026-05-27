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
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/newjeans_once"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const Hooks = {
  ModalScrollLock: {
    mounted()   { document.body.classList.add("overflow-hidden") },
    destroyed() { document.body.classList.remove("overflow-hidden") },
  },
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Reaction counts — server pushes only the new counts, JS patches the DOM directly
const REACTION_FILLED = ["border-black", "dark:border-white", "bg-black", "dark:bg-white", "shadow-[3px_3px_0_#000]", "dark:shadow-[3px_3px_0_#fff]"]
const REACTION_EMPTY  = ["border-black/20", "dark:border-white/20", "hover:border-black", "dark:hover:border-white", "hover:shadow-[3px_3px_0_#000]", "dark:hover:shadow-[3px_3px_0_#fff]"]

window.addEventListener("phx:reactions:updated", ({detail: {post_id, counts}}) => {
  for (const [type, count] of Object.entries(counts)) {
    const btn     = document.getElementById(`rxn-${post_id}-${type}`)
    const countEl = document.getElementById(`rxn-count-${post_id}-${type}`)
    if (!btn || !countEl) continue

    countEl.textContent = count
    if (count > 0) {
      countEl.classList.remove("hidden", "text-base-content/40")
      countEl.classList.add("text-white", "dark:text-black")
      btn.classList.remove(...REACTION_EMPTY)
      btn.classList.add(...REACTION_FILLED)
    } else {
      countEl.classList.add("hidden")
      countEl.classList.remove("text-white", "dark:text-black")
      btn.classList.remove(...REACTION_FILLED)
      btn.classList.add(...REACTION_EMPTY)
    }
  }
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

