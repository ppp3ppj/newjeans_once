defmodule NewjeansOnce.Repo do
  use Ecto.Repo,
    otp_app: :newjeans_once,
    adapter: Ecto.Adapters.SQLite3
end
