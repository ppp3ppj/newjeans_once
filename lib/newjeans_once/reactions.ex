defmodule NewjeansOnce.Reactions do
  use GenServer

  @topic "reactions"
  @types ~w(star cat bunny)a

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def react(post_id, type) when type in @types,
    do: GenServer.call(__MODULE__, {:react, post_id, type})

  def get(post_id),
    do: GenServer.call(__MODULE__, {:get, post_id})

  def get_all(post_ids),
    do: GenServer.call(__MODULE__, {:get_all, post_ids})

  def init(state), do: {:ok, state}

  def handle_call({:react, post_id, type}, _from, state) do
    new_state = Map.update(state, {post_id, type}, 1, &(&1 + 1))
    counts = counts_for(new_state, post_id)
    Phoenix.PubSub.broadcast(NewjeansOnce.PubSub, @topic, {:reaction_updated, post_id, counts})
    {:reply, counts, new_state}
  end

  def handle_call({:get, post_id}, _from, state),
    do: {:reply, counts_for(state, post_id), state}

  def handle_call({:get_all, post_ids}, _from, state) do
    result = Map.new(post_ids, fn id -> {id, counts_for(state, id)} end)
    {:reply, result, state}
  end

  defp counts_for(state, post_id),
    do: Map.new(@types, fn type -> {type, Map.get(state, {post_id, type}, 0)} end)
end
