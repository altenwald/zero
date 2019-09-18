defmodule Zero.Bot do
  require Logger
  alias Zero.{Game, EventManager}

  use GenStage

  @time_to_think 1_000
  @colors [:red, :green, :blue, :yellow]

  defmodule State do
    defstruct [:game, :username]
  end

  def start_link(game \\ Zero, username \\ "timmy") do
    pid = EventManager.get_pid(game)
    GenStage.start_link __MODULE__, [pid, game, username]
  end

  @impl true
  def init([producer, game, username]) do
    state = %State{game: game,
                   username: username}
    Game.join(game, username)
    Process.monitor Game.get_pid(game)
    {:consumer, state, subscribe_to: [producer]}
  end

  @impl true
  def handle_events(events, _from, state) do
    List.foldl(events, {:noreply, [], state},
               fn event, {:noreply, [], state} -> process_event(event, state)
                  _event, result -> result
               end)
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  defp process_event(:dealt, state) do
    if Game.is_my_turn?(state.game) do
      Process.sleep @time_to_think
      play(state.game)
    end
    {:noreply, [], state}
  end
  defp process_event({:turn, username, _previous}, %State{username: username} = state) do
    Process.sleep @time_to_think
    play(state.game)
    {:noreply, [], state}
  end
  defp process_event({:turn, _other, _previous}, state), do: {:noreply, [], state}
  defp process_event({:gameover, _winner}, state), do: {:stop, :normal, state}
  defp process_event(event, state) do
    Logger.debug "event not handled => #{inspect event}"
    {:noreply, [], state}
  end

  defp play(game, tries \\ 2) do
    {shown_color, shown_type} = Game.get_shown(game)
    hand = Game.get_hand(game)
    options = hand
              |> Enum.map(fn {i, {c, t}} -> {i, c, t} end)
              |> Enum.filter(fn {_, ^shown_color, _} -> true
                                {_, _, ^shown_type} -> true
                                {_, :special, _} -> true
                                {_, _, _} -> false
                             end)
              |> Enum.sort_by(fn {_, :special, _} -> 3
                                 {_, _, ^shown_type} -> 2
                                 {_, ^shown_color, _} -> 1
                              end)
    Logger.debug "options => #{inspect options}"
    case options do
      [{i, :special, _}|_] -> Game.play(game, i, choose_color(hand))
      [{i, color, _}|_] -> Game.play(game, i, color)
      [] when tries > 0 ->
        Game.pick_from_deck(game)
        play(game, tries - 1)
      [] ->
        Game.pass(game)
    end
  end

  defp choose_color(hand) do
    hand
    |> Enum.map(fn {_, {color, _}} -> color end)
    |> Enum.filter(&(&1 in @colors))
    |> Enum.reduce(%{red: 0, green: 0, blue: 0, yellow: 0},
                   fn color, acc -> Map.update(acc, color, 1, &(&1 + 1)) end)
    |> Enum.sort_by(&(elem(&1, 1)), &>=/2)
    |> hd()
    |> elem(0)
  end
end
