defmodule ZeroWeb.Application do
  @moduledoc false
  use Application

  require Logger

  alias ZeroGame.EventManager

  @port 1234

  @consumer_sup ZeroWeb.Consumers

  @impl Application
  @doc false
  def start(_type, _args) do
    # List all child processes to be supervised
    port_number = Application.get_env(:zero_web, :port, @port)

    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: ZeroWeb.Router,
        options: [port: port_number, dispatch: dispatch()]
      ),
      {DynamicSupervisor, strategy: :one_for_one, name: @consumer_sup}
    ]

    Logger.info("[app] initiated application")

    opts = [strategy: :one_for_one, name: ZeroWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Start a consumer given the name for the event manager (producer) and the
  websocket process id that will be subscribed.
  """
  def start_consumer(name, websocket) do
    producer = EventManager.get_pid(name)
    args = [producer, websocket]
    DynamicSupervisor.start_child(@consumer_sup, {ZeroWeb.Consumer, args})
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
