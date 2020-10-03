defmodule ZeroGame.EventManager do
  use GenStage

  defp via(name) do
    {:via, Registry, {ZeroGame.EventManager.Registry, name}}
  end

  def exists?(name) do
    [] != Registry.lookup(ZeroGame.EventManager.Registry, name)
  end

  def get_pid(name) do
    [{pid, nil}] = Registry.lookup(ZeroGame.EventManager.Registry, name)
    pid
  end

  def start_link(name) do
    GenStage.start_link(__MODULE__, [], name: via(name))
  end

  def stop(name) do
    GenStage.stop(via(name))
  end

  def notify(name, event), do: GenStage.cast(via(name), {:notify, event})

  def init([]) do
    {:producer, [], dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_cast({:notify, event}, state) do
    {:noreply, [event], state}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end
end
