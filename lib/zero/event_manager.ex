defmodule Zero.EventManager do
  use GenStage

  defp via(name) do
    {:via, Registry, {Zero.EventManager.Registry, name}}
  end

  def exists?(name) do
    [] != Registry.lookup(Zero.EventManager.Registry, name)
  end

  def get_pid(name) do
    [{pid, nil}] = Registry.lookup(Zero.EventManager.Registry, name)
    pid
  end

  def start_link(name) do
    GenStage.start_link(__MODULE__, [], name: via(name))
  end

  def stop(name) do
    GenStage.stop via(name)
  end

  def notify(name, event), do: GenStage.cast via(name), {:notify, event}

  def init([]) do
    {:producer, [], dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_cast({:notify, event}, events) do
    {:noreply, [event], events}
  end

  def handle_demand(demand, events) do
    {to_dispatch, to_keep} = Enum.split(events, demand)
    {:noreply, to_dispatch, to_keep}
  end
end
