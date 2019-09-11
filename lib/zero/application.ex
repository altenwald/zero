defmodule Zero.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Registry, keys: :unique, name: Zero.Game.Registry},
      {Registry, keys: :unique, name: Zero.EventManager.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Zero.Games},
    ]

    Logger.info "[app] initiated application"

    opts = [strategy: :one_for_one, name: Zero.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
