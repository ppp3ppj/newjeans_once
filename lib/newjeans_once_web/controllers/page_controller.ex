defmodule NewjeansOnceWeb.PageController do
  use NewjeansOnceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
