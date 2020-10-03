defmodule ZeroWeb.Listener do
  use GenStage, restart: :transient

  require Logger

  def start_link(args) do
    GenStage.start_link(__MODULE__, args)
  end

  @impl GenStage
  def init([producer, websocket]) do
    Process.monitor(websocket)
    {:consumer, websocket, subscribe_to: [producer]}
  end

  @impl GenStage
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  @impl GenStage
  def handle_events(events, _from, websocket) do
    Logger.debug("events => #{inspect(events)}")

    for event <- events do
      Logger.debug("sending event #{inspect(event)} to #{inspect(websocket)}")
      send(websocket, event)
    end

    {:noreply, [], websocket}
  end
end
