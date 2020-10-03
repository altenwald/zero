defmodule ZeroWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @port 1234

  def start(_type, _args) do
    # List all child processes to be supervised
    port_number = Application.get_env(:zero_web, :port, @port)

    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: ZeroWeb.Router,
        options: [port: port_number, dispatch: dispatch()]
      )
    ]

    Logger.info("[app] initiated application")

    opts = [strategy: :one_for_one, name: ZeroWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def vsn do
    to_string(Application.spec(:zero_web)[:vsn])
  end

  defp dispatch do
    [
      {:_,
       [
         {"/websession", ZeroWeb.Websocket, []},
         {"/kiosksession", ZeroWeb.Kiosk.Websocket, []},
         {:_, Plug.Cowboy.Handler, {ZeroWeb.Router, []}}
       ]}
    ]
  end
end
