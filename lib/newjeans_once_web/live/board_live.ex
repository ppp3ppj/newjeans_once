defmodule NewjeansOnceWeb.BoardLive do
  use NewjeansOnceWeb, :live_view
  alias NewjeansOnce.Board
  alias NewjeansOnce.Board.Message

  def mount(_params, _session, socket) do
    if connected?(socket), do: Board.subscribe()

    {:ok,
     socket
     |> assign(:new_form, to_form(Board.change_message(%Message{})))
     |> assign(:editing_id, nil)
     |> assign(:edit_form, nil)
     |> stream(:messages, Board.list_messages())}
  end

  # PubSub — real-time sync across all browsers
  def handle_info({:created, msg}, socket),
    do: {:noreply, stream_insert(socket, :messages, msg, at: 0)}

  def handle_info({:updated, msg}, socket),
    do: {:noreply, stream_insert(socket, :messages, msg)}

  def handle_info({:deleted, msg}, socket),
    do: {:noreply, stream_delete(socket, :messages, msg)}

  # Create
  def handle_event("validate_new", %{"message" => p}, socket) do
    form = Board.change_message(%Message{}, p) |> Map.put(:action, :validate) |> to_form()
    {:noreply, assign(socket, :new_form, form)}
  end

  def handle_event("save_new", %{"message" => p}, socket) do
    case Board.create_message(p) do
      {:ok, _} ->
        {:noreply, assign(socket, :new_form, to_form(Board.change_message(%Message{})))}

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
     |> assign(:edit_form, to_form(Board.change_message(msg)))
     |> stream_insert(:messages, msg)}
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
  def handle_event("delete", %{"id" => id}, socket) do
    Board.delete_message(Board.get_message!(id))
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-3xl mx-auto flex flex-col gap-8">
        <%!-- Hero header --%>
        <div class="pt-4 pb-2 relative">
          <div class="relative inline-block">
            <h1 class="text-5xl sm:text-7xl font-black uppercase tracking-widest leading-none text-base-content">
              FAN WALL
            </h1>
            <div class="w-full h-[6px] bg-base-content mt-2"></div>
            <%!-- Deco sticker: yellow star --%>
            <div class="absolute -top-4 -right-10 w-12 h-12 bg-[#ffff00] border-[3px] border-black dark:border-white rotate-12 hidden sm:flex items-center justify-center text-xl font-black text-black select-none">
              ★
            </div>
          </div>
          <p class="font-black uppercase tracking-[0.25em] mt-4 text-xs text-base-content/50">
            ✦ Your posts appear live on every screen ✦
          </p>
          <%!-- Background deco block --%>
          <div class="absolute top-0 right-0 w-20 h-20 bg-[#ff0000] opacity-[0.06] rotate-45 -z-10 hidden sm:block">
          </div>
        </div>

        <%!-- New post form — yellow block with hard shadow --%>
        <.form
          for={@new_form}
          id="new-message-form"
          phx-submit="save_new"
          phx-change="validate_new"
          class="flex flex-col gap-4 p-6 border-[4px] border-black dark:border-white bg-[#ffff00] dark:bg-[#1a1a1a] shadow-[6px_6px_0_#000000] dark:shadow-[6px_6px_0_#ffffff]"
        >
          <div class="flex items-center justify-between border-b-[4px] border-black dark:border-white pb-3">
            <h2 class="font-black text-xl uppercase tracking-widest text-black dark:text-white">
              // NEW POST
            </h2>
            <span class="text-[10px] font-black uppercase tracking-widest bg-black dark:bg-white text-white dark:text-black px-2 py-1">
              LIVE
            </span>
          </div>
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
          <div class="flex justify-end pt-2">
            <button type="submit" class="btn btn-neutral">
              POST IT →
            </button>
          </div>
        </.form>

        <%!-- Live stream of posts --%>
        <div id="messages" phx-update="stream" class="flex flex-col gap-5">
          <div
            :for={{id, msg} <- @streams.messages}
            id={id}
            class="border-[4px] border-black dark:border-white bg-base-100 overflow-hidden group shadow-[5px_5px_0_#000000] dark:shadow-[5px_5px_0_#ffffff] transition-all duration-150 hover:-translate-x-[3px] hover:-translate-y-[3px] hover:shadow-[8px_8px_0_#000000] dark:hover:shadow-[8px_8px_0_#ffffff]"
          >
            <%= if @editing_id == msg.id do %>
              <%!-- Edit mode: cyan header bar --%>
              <div class="bg-[#00ffff] border-b-[4px] border-black px-4 py-2 flex items-center gap-2">
                <span class="font-black uppercase tracking-widest text-black text-xs">
                  ✏ EDITING
                </span>
              </div>
              <.form
                for={@edit_form}
                id={"edit-form-#{msg.id}"}
                phx-submit="save_edit"
                class="flex flex-col gap-3 p-5 bg-base-100"
              >
                <.input field={@edit_form[:author]} label="Name" />
                <.input field={@edit_form[:title]} label="Title" />
                <.input field={@edit_form[:description]} type="textarea" label="Message" />
                <.input field={@edit_form[:photo_url]} label="Image URL" />
                <div class="flex gap-2 justify-end border-t-[3px] border-black dark:border-white pt-3">
                  <button type="button" phx-click="cancel_edit" class="btn btn-ghost btn-sm">
                    Cancel
                  </button>
                  <button type="submit" class="btn btn-primary btn-sm">
                    Save
                  </button>
                </div>
              </.form>
            <% else %>
              <img
                :if={msg.photo_url && msg.photo_url != ""}
                src={msg.photo_url}
                class="w-full h-52 object-cover border-b-[4px] border-black dark:border-white"
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
                  <div class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                    <button
                      phx-click="edit"
                      phx-value-id={msg.id}
                      class="btn btn-ghost btn-xs"
                    >
                      ✏️
                    </button>
                    <button
                      phx-click="delete"
                      phx-value-id={msg.id}
                      data-confirm="Delete this post?"
                      class="btn btn-ghost btn-xs text-error"
                    >
                      🗑
                    </button>
                  </div>
                </div>
                <p class="text-base-content/80 leading-relaxed mt-1 border-l-[4px] border-[#ffff00] pl-3">
                  {msg.description}
                </p>
                <div class="flex items-center gap-2 mt-2 pt-2 border-t-[2px] border-black/10 dark:border-white/10">
                  <span class="text-[10px] font-black uppercase tracking-widest text-base-content/40">
                    {Calendar.strftime(msg.inserted_at, "%d %b %Y · %H:%M")}
                  </span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
