defmodule NewjeansOnceWeb.BoardLive do
  use NewjeansOnceWeb, :live_view
  alias NewjeansOnce.Board
  alias NewjeansOnce.Board.Message
  alias NewjeansOnce.Presence

  @presence_topic "bunnies:lobby"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Board.subscribe()
      {:ok, _} = Presence.track(self(), @presence_topic, socket.id, %{})
      Phoenix.PubSub.subscribe(NewjeansOnce.PubSub, @presence_topic)
    end

    {:ok,
     socket
     |> assign(:fan_count, count_fans())
     |> assign(:post_count, Board.count_messages())
     |> assign(:show_new_modal, false)
     |> assign(:new_form, to_form(Board.change_message(%Message{})))
     |> assign(:editing_id, nil)
     |> assign(:edit_form, nil)
     |> assign(:delete_msg, nil)
     |> stream(:messages, Board.list_messages())}
  end

  defp count_fans, do: Presence.list(@presence_topic) |> map_size()

  # PubSub — real-time sync across all browsers
  def handle_info({:created, msg}, socket) do
    {:noreply,
     socket
     |> update(:post_count, &(&1 + 1))
     |> stream_insert(:messages, msg, at: 0)}
  end

  def handle_info({:updated, msg}, socket),
    do: {:noreply, stream_insert(socket, :messages, msg)}

  def handle_info({:deleted, msg}, socket) do
    {:noreply,
     socket
     |> update(:post_count, &(&1 - 1))
     |> stream_delete(:messages, msg)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket),
    do: {:noreply, assign(socket, :fan_count, count_fans())}

  # New-post modal
  def handle_event("open_new_modal", _, socket),
    do: {:noreply, assign(socket, :show_new_modal, true)}

  def handle_event("close_new_modal", _, socket),
    do: {:noreply, assign(socket, show_new_modal: false, new_form: to_form(Board.change_message(%Message{})))}

  # Create
  def handle_event("validate_new", %{"message" => p}, socket) do
    form = Board.change_message(%Message{}, p) |> Map.put(:action, :validate) |> to_form()
    {:noreply, assign(socket, :new_form, form)}
  end

  def handle_event("save_new", %{"message" => p}, socket) do
    case Board.create_message(p) do
      {:ok, _} ->
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
    msg = Board.get_message!(id)

    {:noreply,
     socket
     |> assign(:editing_id, id)
     |> assign(:edit_form, to_form(Board.change_message(msg)))}
  end

  def handle_event("cancel_edit", _, socket),
    do: {:noreply, assign(socket, editing_id: nil, edit_form: nil)}

  def handle_event("save_edit", %{"message" => p}, socket) do
    msg = Board.get_message!(socket.assigns.editing_id)

    case Board.update_message(msg, p) do
      {:ok, _} -> {:noreply, assign(socket, editing_id: nil, edit_form: nil)}
      {:error, cs} -> {:noreply, assign(socket, :edit_form, to_form(cs))}
    end
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
            <div class="absolute -top-4 -right-10 w-12 h-12 bg-[#ffff00] border-[3px] border-black dark:border-white rotate-12 hidden sm:flex items-center justify-center text-xl font-black text-black select-none">
              ★
            </div>
          </div>
          <button
            phx-click="open_new_modal"
            class="btn btn-neutral shrink-0 flex items-center gap-2 px-6"
          >
            <span class="text-lg">✚</span> NEW POST
          </button>
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
            class="border-[4px] border-black dark:border-white bg-base-100 overflow-hidden group shadow-[5px_5px_0_#000000] dark:shadow-[5px_5px_0_#ffffff] transition-all duration-150 hover:-translate-x-[3px] hover:-translate-y-[3px] hover:shadow-[8px_8px_0_#000000] dark:hover:shadow-[8px_8px_0_#ffffff]"
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
                <div class="flex gap-1.5 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
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

      <%!-- ── NEW POST MODAL ─────────────────────────────────── --%>
      <div
        :if={@show_new_modal}
        id="new-post-modal-overlay"
        phx-hook="ModalScrollLock"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <%!-- Backdrop --%>
        <div
          class="absolute inset-0 bg-black/60"
          phx-click="close_new_modal"
        >
        </div>
        <%!-- Modal box --%>
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
        <%!-- Backdrop --%>
        <div
          class="absolute inset-0 bg-black/60"
          phx-click="cancel_edit"
        >
        </div>
        <%!-- Modal box --%>
        <div class="relative z-10 w-full max-w-lg border-[4px] border-black dark:border-white bg-[#00ffff] shadow-[8px_8px_0_#000000] dark:shadow-[8px_8px_0_#ffffff] max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between border-b-[4px] border-black px-6 py-4">
            <h2 class="font-black text-xl uppercase tracking-widest text-black">
              ✏ EDIT POST
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
            <%!-- Post preview --%>
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
    </Layouts.app>
    """
  end
end
