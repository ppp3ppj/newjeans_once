defmodule NewjeansOnce.Repo.Migrations.CreateFanMessages do
  use Ecto.Migration

  def change do
    create table(:fan_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :string, null: false
      add :photo_url, :string
      add :author, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
