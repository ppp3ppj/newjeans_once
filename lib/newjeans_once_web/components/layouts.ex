defmodule NewjeansOnceWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use NewjeansOnceWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :fan_count, :integer, default: nil

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-black text-white border-b-[6px] border-[#ff0000]">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 flex items-center justify-between h-16">
        <a href="/" class="flex items-center gap-3 shrink-0">
          <div class="w-10 h-10 bg-[#ff0000] border-[3px] border-white flex items-center justify-center font-black text-white text-xs leading-none tracking-tighter">
            FW
          </div>
          <span class="font-black text-base uppercase tracking-widest hidden sm:block">
            FanWall
          </span>
        </a>
        <div class="flex items-center gap-2 sm:gap-3">
          <div
            :if={@fan_count != nil}
            class="flex items-center gap-2 border-[2px] border-white bg-[#00ffff] px-3 py-1.5"
          >
            <span class="text-base leading-none select-none">🐰</span>
            <span class="font-black text-sm text-black tabular-nums leading-none">{@fan_count}</span>
            <span class="font-black uppercase text-[10px] text-black tracking-widest hidden sm:block leading-none">
              {if @fan_count == 1, do: "BUNNY", else: "BUNNIES"}
            </span>
            <span class="w-2 h-2 bg-green-600 rounded-full animate-pulse shrink-0"></span>
          </div>
          <.theme_toggle />
        </div>
      </div>
    </header>

    <main class="px-4 py-10 sm:px-6 lg:px-8">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="flex border-[2px] border-white shrink-0" title="Toggle theme">
      <button
        class="flex p-2 cursor-pointer hover:bg-[#ff6600] hover:text-black transition-colors duration-150"
        title="System"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>
      <button
        class="flex p-2 cursor-pointer border-x-[2px] border-white hover:bg-[#ffff00] hover:text-black transition-colors duration-150"
        title="Light"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>
      <button
        class="flex p-2 cursor-pointer hover:bg-[#00ffff] hover:text-black transition-colors duration-150"
        title="Dark"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
