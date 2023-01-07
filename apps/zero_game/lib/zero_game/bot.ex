defmodule ZeroGame.Bot do
  @moduledoc """
  Player controlled by the system. This game is very simple, it only requires
  choose a valid card from the hand the user is handling or pick up a new one
  from the deck, and pass if there's no more options.

  The bot is consuming the events for the game where it was added and then it
  is playing in the following way (see `play/3`):

  1. Get the hand (`Game.get_hand/1` in `hand`)
  2. Process the `options` from `hand` where:
    1. Transform the cards from `{i, {c, t}}` to `{i, c, t}`.
    2. Filter for valid cards `shown_color` and `shown_type` are going to be
       useful for the filtering based on `c` and `t` respectively and we add
       the `:special` cards as well.
    3. We sort the cards based on priority for use:
      1. Cards with the same color as shown card.
      2. Cards with the same type as shown card.
      3. Special cards.
  3. If there's options, we choose the first one and use `Game.play/3`,
     otherwise we pick one card from the deck and replay this algorithm. If
     the number of tries reach zero, then we pass (`Game.pass/1`).

  Note that `i` is for the index, the order for the card, `c` is for the color
  or `:special` value, and `t` is for the type of the card.
  """
  use GenStage

  require Logger

  alias ZeroGame.{EventManager, Game}

  @time_to_think 1_000
  @colors ~w(red green blue yellow)a

  @opaque t() :: %__MODULE__{
    game: String.t(),
    username: String.t()
  }

  defstruct [:game, :username]

  @doc """
  Start the bot for the given game and it is configured with the specified
  username.
  """
  def start_link([game, username]) do
    pid = EventManager.get_pid(game)
    GenStage.start_link(__MODULE__, [pid, game, username])
  end

  @impl GenStage
  @doc false
  def init([producer, game, username]) do
    state = %__MODULE__{game: game, username: username}
    :ok = Game.join(game, username)
    :ok = Game.deal(game)
    Process.monitor(Game.get_pid(game))
    {:consumer, state, subscribe_to: [producer]}
  end

  @impl GenStage
  @doc false
  def handle_events(events, _from, state) do
    Enum.reduce(events, {:noreply, [], state}, fn
      event, {:noreply, [], state} -> process_event(event, state)
      _event, result -> result
    end)
  end

  @impl GenStage
  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  defp process_event(:dealt, state) do
    if Game.is_my_turn?(state.game) do
      Process.sleep(@time_to_think)
      play(state.username, state.game)
    end

    {:noreply, [], state}
  end

  defp process_event({:turn, username, _previous}, %__MODULE__{username: username} = state) do
    Logger.debug("[#{username}] thinking my move")
    Process.sleep(@time_to_think)
    play(username, state.game)
    {:noreply, [], state}
  end

  defp process_event({:turn, _other, _previous}, state) do
    {:noreply, [], state}
  end

  defp process_event({:game_over, winner}, state) do
    Logger.debug("[#{state.username}] game over, winner is #{winner}")
    ## just in case of restart, we don't leave yet
    {:noreply, [], state}
  end

  defp process_event(event, state) do
    Logger.warn("event not handled => #{inspect(event)}")
    {:noreply, [], state}
  end

  defp play(username, game, tries \\ 2) do
    {_color, shown_type} = Game.get_shown(game)
    shown_color = Game.color?(game)
    Logger.debug("[#{username}] the show card is #{shown_color} color and #{shown_type} type")
    hand = Game.get_hand(game)
    Logger.debug("[#{username}] my hand is #{inspect(hand)}")

    options =
      hand
      |> Enum.map(fn {i, {c, t}} -> {i, c, t} end)
      |> Enum.filter(fn
        {_, ^shown_color, _} -> true
        {_, _, ^shown_type} -> true
        {_, :special, _} -> true
        {_, _, _} -> false
      end)
      |> Enum.sort_by(fn
        {_, :special, _} -> 3
        {_, _, ^shown_type} -> 2
        {_, ^shown_color, _} -> 1
      end)

    Logger.debug("[#{username}] my options are #{inspect(options)}")

    case options do
      [{i, :special, _} = card | _] ->
        Logger.debug("[#{username}] playing special one: #{inspect(card)}")
        Game.play(game, i, choose_color(hand))

      [{i, color, _} = card | _] ->
        Logger.debug("[#{username}] playing card: #{inspect(card)}")
        Game.play(game, i, color)

      [] when tries > 0 ->
        Logger.debug("[#{username}] no card available. Picking up!")
        Game.pick_from_deck(game)
        play(username, game, tries - 1)

      [] ->
        Logger.debug("[#{username}] no card. No pickup up. Passing!")
        Game.pass(game)
    end
  end

  defp choose_color(hand) do
    hand
    |> Enum.map(fn {_, {color, _}} -> color end)
    |> Enum.filter(&(&1 in @colors))
    |> Enum.reduce(
      %{red: 0, green: 0, blue: 0, yellow: 0},
      fn color, acc -> Map.update(acc, color, 1, &(&1 + 1)) end
    )
    |> Enum.sort_by(&elem(&1, 1), &>=/2)
    |> log_options()
    |> case do
      [{color, _} | _] -> color
      [] -> Enum.random(~w[red green blue yellow]a)
    end
  end

  defp log_options(options) do
    Logger.debug("options: #{inspect(options)}")
    options
  end
end
