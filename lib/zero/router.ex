defmodule Zero.Router do
  use Plug.Router

  plug Plug.Logger, log: :debug
  plug Plug.Static, from: {:zero, "priv/static"}, at: "/"
  plug Plug.Parsers, parsers: [:json],
                     pass: ["text/*"],
                     json_decoder: Jason
  plug :match
  plug :dispatch
  plug ETag.Plug

  get "/" do
    priv_dir = :code.priv_dir(:zero)
    send_file(conn, 200, "#{priv_dir}/static/index.html")
  end

  get "/qr/:id" do
    url = if (conn.scheme == :http and conn.port == 80) or
       (conn.scheme == :https and conn.port == 443) do
      "#{conn.scheme}://#{conn.host}/#{id}"
    else
      "#{conn.scheme}://#{conn.host}:#{conn.port}/#{id}"
    end
    qr = url
         |> EQRCode.encode()
         |> EQRCode.png(width: 100)
    conn
    |> put_resp_header("content-type", "image/png")
    |> send_resp(200, qr)
  end

  get "/:id" do
    priv_dir = :code.priv_dir(:zero)
    send_file(conn, 200, "#{priv_dir}/static/index.html")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
