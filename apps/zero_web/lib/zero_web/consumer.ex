defmodule ZeroWeb.Consumer do
  @moduledoc """
  Consumer for the WebSocket. This is in charge of consuming events from the
  event manager and sending it back to the websocket.
  """
  use GenStage, restart: :transient

  require Logger

  def start_link(args) do
    GenStage.start_link(__MODULE__, args)
  end

  @impl GenStage
  @doc false
  def init([producer, websocket]) do
    Process.monitor(websocket)
    {:consumer, websocket, subscribe_to: [producer]}
  end

  @impl GenStage
  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  @impl GenStage
  @doc false
  def handle_events(events, _from, websocket) do
    Logger.debug("events => #{inspect(events)}")

    for event <- events do
      Logger.debug("sending event #{inspect(event)} to #{inspect(websocket)}")
      send(websocket, event)
    end

    {:noreply, [], websocket}
  end
end
