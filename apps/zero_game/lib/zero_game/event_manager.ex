defmodule ZeroGame.EventManager do
  @moduledoc """
  Event Manger is the producer in charge of receive the events related
  to a specific game and spread them to the players. It has no a history
  for the events, that's meaning if a user is disconnected, it needs to
  recreate the state previously to attend events.
  """
  use GenStage

  @registry ZeroGame.EventManager.Registry

  defp via(name) do
    {:via, Registry, {@registry, name}}
  end

  @doc """
  Returns true if the event manager exists otherwise false.
  """
  def exists?(name) do
    get_pid(name) != nil
  end

  @doc """
  Returns the PID for the requested event manager otherwise nil.
  """
  def get_pid(name) do
    case Registry.lookup(@registry, name) do
      [{pid, nil}] -> pid
      [] -> nil
    end
  end

  @doc """
  Starts the event manager.
  """
  def start_link(name) do
    GenStage.start_link(__MODULE__, [], name: via(name))
  end

  @doc """
  Stops the event manager.
  """
  def stop(name) do
    GenStage.stop(via(name))
  end

  @doc """
  Notify an event to the specific event manager.
  """
  def notify(name, event), do: GenStage.cast(via(name), {:notify, event})

  @impl GenStage
  @doc false
  def init([]) do
    {:producer, [], dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl GenStage
  @doc false
  def handle_cast({:notify, event}, state) do
    # Every event received is pushed as new event to be consumed.
    {:noreply, [event], state}
  end

  @impl GenStage
  @doc false
  def handle_demand(_demand, state) do
    # We are not generating information, only transferring the information
    # incoming from inside. That's because we return an empty list for events.
    {:noreply, [], state}
  end
end
