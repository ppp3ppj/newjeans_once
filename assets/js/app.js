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

// Single source of truth for cursor visibility — shared between CursorToggle and CursorTracker
let cursorEnabled = localStorage.getItem("cursor_enabled") !== "false"

// Deterministic color from name — same name always gives the same color
const CURSOR_COLORS = ["#ff6600","#00ffff","#ffff00","#ff69b4","#00ff99","#bf5fff"]
function cursorColor(name) {
  let h = 0
  for (const c of name) h = Math.imul(31, h) + c.charCodeAt(0) | 0
  return CURSOR_COLORS[Math.abs(h) % CURSOR_COLORS.length]
}

const Hooks = {
  ModalScrollLock: {
    mounted()   { document.body.classList.add("overflow-hidden") },
    destroyed() { document.body.classList.remove("overflow-hidden") },
  },
  GuestName: {
    mounted() {
      this.handleEvent("assign_name", ({name}) => {
        localStorage.setItem("guest_name", name)
      })
    }
  },
  CursorToggle: {
    mounted() {
      const sync = () => {
        this.el.textContent = cursorEnabled ? "ON" : "OFF"
        this.el.style.borderColor = cursorEnabled ? "white" : ""
        this.el.style.color = cursorEnabled ? "white" : ""
      }
      sync()
      this._click = () => {
        cursorEnabled = !cursorEnabled
        localStorage.setItem("cursor_enabled", cursorEnabled ? "true" : "false")
        sync()
        window.dispatchEvent(new CustomEvent("fanwall:cursor-toggle", {detail: {enabled: cursorEnabled}}))
      }
      this.el.addEventListener("click", this._click)
    },
    destroyed() { this.el.removeEventListener("click", this._click) },
  },
  CursorTracker: {
    mounted() {
      // Single canvas overlay — one paint pass for all cursors
      const canvas = document.createElement("canvas")
      canvas.style.cssText = "position:fixed;top:0;left:0;pointer-events:none;z-index:9999"
      document.body.appendChild(canvas)
      this._canvas = canvas
      const ctx = canvas.getContext("2d")

      const setSize = () => { canvas.width = window.innerWidth; canvas.height = window.innerHeight }
      setSize()
      this._resize = setSize
      window.addEventListener("resize", this._resize)

      // Cursor state: current pos (lerped) + target pos (from server)
      const cursors = new Map()
      const lerp = (a, b, t) => a + (b - a) * t

      const render = () => {
        const W = canvas.width, H = canvas.height
        ctx.clearRect(0, 0, W, H)
        for (const c of cursors.values()) {
          c.x = lerp(c.x, c.tx, 0.18)
          c.y = lerp(c.y, c.ty, 0.18)
          const px = c.x / 100 * W, py = c.y / 100 * H
          ctx.save()
          ctx.translate(px, py)
          // Arrow
          ctx.beginPath()
          ctx.moveTo(0, 0); ctx.lineTo(0, 14); ctx.lineTo(3.5, 10.5)
          ctx.lineTo(6, 17); ctx.lineTo(8, 16); ctx.lineTo(5.5, 9.5)
          ctx.lineTo(10, 9.5); ctx.closePath()
          ctx.fillStyle = c.color; ctx.fill()
          ctx.strokeStyle = "#000"; ctx.lineWidth = 1.5; ctx.lineJoin = "round"; ctx.stroke()
          // Name badge
          ctx.font = "900 10px monospace"
          const tw = ctx.measureText(c.name).width
          const bx = 14, by = 14, bp = 5, bh = 18, bw = tw + bp * 2
          ctx.fillStyle = c.color; ctx.fillRect(bx, by, bw, bh)
          ctx.strokeStyle = "#000"; ctx.lineWidth = 2; ctx.strokeRect(bx, by, bw, bh)
          ctx.fillStyle = "#000"; ctx.fillText(c.name, bx + bp, by + 13)
          ctx.restore()
        }
        this._raf = requestAnimationFrame(render)
      }
      this._raf = requestAnimationFrame(render)

      // Toggle controls only whether YOU see others — your cursor always broadcasts
      this._showOthers = cursorEnabled
      this._onToggle = ({detail: {enabled}}) => {
        this._showOthers = enabled
        if (!enabled) cursors.clear()
      }
      window.addEventListener("fanwall:cursor-toggle", this._onToggle)

      // Always send your own cursor regardless of toggle
      let last = 0
      this._move = (e) => {
        const now = performance.now()
        if (now - last < 50) return
        last = now
        this.pushEvent("cursor_move", {
          x: Math.round(e.clientX / window.innerWidth * 100),
          y: Math.round(e.clientY / window.innerHeight * 100),
        })
      }
      this._leave = () => this.pushEvent("cursor_leave", {})
      window.addEventListener("mousemove", this._move)
      window.addEventListener("mouseleave", this._leave)

      this.handleEvent("cursor:updated", ({id, name, x, y}) => {
        if (!this._showOthers) return
        const c = cursors.get(id)
        if (c) { c.tx = x; c.ty = y }
        else cursors.set(id, {x, y, tx: x, ty: y, name, color: cursorColor(name)})
      })
      this.handleEvent("cursor:removed", ({id}) => cursors.delete(id))
    },
    destroyed() {
      cancelAnimationFrame(this._raf)
      this._canvas?.remove()
      window.removeEventListener("fanwall:cursor-toggle", this._onToggle)
      window.removeEventListener("mousemove", this._move)
      window.removeEventListener("mouseleave", this._leave)
      window.removeEventListener("resize", this._resize)
    },
  },
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: () => ({_csrf_token: csrfToken, guest_name: localStorage.getItem("guest_name") || ""}),
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Confetti — triggered only for the poster's own browser via push_event (not PubSub)
function launchConfetti() {
  const canvas = document.createElement("canvas")
  canvas.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:9999"
  document.body.appendChild(canvas)
  const ctx = canvas.getContext("2d")
  canvas.width = window.innerWidth
  canvas.height = window.innerHeight

  const colors = ["#ffff00", "#00ffff", "#ff0000", "#ff6600", "#ffffff"]
  const pieces = Array.from({length: 100}, () => ({
    x: Math.random() * canvas.width,
    y: -10 - Math.random() * canvas.height * 0.3,
    w: 8 + Math.random() * 8,
    h: 6 + Math.random() * 6,
    color: colors[Math.floor(Math.random() * colors.length)],
    vx: (Math.random() - 0.5) * 5,
    vy: 3 + Math.random() * 5,
    vr: (Math.random() - 0.5) * 0.25,
    rotation: Math.random() * Math.PI * 2,
  }))

  let frame
  const animate = () => {
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    let alive = false
    pieces.forEach(p => {
      p.x += p.vx; p.y += p.vy; p.rotation += p.vr
      if (p.y < canvas.height + 20) alive = true
      ctx.save()
      ctx.translate(p.x, p.y)
      ctx.rotate(p.rotation)
      ctx.fillStyle = p.color
      ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h)
      ctx.restore()
    })
    alive ? (frame = requestAnimationFrame(animate)) : canvas.remove()
  }
  frame = requestAnimationFrame(animate)
  setTimeout(() => { cancelAnimationFrame(frame); canvas.remove() }, 3500)
}

window.addEventListener("phx:confetti", launchConfetti)

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

