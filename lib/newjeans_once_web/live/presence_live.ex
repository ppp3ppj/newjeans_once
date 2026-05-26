defmodule NewjeansOnceWeb.PresenceLive do
  use NewjeansOnceWeb, :live_view

  alias NewjeansOnce.Presence

  @topic "bunnies:lobby"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok, _} = Presence.track(self(), @topic, socket.id, %{})
      Phoenix.PubSub.subscribe(NewjeansOnce.PubSub, @topic)
    end

    {:ok, assign(socket, :fan_count, count_fans())}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :fan_count, count_fans())}
  end

  defp count_fans, do: Presence.list(@topic) |> map_size()

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-[80vh] flex flex-col items-center justify-center gap-10 text-center px-4">
        <div class="flex flex-col items-center gap-3">
          <span class="text-8xl drop-shadow-lg">🐰</span>
          <h1 class="text-5xl font-black tracking-tight bg-gradient-to-r from-pink-500 to-purple-500 bg-clip-text text-transparent">
            ONCE Counter
          </h1>
          <p class="text-base-content/50 text-lg">Live fans connected right now</p>
        </div>

        <div class="relative flex items-center justify-center w-60 h-60 rounded-full
                    bg-gradient-to-br from-pink-400 via-fuchsia-400 to-purple-500 shadow-2xl shadow-purple-500/30">
          <div class="absolute inset-0 rounded-full bg-gradient-to-br from-pink-400 to-purple-500
                      animate-ping opacity-20"></div>
          <div class="absolute inset-2 rounded-full bg-base-100/10 backdrop-blur-sm flex items-center justify-center">
            <span class="text-7xl font-black text-white z-10 tabular-nums">{@fan_count}</span>
          </div>
        </div>

        <div class="flex flex-col items-center gap-2">
          <p class="text-3xl font-bold">
            {@fan_count} {if @fan_count == 1, do: "BUNNY", else: "BUNNIES"} here right now 🎀
          </p>
          <p class="text-sm text-base-content/40 max-w-sm">
            Open this page in multiple tabs or send the link to a friend — the counter updates instantly on every screen, no refresh needed.
          </p>
        </div>

        <div class="flex items-center gap-2 px-4 py-2 rounded-full bg-green-500/10 border border-green-500/20">
          <span class="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span>
          <span class="text-sm text-green-600 font-medium">Live via Phoenix Presence</span>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
