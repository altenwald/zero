defmodule ZeroGame.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: ZeroGame.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: ZeroGame.Games},
      {Registry, keys: :unique, name: ZeroGame.EventManager.Registry}
    ]

    Logger.info("[app] initiated application")

    opts = [strategy: :one_for_one, name: ZeroGame.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
