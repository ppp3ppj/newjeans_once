defmodule NewjeansOnce.Board.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "fan_messages" do
    field :title, :string
    field :description, :string
    field :photo_url, :string
    field :author, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:title, :description, :photo_url, :author])
    |> validate_required([:title, :description, :author])
    |> validate_length(:title, min: 1, max: 80)
    |> validate_length(:description, min: 1, max: 500)
    |> validate_format(:photo_url, ~r/^https?:\/\/.+/,
        message: "must be a valid URL")
  end
end
