defmodule ZeroGame do
  @moduledoc """
  Zero is a card game to be played for 1-8 players. This
  module is an interface for the game core which let you
  have access to the game through different actions and
  ways to retrieve information.
  """

  @sup_reg ZeroGame.Supervisor.Registry

  alias ZeroGame.{Bot, EventManager, Game}

  @doc """
  Starts the game. It is starting a new supervisor with two
  children: the consumer and the game state machine.
  """
  def start(game) do
    children = [
      {Game, game},
      {EventManager, game},
      {DynamicSupervisor, strategy: :one_for_one}
    ]
    sup_via = {:via, Registry, {@sup_reg, game}}
    opts = [strategy: :one_for_one, name: sup_via]
    args = %{
      id: __MODULE__,
      start: {Supervisor, :start_link, [children, opts]}
    }
    DynamicSupervisor.start_child(ZeroGame.Games, args)
  end

  def start_bot(name, username) do
    [{pid, nil}] = Registry.lookup(@sup_reg, name)
    children = DynamicSupervisor.which_children(pid)
    [dynsup] = for {_, pid, :supervisor, _} <- children, do: pid
    DynamicSupervisor.start_child(dynsup, {Bot, [name, username]})
  end

  @doc """
  Retrieves the PID for the EventManager.
  """
  defdelegate get_event_manager_pid(name), to: EventManager, as: :get_pid

  @doc """
  Stops the consumer and the game state machine independently.
  """
  def stop(name) do
    [{pid, nil}] = Registry.lookup(@sup_reg, name)
    DynamicSupervisor.terminate_child(ZeroGame.Games, pid)
  end

  @doc """
  Tells if the game exists or not.
  """
  defdelegate exists?(game), to: ZeroGame.Game

  @doc """
  A user provides a `player_name` to join a game based on
  the `name`. It only lets play in the same game to 8 players.
  The PID from the caller process is assigned to the game and
  it's monitored. If the process terminates, the user is
  disconnected until it's connected again with the same player
  name.
  """
  defdelegate join(name, player_name), to: ZeroGame.Game

  @doc """
  Request dealing cards. If there is more than one player it
  starts the game for all of the players.
  """
  defdelegate deal(name), to: ZeroGame.Game

  @doc """
  Get the hand of cards assigned to the caller user.
  """
  defdelegate get_hand(name), to: ZeroGame.Game

  @doc """
  Get the number of players in the game.
  """
  defdelegate get_players_number(name), to: ZeroGame.Game

  @doc """
  Get the card which is shown on the table.
  """
  defdelegate get_shown(name), to: ZeroGame.Game

  @doc """
  Uses a card to play. If the card you choose match against
  the card shown on the table (by number, color or because is
  a special card). The card is placed on the table.
  """
  defdelegate play(name, num, color \\ nil), to: ZeroGame.Game

  @doc """
  Pick a card up from the deck. It decrements the amount of cards
  from the deck and increase the number of cards in the hand of
  the player.
  """
  defdelegate pick_from_deck(name), to: ZeroGame.Game

  @doc """
  Performs the turn pass. It is only possible if the player picked
  a card up from the deck first.
  """
  defdelegate pass(name), to: ZeroGame.Game

  @doc """
  Is my turn? The function returns if the process caller is which
  has the possibility to play or not.
  """
  defdelegate is_my_turn?(name), to: ZeroGame.Game

  @doc """
  Color? It's giving the current and active color based on the
  card shown on the table.
  """
  defdelegate color?(name), to: ZeroGame.Game

  @doc """
  Retrieve player names and number of cards per player.
  """
  defdelegate players(name), to: ZeroGame.Game

  @doc """
  Whose turn is it? Returns the name of the player who is playing
  at the current moment.
  """
  defdelegate whose_turn_is_it?(name), to: ZeroGame.Game

  @doc """
  Retrieve the number of cards in the deck.
  """
  defdelegate deck_cards_num(name), to: ZeroGame.Game

  @doc """
  Restarts the game.
  """
  defdelegate restart(name), to: ZeroGame.Game

  @doc """
  Check if that's a valid name for a user.
  """
  defdelegate valid_name?(name, username), to: ZeroGame.Game

  @doc """
  Is Game Over? Is telling us if the game is over or not.
  """
  defdelegate is_game_over?(name), to: ZeroGame.Game

  @doc """
  Is started? Tell us if the game started or not.
  """
  defdelegate is_started?(name), to: ZeroGame.Game
end
