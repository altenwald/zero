defmodule ZeroGame.Application do
  @moduledoc false

  use Application
  require Logger

  @impl Application
  @doc false
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: ZeroGame.Game.Registry},
      {Registry, keys: :unique, name: ZeroGame.EventManager.Registry},
      {Registry, keys: :unique, name: ZeroGame.Supervisor.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: ZeroGame.Games}
    ]

    Logger.info("[app] initiated application")

    opts = [strategy: :one_for_one, name: ZeroGame.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
