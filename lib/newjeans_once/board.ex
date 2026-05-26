defmodule NewjeansOnce.Board do
  import Ecto.Query
  alias NewjeansOnce.{Repo, Board.Message}

  @topic "board:messages"

  def subscribe, do: Phoenix.PubSub.subscribe(NewjeansOnce.PubSub, @topic)

  def list_messages do
    Repo.all(from m in Message, order_by: [desc: m.inserted_at])
  end

  def count_messages, do: Repo.aggregate(Message, :count)

  def get_message!(id), do: Repo.get!(Message, id)

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:created)
  end

  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
    |> broadcast(:updated)
  end

  def delete_message(%Message{} = message) do
    Repo.delete(message)
    |> broadcast(:deleted)
  end

  def change_message(%Message{} = message, attrs \\ %{}),
    do: Message.changeset(message, attrs)

  def delete_all_messages do
    Repo.delete_all(Message)
    Phoenix.PubSub.broadcast(NewjeansOnce.PubSub, @topic, {:nuked})
    :ok
  end

  defp broadcast({:ok, message}, event) do
    Phoenix.PubSub.broadcast(NewjeansOnce.PubSub, @topic, {event, message})
    {:ok, message}
  end

  defp broadcast(error, _), do: error
end
