defmodule ZeroGame.ConsumerSender do
  @moduledoc false
  use GenStage

  def start(name) do
    pid = ZeroGame.get_event_manager_pid(name)
    GenStage.start(__MODULE__, [pid, self()])
  end

  def stop(pid) do
    GenStage.stop(pid)
  end

  @impl GenStage
  def init([producer, pid]) do
    {:consumer, pid, subscribe_to: [producer]}
  end

  @impl GenStage
  def handle_events(events, _from, pid) do
    for event <- events do
      send(pid, event)
    end

    {:noreply, [], pid}
  end
end
