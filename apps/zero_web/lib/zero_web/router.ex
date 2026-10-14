defmodule ZeroWeb.Router do
  @moduledoc """
  The router is responsible for the routes implementation. It's defining
  the possible URIs available for the HTTP server.
  """
  use Plug.Router

  plug(Plug.Logger, log: :debug)
  plug(Plug.Static, from: {:zero_web, "priv/static"}, at: "/")

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["text/*"],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)
  # plug ETag.Plug

  get "/websession" do
    upgrade(conn, ZeroWeb.Websocket)
  end

  get "/kiosksession" do
    upgrade(conn, ZeroWeb.Kiosk.Websocket)
  end

  get "/" do
    page(conn, "index.html")
  end

  get "/kiosk" do
    page(conn, "kiosk.html")
  end

  get "/kiosk/:id" do
    page(conn, "kiosk.html")
  end

  get "/qr/:id" do
    url =
      if (conn.scheme == :http and conn.port == 80) or
           (conn.scheme == :https and conn.port == 443) do
        "#{conn.scheme}://#{conn.host}/#{id}"
      else
        "#{conn.scheme}://#{conn.host}:#{conn.port}/#{id}"
      end

    qr =
      url
      |> EQRCode.encode()
      |> EQRCode.png(width: 100)

    conn
    |> put_resp_header("content-type", "image/png")
    |> send_resp(200, qr)
  end

  get "/:id" do
    page(conn, "index.html")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp page(conn, file) do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Path.join([:code.priv_dir(:zero_web), "static", file]))
  end

  defp upgrade(conn, handler) do
    conn
    |> WebSockAdapter.upgrade(handler, [remote_ip: ZeroWeb.Request.remote_ip(conn)], timeout: 60_000)
    |> halt()
  end
end
