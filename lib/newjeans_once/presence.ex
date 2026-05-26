defmodule NewjeansOnce.Presence do
  use Phoenix.Presence,
    otp_app: :newjeans_once,
    pubsub_server: NewjeansOnce.PubSub
end
