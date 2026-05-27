defmodule NewjeansOnceWeb.PageControllerTest do
  use NewjeansOnceWeb.ConnCase

  test "GET / renders the fan wall", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "FAN WALL"
  end
end
