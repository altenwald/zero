defmodule ZeroWeb.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  @opts ZeroWeb.Router.init([])

  defp get(path), do: :get |> conn(path) |> ZeroWeb.Router.call(@opts)

  test "the root and the invitation links serve the player interface" do
    for path <- ["/", "/some-game-id"] do
      conn = get(path)
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
      assert conn.resp_body =~ "<html"
    end
  end

  test "the kiosk routes serve the kiosk interface" do
    for path <- ["/kiosk", "/kiosk/some-game-id"] do
      conn = get(path)
      assert conn.status == 200
      assert conn.resp_body =~ "<html"
    end
  end

  test "static files are served" do
    conn = get("/js/index.js")
    assert conn.status == 200
  end

  test "the QR code is a PNG image for the invitation link" do
    conn = get("/qr/abc")
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["image/png"]
    assert <<137, "PNG", _rest::binary>> = conn.resp_body
  end

  test "deeper unknown paths are not found" do
    conn = get("/a/b/c")
    assert conn.status == 404
    assert conn.resp_body == "oops"
  end
end
