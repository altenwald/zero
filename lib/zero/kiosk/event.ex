defmodule Zero.Kiosk.Event do
  use GenStage
  require Logger

  def init([producer, game]) do
    Process.monitor game
    {:consumer, game, subscribe_to: [producer]}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  def handle_events(events, _from, game) do
    Logger.debug "events => #{inspect events}"
    for event <- events do
      Logger.debug "sending event #{inspect event} to #{inspect game}"
      send(game, event)
    end
    {:noreply, [], game}
  end
end
