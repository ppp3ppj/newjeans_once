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
      <div class="max-w-3xl mx-auto px-4 py-10 flex flex-col gap-10">
        <div class="text-center">
          <h1 class="text-4xl font-black bg-gradient-to-r from-pink-500 to-purple-500 bg-clip-text text-transparent">
            Fan Wall 💌
          </h1>
          <p class="text-base-content/50 mt-1">Your posts appear live on every screen</p>
        </div>

        <%!-- New post form --%>
        <.form
          for={@new_form}
          id="new-message-form"
          phx-submit="save_new"
          phx-change="validate_new"
          class="flex flex-col gap-4 p-6 rounded-2xl border border-base-300 bg-base-200/40"
        >
          <h2 class="font-bold text-lg">New Post ✨</h2>
          <.input field={@new_form[:author]} label="Your name" placeholder="e.g. Bunny_Hanni" />
          <.input
            field={@new_form[:title]}
            label="Title"
            placeholder="e.g. Hanni's smile saved me 🐰"
          />
          <.input
            field={@new_form[:description]}
            type="textarea"
            label="Description"
            placeholder="Share your love for NewJeans..."
          />
          <.input
            field={@new_form[:photo_url]}
            label="Image URL (optional)"
            placeholder="https://example.com/photo.jpg"
          />
          <button type="submit" class="btn btn-primary self-end">Post 🎀</button>
        </.form>

        <%!-- Live stream of posts --%>
        <div id="messages" phx-update="stream" class="flex flex-col gap-4">
          <div
            :for={{id, msg} <- @streams.messages}
            id={id}
            class="rounded-2xl border border-base-300 bg-base-100 shadow-sm overflow-hidden group"
          >
            <%= if @editing_id == msg.id do %>
              <.form
                for={@edit_form}
                id={"edit-form-#{msg.id}"}
                phx-submit="save_edit"
                class="flex flex-col gap-3 p-5"
              >
                <.input field={@edit_form[:author]} label="Name" />
                <.input field={@edit_form[:title]} label="Title" />
                <.input field={@edit_form[:description]} type="textarea" label="Description" />
                <.input field={@edit_form[:photo_url]} label="Image URL" />
                <div class="flex gap-2 justify-end">
                  <button type="button" phx-click="cancel_edit" class="btn btn-ghost btn-sm">
                    Cancel
                  </button>
                  <button type="submit" class="btn btn-primary btn-sm">Save</button>
                </div>
              </.form>
            <% else %>
              <img
                :if={msg.photo_url && msg.photo_url != ""}
                src={msg.photo_url}
                class="w-full h-52 object-cover"
              />
              <div class="p-5 flex flex-col gap-1">
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <p class="font-black text-lg">{msg.title}</p>
                    <p class="text-sm text-pink-500 font-medium">by {msg.author}</p>
                  </div>
                  <div class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                    <button phx-click="edit" phx-value-id={msg.id} class="btn btn-ghost btn-xs">
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
                <p class="text-base-content/70 mt-1">{msg.description}</p>
                <p class="text-xs text-base-content/30 mt-2">
                  {Calendar.strftime(msg.inserted_at, "%d %b %Y · %H:%M")}
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
