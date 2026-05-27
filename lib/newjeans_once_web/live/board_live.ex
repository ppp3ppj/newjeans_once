defmodule NewjeansOnceWeb.BoardLive do
  use NewjeansOnceWeb, :live_view
  alias NewjeansOnce.Board
  alias NewjeansOnce.Board.Message
  alias NewjeansOnce.Presence

  @presence_topic "bunnies:lobby"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Board.subscribe()
      {:ok, _} = Presence.track(self(), @presence_topic, socket.id, %{typing: false})
      Phoenix.PubSub.subscribe(NewjeansOnce.PubSub, @presence_topic)
    end

    {:ok,
     socket
     |> assign(:fan_count, count_fans())
     |> assign(:typing_count, 0)
     |> assign(:toast, nil)
     |> assign(:post_count, Board.count_messages())
     |> assign(:show_new_modal, false)
     |> assign(:new_form, to_form(Board.change_message(%Message{})))
     |> assign(:editing_id, nil)
     |> assign(:edit_form, nil)
     |> assign(:delete_msg, nil)
     |> assign(:star_clicks, 0)
     |> assign(:show_nuke_modal, false)
     |> assign(:show_info_modal, false)
     |> stream(:messages, Board.list_messages())}
  end

  defp count_fans, do: Presence.list(@presence_topic) |> map_size()

  defp count_typing do
    Presence.list(@presence_topic)
    |> Map.values()
    |> Enum.count(fn %{metas: [meta | _]} -> meta.typing end)
  end

  # PubSub — real-time sync across all browsers
  def handle_info({:created, msg}, socket) do
    Process.send_after(self(), :clear_toast, 4000)

    {:noreply,
     socket
     |> assign(:toast, msg)
     |> update(:post_count, &(&1 + 1))
     |> stream_insert(:messages, msg, at: 0)}
  end

  def handle_info(:clear_toast, socket),
    do: {:noreply, assign(socket, :toast, nil)}

  def handle_info({:updated, msg}, socket),
    do: {:noreply, stream_insert(socket, :messages, msg)}

  def handle_info({:deleted, msg}, socket) do
    {:noreply,
     socket
     |> update(:post_count, &(&1 - 1))
     |> stream_delete(:messages, msg)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket),
    do: {:noreply, socket |> assign(:fan_count, count_fans()) |> assign(:typing_count, count_typing())}

  def handle_info({:nuked}, socket) do
    {:noreply,
     socket
     |> assign(:post_count, 0)
     |> stream(:messages, [], reset: true)}
  end

  # New-post modal
  def handle_event("open_new_modal", _, socket) do
    Presence.update(self(), @presence_topic, socket.id, %{typing: true})
    {:noreply, assign(socket, :show_new_modal, true)}
  end

  def handle_event("close_new_modal", _, socket) do
    Presence.update(self(), @presence_topic, socket.id, %{typing: false})
    {:noreply, assign(socket, show_new_modal: false, new_form: to_form(Board.change_message(%Message{})))}
  end

  # Create
  def handle_event("validate_new", %{"message" => p}, socket) do
    form = Board.change_message(%Message{}, p) |> Map.put(:action, :validate) |> to_form()
    {:noreply, assign(socket, :new_form, form)}
  end

  def handle_event("save_new", %{"message" => p}, socket) do
    case Board.create_message(p) do
      {:ok, _} ->
        Presence.update(self(), @presence_topic, socket.id, %{typing: false})

        {:noreply,
         assign(socket,
           show_new_modal: false,
           new_form: to_form(Board.change_message(%Message{}))
         )}

      {:error, cs} ->
        {:noreply, assign(socket, :new_form, to_form(cs))}
    end
  end

  # Edit
  def handle_event("edit", %{"id" => id}, socket) do
    Presence.update(self(), @presence_topic, socket.id, %{typing: true})
    msg = Board.get_message!(id)

    {:noreply,
     socket
     |> assign(:editing_id, id)
     |> assign(:edit_form, to_form(Board.change_message(msg)))}
  end

  def handle_event("cancel_edit", _, socket) do
    Presence.update(self(), @presence_topic, socket.id, %{typing: false})
    {:noreply, assign(socket, editing_id: nil, edit_form: nil)}
  end

  def handle_event("save_edit", %{"message" => p}, socket) do
    msg = Board.get_message!(socket.assigns.editing_id)

    case Board.update_message(msg, p) do
      {:ok, _} ->
        Presence.update(self(), @presence_topic, socket.id, %{typing: false})
        {:noreply, assign(socket, editing_id: nil, edit_form: nil)}

      {:error, cs} ->
        {:noreply, assign(socket, :edit_form, to_form(cs))}
    end
  end

  # Info modal
  def handle_event("open_info_modal", _, socket),
    do: {:noreply, assign(socket, :show_info_modal, true)}

  def handle_event("close_info_modal", _, socket),
    do: {:noreply, assign(socket, :show_info_modal, false)}

  # Let it crash — OTP supervisor restarts this process in milliseconds
  def handle_event("crash", _, _socket) do
    raise "intentional crash — watch OTP restart this process"
  end

  # Secret nuke — triggered by clicking ★ sticker 3 times
  def handle_event("star_click", _, socket) do
    clicks = socket.assigns.star_clicks + 1

    if clicks >= 3 do
      {:noreply, assign(socket, star_clicks: 0, show_nuke_modal: true)}
    else
      {:noreply, assign(socket, :star_clicks, clicks)}
    end
  end

  def handle_event("close_nuke_modal", _, socket),
    do: {:noreply, assign(socket, show_nuke_modal: false, star_clicks: 0)}

  def handle_event("nuke_all", _, socket) do
    Board.delete_all_messages()

    {:noreply,
     socket
     |> assign(:show_nuke_modal, false)
     |> assign(:post_count, 0)
     |> stream(:messages, [], reset: true)}
  end

  # Delete
  def handle_event("confirm_delete", %{"id" => id}, socket),
    do: {:noreply, assign(socket, :delete_msg, Board.get_message!(id))}

  def handle_event("cancel_delete", _, socket),
    do: {:noreply, assign(socket, :delete_msg, nil)}

  def handle_event("delete", _, socket) do
    Board.delete_message(socket.assigns.delete_msg)
    {:noreply, assign(socket, :delete_msg, nil)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} fan_count={@fan_count} post_count={@post_count}>
      <div class="max-w-3xl mx-auto flex flex-col gap-8">
        <%!-- Hero header + action row --%>
        <div class="pt-4 pb-2 flex items-end justify-between gap-4">
          <div class="relative inline-block">
            <h1 class="text-5xl sm:text-7xl font-black uppercase tracking-widest leading-none text-base-content">
              FAN WALL
            </h1>
            <div class="w-full h-[6px] bg-base-content mt-2"></div>
            <button
              phx-click="star_click"
              class="absolute -top-4 -right-10 w-12 h-12 bg-[#ffff00] border-[3px] border-black dark:border-white rotate-12 hidden sm:flex items-center justify-center text-xl font-black text-black select-none cursor-pointer hover:scale-110 transition-transform duration-150"
              title=""
            >
              ★
            </button>
          </div>
          <button
            phx-click="open_new_modal"
            class="btn btn-neutral shrink-0 flex items-center gap-2 px-6"
          >
            <span class="text-xl font-black leading-none">+</span> NEW POST
          </button>
        </div>

        <%!-- Typing indicator --%>
        <div
          :if={@typing_count > 0}
          class="flex items-center gap-2 border-[2px] border-black dark:border-white bg-[#ff6600] px-3 py-1.5 w-fit -mt-4"
        >
          <span class="w-2 h-2 bg-black animate-pulse shrink-0"></span>
          <span class="font-black uppercase text-[10px] tracking-widest text-black leading-none">
            {@typing_count} {if @typing_count == 1, do: "BUNNY", else: "BUNNIES"} WRITING...
          </span>
        </div>

        <%!-- Live stream of posts --%>
        <div id="messages" phx-update="stream" class="flex flex-col gap-4">
          <div
            :for={{id, msg} <- @streams.messages}
            id={id}
            phx-mounted={
              JS.transition(
                {"transition-all duration-200 ease-out",
                 "opacity-0 -translate-y-3",
                 "opacity-100 translate-y-0"},
                time: 200
              )
            }
            phx-remove={
              JS.transition(
                {"transition-all duration-150 ease-in",
                 "opacity-100 translate-x-0 rotate-0",
                 "opacity-0 translate-x-16 rotate-1"},
                time: 150
              )
            }
            class={[
              "border-[4px] bg-base-100 overflow-hidden group transition-all duration-150",
              if(@editing_id == to_string(msg.id),
                do:
                  "border-[#00ffff] shadow-[5px_5px_0_#00ffff] -translate-x-[3px] -translate-y-[3px]",
                else:
                  "border-black dark:border-white shadow-[5px_5px_0_#000000] dark:shadow-[5px_5px_0_#ffffff] hover:-translate-x-[3px] hover:-translate-y-[3px] hover:shadow-[8px_8px_0_#000000] dark:hover:shadow-[8px_8px_0_#ffffff]"
              )
            ]}
          >
            <img
              :if={msg.photo_url && msg.photo_url != ""}
              src={msg.photo_url}
              class="w-full h-48 object-cover border-b-[4px] border-black dark:border-white"
            />
            <div class="p-5 flex flex-col gap-2">
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="font-black text-xl uppercase tracking-wide leading-tight">
                    {msg.title}
                  </p>
                  <p class="text-sm font-black uppercase tracking-wider mt-1.5 flex items-center gap-1.5">
                    <span class="bg-[#ff0000] text-white px-1.5 py-0.5 text-[10px] font-black">
                      BY
                    </span>
                    <span class="text-[#ff0000] dark:text-[#ff6666]">{msg.author}</span>
                  </p>
                </div>
                <div class="flex items-center gap-1.5 shrink-0">
                  <span
                    :if={@editing_id == to_string(msg.id)}
                    class="font-black uppercase text-[10px] tracking-widest px-2 py-1 bg-[#00ffff] border-[2px] border-black text-black"
                  >
                    EDITING
                  </span>
                  <div class={[
                    "flex gap-1.5",
                    if(@editing_id == to_string(msg.id),
                      do: "opacity-100",
                      else: "opacity-0 group-hover:opacity-100 transition-opacity"
                    )
                  ]}>
                    <button
                      phx-click="edit"
                      phx-value-id={msg.id}
                      class="font-black uppercase text-[10px] tracking-widest px-2 py-1 border-[2px] border-black dark:border-white hover:bg-black hover:text-white dark:hover:bg-white dark:hover:text-black transition-colors duration-150"
                    >
                      EDIT
                    </button>
                    <button
                      phx-click="confirm_delete"
                      phx-value-id={msg.id}
                      class="font-black uppercase text-[10px] tracking-widest px-2 py-1 border-[2px] border-[#ff0000] text-[#ff0000] hover:bg-[#ff0000] hover:text-white transition-colors duration-150"
                    >
                      DEL
                    </button>
                  </div>
                </div>
              </div>
              <p class="text-base-content/80 leading-relaxed mt-1 border-l-[4px] border-[#ffff00] pl-3">
                {msg.description}
              </p>
              <div class="mt-2 pt-2 border-t-[2px] border-black/10 dark:border-white/10">
                <span class="text-[10px] font-black uppercase tracking-widest text-base-content/40">
                  {Calendar.strftime(msg.inserted_at, "%d %b %Y · %H:%M")}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- ── NEW POST TOAST (broadcast to all users) ───────────── --%>
      <div
        :if={@toast != nil}
        id="new-post-toast"
        phx-mounted={
          JS.transition(
            {"transition-all duration-300 ease-out",
             "opacity-0 translate-y-4",
             "opacity-100 translate-y-0"},
            time: 300
          )
        }
        class="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex items-center gap-3 border-[3px] border-black dark:border-white bg-[#ffff00] shadow-[5px_5px_0_#000000] dark:shadow-[5px_5px_0_#ffffff] px-5 py-3 whitespace-nowrap pointer-events-none"
      >
        <span class="w-2 h-2 bg-black animate-pulse shrink-0"></span>
        <span class="font-black uppercase text-[11px] tracking-widest text-black">
          // NEW POST BY {@toast.author}
        </span>
      </div>

      <%!-- ── NEW POST MODAL ─────────────────────────────────── --%>
      <div
        :if={@show_new_modal}
        id="new-post-modal-overlay"
        phx-hook="ModalScrollLock"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/60" phx-click="close_new_modal"></div>
        <div class="relative z-10 w-full max-w-lg border-[4px] border-black dark:border-white bg-[#ffff00] dark:bg-[#111111] shadow-[8px_8px_0_#000000] dark:shadow-[8px_8px_0_#ffffff] max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between border-b-[4px] border-black dark:border-white px-6 py-4">
            <h2 class="font-black text-xl uppercase tracking-widest text-black dark:text-white">
              // NEW POST
            </h2>
            <button
              phx-click="close_new_modal"
              class="font-black text-xl text-black dark:text-white hover:text-[#ff0000] transition-colors leading-none"
            >
              ✕
            </button>
          </div>
          <.form
            for={@new_form}
            id="new-message-form"
            phx-submit="save_new"
            phx-change="validate_new"
            class="flex flex-col gap-4 p-6"
          >
            <.input field={@new_form[:author]} label="Your name" placeholder="e.g. BUNNY_HANNI" />
            <.input
              field={@new_form[:title]}
              label="Title"
              placeholder="e.g. HANNI'S SMILE SAVED ME"
            />
            <.input
              field={@new_form[:description]}
              type="textarea"
              label="Message"
              placeholder="Share your love for NewJeans..."
            />
            <.input
              field={@new_form[:photo_url]}
              label="Image URL (optional)"
              placeholder="https://example.com/photo.jpg"
            />
            <div class="flex gap-3 justify-end pt-2">
              <button type="button" phx-click="close_new_modal" class="btn btn-ghost">
                Cancel
              </button>
              <button type="submit" class="btn btn-neutral">
                POST IT →
              </button>
            </div>
          </.form>
        </div>
      </div>

      <%!-- ── EDIT MODAL ──────────────────────────────────────── --%>
      <div
        :if={@editing_id != nil}
        id="edit-modal-overlay"
        phx-hook="ModalScrollLock"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/60" phx-click="cancel_edit"></div>
        <div class="relative z-10 w-full max-w-lg border-[4px] border-black dark:border-white bg-[#00ffff] shadow-[8px_8px_0_#000000] dark:shadow-[8px_8px_0_#ffffff] max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between border-b-[4px] border-black px-6 py-4">
            <h2 class="font-black text-xl uppercase tracking-widest text-black">
              // EDIT POST
            </h2>
            <button
              phx-click="cancel_edit"
              class="font-black text-xl text-black hover:text-[#ff0000] transition-colors leading-none"
            >
              ✕
            </button>
          </div>
          <.form
            :if={@edit_form}
            for={@edit_form}
            id="edit-message-form"
            phx-submit="save_edit"
            class="flex flex-col gap-4 p-6"
          >
            <.input field={@edit_form[:author]} label="Your name" />
            <.input field={@edit_form[:title]} label="Title" />
            <.input field={@edit_form[:description]} type="textarea" label="Message" />
            <.input field={@edit_form[:photo_url]} label="Image URL (optional)" />
            <div class="flex gap-3 justify-end border-t-[3px] border-black pt-4">
              <button type="button" phx-click="cancel_edit" class="btn btn-ghost">
                Cancel
              </button>
              <button type="submit" class="btn btn-neutral">
                SAVE →
              </button>
            </div>
          </.form>
        </div>
      </div>

      <%!-- ── DELETE MODAL ─────────────────────────────────────── --%>
      <div
        :if={@delete_msg != nil}
        id="delete-modal-overlay"
        phx-hook="ModalScrollLock"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/60" phx-click="cancel_delete"></div>
        <div class="relative z-10 w-full max-w-sm border-[4px] border-black shadow-[8px_8px_0_#000000] bg-[#ff0000]">
          <div class="border-b-[4px] border-black px-6 py-4">
            <h2 class="font-black text-xl uppercase tracking-widest text-white">
              // DELETE POST?
            </h2>
          </div>
          <div class="px-6 py-5 flex flex-col gap-4">
            <div class="border-[3px] border-white/50 bg-white/10 px-4 py-3 flex flex-col gap-1">
              <p class="font-black uppercase tracking-wide text-white leading-tight line-clamp-2">
                {@delete_msg.title}
              </p>
              <p class="font-black uppercase text-[10px] tracking-widest text-white/70 flex items-center gap-1.5">
                <span class="bg-white/20 px-1.5 py-0.5">BY</span>
                {@delete_msg.author}
              </p>
            </div>
            <p class="font-black uppercase tracking-widest text-white/70 text-xs">
              This cannot be undone.
            </p>
            <div class="flex gap-3 justify-end border-t-[3px] border-white/30 pt-3">
              <button
                phx-click="cancel_delete"
                class="font-black uppercase text-xs tracking-widest px-4 py-2 border-[2px] border-white text-white hover:bg-white hover:text-[#ff0000] transition-colors duration-150"
              >
                CANCEL
              </button>
              <button
                phx-click="delete"
                class="font-black uppercase text-xs tracking-widest px-4 py-2 border-[2px] border-black bg-black text-white hover:bg-white hover:text-black transition-colors duration-150"
              >
                DELETE →
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- ── INFO MODAL (click version badge) ────────────────── --%>
      <div
        :if={@show_info_modal}
        id="info-modal-overlay"
        phx-hook="ModalScrollLock"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/70" phx-click="close_info_modal"></div>
        <div class="relative z-10 w-full max-w-sm border-[4px] border-white bg-black shadow-[8px_8px_0_#ffffff]">
          <div class="flex items-center justify-between border-b-[4px] border-white px-6 py-4">
            <h2 class="font-black text-xl uppercase tracking-widest text-white">
              // APP INFO
            </h2>
            <button
              phx-click="close_info_modal"
              class="font-black text-xl text-white hover:text-[#ff0000] transition-colors leading-none"
            >
              ✕
            </button>
          </div>
          <div class="px-6 pt-6 pb-4 flex flex-col gap-4">
            <div class="border-l-[6px] border-[#ffff00] pl-4">
              <p class="font-black uppercase tracking-widest text-white/50 text-[10px]">APP</p>
              <p class="font-black text-4xl text-white font-mono tracking-tight leading-tight">
                FANWALL
              </p>
              <p class="font-mono font-black text-[#ffff00] text-lg tracking-widest">
                v{Application.spec(:newjeans_once, :vsn)}
              </p>
            </div>
            <div class="border-[2px] border-white/20 divide-y divide-white/20">
              <div class="flex items-center justify-between px-4 py-2">
                <span class="font-black uppercase text-[10px] tracking-widest text-white/50">
                  Phoenix
                </span>
                <code class="font-mono font-black text-xs text-white">
                  v{Application.spec(:phoenix, :vsn)}
                </code>
              </div>
              <div class="flex items-center justify-between px-4 py-2">
                <span class="font-black uppercase text-[10px] tracking-widest text-white/50">
                  LiveView
                </span>
                <code class="font-mono font-black text-xs text-white">
                  v{Application.spec(:phoenix_live_view, :vsn)}
                </code>
              </div>
              <div class="flex items-center justify-between px-4 py-2">
                <span class="font-black uppercase text-[10px] tracking-widest text-white/50">
                  Elixir
                </span>
                <code class="font-mono font-black text-xs text-white">
                  v{System.version()}
                </code>
              </div>
              <div class="flex items-center justify-between px-4 py-2">
                <span class="font-black uppercase text-[10px] tracking-widest text-white/50">
                  OTP
                </span>
                <code class="font-mono font-black text-xs text-white">
                  {to_string(:erlang.system_info(:otp_release))}
                </code>
              </div>
            </div>
            <div class="border-t-[3px] border-white/20 pt-4">
              <p class="font-black uppercase text-[10px] tracking-widest text-white/30 mb-3">
                OTP SUPERVISION DEMO
              </p>
              <button
                phx-click="crash"
                class="w-full font-black uppercase text-xs tracking-widest px-4 py-3 border-[3px] border-white text-white
                       bg-[repeating-linear-gradient(45deg,#1a1a1a,#1a1a1a_6px,#000_6px,#000_12px)]
                       hover:bg-[repeating-linear-gradient(45deg,#ff0000,#ff0000_6px,#000_6px,#000_12px)]
                       hover:border-[#ff0000] hover:text-white
                       transition-all duration-150 shadow-[3px_3px_0_#ffffff]
                       hover:-translate-x-[2px] hover:-translate-y-[2px] hover:shadow-[5px_5px_0_#ff0000]"
              >
                ! CRASH THIS PROCESS →
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- ── NUKE MODAL (secret: click ★ × 3) ───────────────── --%>
      <div
        :if={@show_nuke_modal}
        id="nuke-modal-overlay"
        phx-hook="ModalScrollLock"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/90" phx-click="close_nuke_modal"></div>
        <div class="relative z-10 w-full max-w-sm border-[4px] border-[#ff0000] bg-black shadow-[8px_8px_0_#ff0000]">
          <div class="border-b-[4px] border-[#ff0000] px-6 py-4 flex items-center gap-3">
            <span class="font-black text-2xl text-[#ff0000] animate-pulse">⚠</span>
            <h2 class="font-black text-xl uppercase tracking-widest text-[#ff0000]">
              NUKE WALL?
            </h2>
          </div>
          <div class="px-6 py-5 flex flex-col gap-3">
            <p class="font-black uppercase tracking-widest text-white text-sm">
              Delete all {@post_count} {if @post_count == 1, do: "post", else: "posts"}.
            </p>
            <p class="font-black uppercase tracking-[0.2em] text-[#ff0000]/60 text-[10px]">
              Cannot be undone. Ever.
            </p>
            <div class="flex gap-3 justify-end border-t-[3px] border-[#ff0000]/20 pt-4">
              <button
                phx-click="close_nuke_modal"
                class="font-black uppercase text-xs tracking-widest px-4 py-2 border-[2px] border-white text-white hover:bg-white hover:text-black transition-colors duration-150"
              >
                ABORT
              </button>
              <button
                phx-click="nuke_all"
                class="font-black uppercase text-xs tracking-widest px-4 py-2 border-[2px] border-[#ff0000] text-[#ff0000] hover:bg-[#ff0000] hover:text-white transition-colors duration-150"
              >
                NUKE ALL →
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
