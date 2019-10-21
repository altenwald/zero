defmodule Zero.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @port 1234

  def start(_type, _args) do
    # List all child processes to be supervised
    port_number = Application.get_env(:zero, :port, @port)

    children = [
      {Registry, keys: :unique, name: Zero.Game.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Zero.Games},
      {Registry, keys: :unique, name: Zero.EventManager.Registry},
      Plug.Cowboy.child_spec(scheme: :http,
                             plug: Zero.Router,
                             options: [port: port_number,
                                       dispatch: dispatch()]),
    ]

    Logger.info "[app] initiated application"

    opts = [strategy: :one_for_one, name: Zero.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_, [
        {"/websession", Zero.Websocket, []},
        {"/kiosksession", Zero.Kiosk.Websocket, []},
        {:_, Plug.Cowboy.Handler, {Zero.Router, []}},
      ]}
    ]
  end
end
