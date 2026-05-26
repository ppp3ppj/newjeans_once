defmodule NewjeansOnceWeb.HealthController do
  use NewjeansOnceWeb, :controller

  def check(conn, _params) do
    send_resp(conn, 200, "OK")
  end
end
