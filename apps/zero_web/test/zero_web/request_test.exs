defmodule ZeroWeb.RequestTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias ZeroWeb.Request

  test "a remote client is identified by its own address" do
    conn =
      :get
      |> conn("/")
      |> put_peer_data(%{address: {192, 168, 1, 40}, port: 4000, ssl_cert: nil})

    assert Request.remote_ip(conn) == "192.168.1.40"
  end

  test "a loopback peer (a local proxy) is replaced by x-forwarded-for" do
    conn =
      :get
      |> conn("/")
      |> put_peer_data(%{address: {127, 0, 0, 1}, port: 4000, ssl_cert: nil})
      |> put_req_header("x-forwarded-for", "203.0.113.9")

    assert Request.remote_ip(conn) == "203.0.113.9"
  end

  test "a loopback peer without the header stays loopback" do
    conn =
      :get
      |> conn("/")
      |> put_peer_data(%{address: {127, 0, 0, 1}, port: 4000, ssl_cert: nil})

    assert Request.remote_ip(conn) == "127.0.0.1"
  end
end
