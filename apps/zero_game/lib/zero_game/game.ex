defmodule ZeroGame.Game do
  use GenStateMachine, callback_mode: :state_functions, restart: :transient

  @card_colors [:blue, :red, :yellow, :green]
  @card_types [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, :reverse, :turn, :plus_2]
  @special_cards [{:special, :plus_4}, {:special, :color_change}]

  @inital_cards 10
  @max_num_players 7
  @max_pick_from_deck 4

  @max_menu_time 3_600_000
  @max_game_time 21_600_000
  @max_ended_time 1_800_000

  alias ZeroGame.{EventManager, Game}

  @type name :: String.t()

  @type card :: {card_color, card_type}
  @type card_color :: :blue | :red | :yellow | :green
  @type all_card_color :: card_color | :special
  @type card_type :: 1..9 | :reverse | :turn | :plus_2 | :plus_4 | :color_change
  @type cards :: [card]
  @type player_status :: :waiting | :ready | :out

  @type player :: {pid, name, cards, player_status}
  @type players :: [player]

  @type t :: %__MODULE__{
    players: players,
    deck: cards,
    shown: cards,
    shown_color: nil | card_color,
    can_pass: boolean,
    pick_from_deck: integer,
    name: nil | name
  }

  defstruct players: [],
            deck: [],
            shown: [],
            shown_color: nil,
            can_pass: false,
            pick_from_deck: @max_pick_from_deck,
            name: nil

  defp via(game) do
    {:via, Registry, {ZeroGame.Game.Registry, game}}
  end

  def start_link(name) do
    GenStateMachine.start_link(__MODULE__, [name], name: via(name))
  end

  @spec exists?(name) :: boolean
  def exists?(game) do
    case Registry.lookup(ZeroGame.Game.Registry, game) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  defp cast(name, args), do: GenStateMachine.cast(via(name), args)
  defp call(name, args), do: GenStateMachine.call(via(name), args)

  @spec join(game_name :: name, player_name :: name) :: :ok
  def join(name, player_name), do: cast(name, {:join, self(), player_name})

  @spec deal(game_name :: name) :: :ok
  def deal(name), do: cast(name, {:deal, self()})

  @spec get_hand(game_name :: name) :: nil | %{ integer => card }
  def get_hand(name), do: call(name, :get_hand)

  @spec get_players_number(game_name :: name) :: integer
  def get_players_number(name), do: call(name, :players_num)

  @spec get_shown(game_name :: name) :: nil | card
  def get_shown(name), do: call(name, :get_shown)

  @spec play(game_name :: name, integer, nil | card_color) ::
    nil | :ok | {:error, :invalid_card | :invalid_choosen_color | :invalid_number | :not_your_turn}
  def play(name, num, color \\ nil), do: call(name, {:play, num, color})

  @spec pick_from_deck(game_name :: name) ::
    nil | :ok | :gameover | {:error, :max_pick_from_deck | :not_your_turn}
  def pick_from_deck(name), do: call(name, :pick_from_deck)

  @spec pass(game_name :: name) ::
    nil | :ok | {:error, :cannot_pass | :not_your_turn}
  def pass(name), do: call(name, :pass)

  @spec is_my_turn?(game_name :: name) :: nil | boolean
  def is_my_turn?(name), do: call(name, :is_my_turn?)

  @spec color?(game_name :: name) :: nil | card_color
  def color?(name), do: call(name, :color?)

  @spec players(game_name :: name) :: {player_name :: name, cards :: integer, player_status}
  def players(name), do: call(name, :players)

  @spec whose_turn_is_it?(game_name :: name) :: nil | name
  def whose_turn_is_it?(name), do: call(name, :whose_turn_is_it?)

  @spec deck_cards_num(game_name :: name) :: nil | integer
  def deck_cards_num(name), do: call(name, :deck_cards_num)

  @spec restart(game_name :: name) :: :ok
  def restart(name), do: cast(name, :restart)

  @spec valid_name?(game_name :: name, username :: name) :: boolean
  def valid_name?(name, username), do: call(name, {:valid_name?, username})

  @spec is_game_over?(game_name :: name) :: boolean
  def is_game_over?(name), do: call(name, :is_game_over?)

  @spec is_started?(game_name :: name) :: boolean
  def is_started?(name), do: call(name, :is_started?)

  @spec get_pid(game_name :: name) :: pid
  def get_pid(game) do
    [{pid, _}] = Registry.lookup(ZeroGame.Game.Registry, game)
    pid
  end

  @spec stop(game_name :: name) :: :ok
  def stop(name) do
    GenStateMachine.stop(via(name))
  end

  @impl true
  @doc false
  def init([name]) do
    game = %Game{deck: shuffle_cards(), name: name}
    {:ok, :waiting_players, game, [{:state_timeout, @max_menu_time, :game_over}]}
  end

  @impl true
  @doc false
  def code_change(_old_vsn, state_name, state_data, _extra) do
    {:ok, state_name, state_data}
  end

  ## State: waiting for players

  @doc false
  def waiting_players(:state_timeout, :game_over, _state), do: :stop

  def waiting_players({:call, from}, :is_started?, _state) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def waiting_players({:call, from}, :is_game_over?, _state) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def waiting_players(:cast, {:join, _, _}, %Game{players: players})
      when length(players) > @max_num_players do
    :keep_state_and_data
  end

  def waiting_players(:cast, {:join, player_pid, player_name}, game) do
    case {find_by_name(game, player_name), find_by_pid(game, player_pid)} do
      {nil, nil} ->
        Process.monitor(player_pid)
        EventManager.notify(game.name, {:join, player_name})
        {:keep_state, %Game{game | players: [{player_pid, player_name, [], :waiting} | game.players]}}

      _ ->
        :keep_state_and_data
    end
  end

  def waiting_players(:cast, {:deal, pid}, %Game{players: p} = game) when length(p) < 2 do
    {:keep_state, ready_player(game, pid)}
  end

  def waiting_players(:cast, {:deal, pid}, game) do
    game = ready_player(game, pid)
    if Enum.all?(game.players, fn {_pid, _name, _cards, status} -> status == :ready end) do
      game = give_cards(game)
      {:next_state, :playing, game, [{:state_timeout, @max_game_time, :game_over}]}
    else
      {:keep_state, game}
    end
  end

  def waiting_players({:call, from}, :players_num, %Game{players: players}) do
    {:keep_state_and_data, [{:reply, from, length(players)}]}
  end

  def waiting_players({:call, from}, :players, %Game{players: players}) do
    players = for {_, name, cards, status} <- players, do: {name, length(cards), status}
    {:keep_state_and_data, [{:reply, from, players}]}
  end

  def waiting_players({:call, from}, {:valid_name?, ""}, _game) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def waiting_players({:call, from}, {:valid_name?, username}, game) do
    reply =
      not Enum.any?(game.players, fn
        {_, ^username, _, _} -> true
        {_, _, _, _} -> false
      end)

    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def waiting_players(
        :info,
        {:DOWN, _ref, :process, player_pid, _reason},
        %Game{players: players} = game
      ) do
    {_, player_name, _, _} = player = find_by_pid(game, player_pid)
    EventManager.notify(game.name, {:disconnected, player_name})
    {:keep_state, %Game{game | players: players -- [player]}}
  end

  def waiting_players({:call, from}, _event, _state) do
    {:keep_state_and_data, [{:reply, from, nil}]}
  end

  def waiting_players(:cast, :restart, _game) do
    :keep_state_and_data
  end

  ## State: playing

  def playing(:state_timeout, :game_over, _state), do: :stop

  def playing({:call, from}, :is_game_over?, _state) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def playing({:call, from}, :is_started?, _state) do
    {:keep_state_and_data, [{:reply, from, true}]}
  end

  def playing(:cast, {:join, player_pid, name}, %Game{players: players} = game) do
    players =
      case find_by_name(game, name) do
        nil ->
          players

        {^player_pid, ^name, _cards, _status} ->
          players

        {nil, ^name, cards, _status} ->
          Process.monitor(player_pid)
          EventManager.notify(game.name, {:join, name})
          List.keyreplace(players, name, 1, {player_pid, name, cards, :waiting})

        {old_pid, ^name, cards, _status} ->
          Process.exit(old_pid, :kicked)
          Process.monitor(player_pid)
          EventManager.notify(game.name, {:join, name})
          List.keyreplace(players, name, 1, {player_pid, name, cards, :waiting})
      end

    {:keep_state, %Game{game | players: players}}
  end

  def playing(:cast, {:deal, pid}, game) do
    game = ready_player(game, pid)
    EventManager.notify(game.name, :dealt)
    {:keep_state, game}
  end

  def playing({:call, {player_pid, _} = from}, :get_hand, game) do
    reply =
      case find_by_pid(game, player_pid) do
        nil ->
          :not_found

        {_pid, _name, cards, _status} ->
          cards
          |> Enum.with_index(1)
          |> List.foldl(%{}, fn {v, k}, acc -> Map.put_new(acc, k, v) end)
      end

    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def playing({:call, from}, :players_num, %Game{players: players}) do
    {:keep_state_and_data, [{:reply, from, length(players)}]}
  end

  def playing({:call, from}, :deck_cards_num, %Game{deck: deck}) do
    {:keep_state_and_data, [{:reply, from, length(deck)}]}
  end

  def playing({:call, from}, :get_shown, %Game{shown: [card_shown | _]}) do
    {:keep_state_and_data, [{:reply, from, card_shown}]}
  end

  def playing({:call, from}, :is_my_turn?, %Game{players: [{pid, _, _, _} | _]}) do
    reply =
      case from do
        {^pid, _} -> true
        {_, _} -> false
      end

    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def playing({:call, from}, :color?, %Game{shown_color: color, shown: [{:special, _} | _]}) do
    {:keep_state_and_data, [{:reply, from, color}]}
  end

  def playing({:call, from}, :color?, %Game{shown: [{color, _} | _]}) do
    {:keep_state_and_data, [{:reply, from, color}]}
  end

  def playing({:call, from}, :whose_turn_is_it?, game) do
    {:keep_state_and_data, [{:reply, from, player_name(game)}]}
  end

  def playing({:call, from}, :players, %Game{players: players}) do
    players = for {_, name, cards, status} <- players, do: {name, length(cards), status}
    {:keep_state_and_data, [{:reply, from, players}]}
  end

  def playing({:call, from}, {:valid_name, _player_name}, _game) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def playing({:call, {player_pid, _} = from}, _action, %Game{players: [{other_pid, _, _, _} | _]})
      when player_pid != other_pid do
    {:keep_state_and_data, [{:reply, from, {:error, :not_your_turn}}]}
  end

  def playing({:call, from}, {:play, num, _color}, %Game{players: [{_, _, cards, _} | _]})
      when length(cards) < num or num <= 0 do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_number}}]}
  end

  def playing({:call, from}, {:play, _num, color}, _game)
      when color not in @card_colors and color != nil do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_choosen_color}}]}
  end

  def playing(
        {:call, from},
        {:play, num, choosen_color},
        %Game{players: [{_pid, player_name, cards, _status} | _players], shown: [{color, type} | _]} = game
      ) do
    played_card = Enum.at(cards, num - 1)

    if valid?(played_card, color, type, game.shown_color) do
      num_cards = length(cards) - 1
      EventManager.notify(game.name, {:cards, player_name, num_cards})

      game =
        game
        |> play_card(played_card)
        |> effects(played_card, choosen_color, player_name)

      if game_ends?(game) do
        EventManager.notify(game.name, {:game_over, who_wins?(game)})
        actions = [{:reply, from, :ok}, {:state_timeout, @max_ended_time, :terminate}]
        {:next_state, :ended, game, actions}
      else
        EventManager.notify(game.name, {:turn, player_name(game), player_name})
        {:keep_state, game, [{:reply, from, :ok}]}
      end
    else
      {:keep_state_and_data, [{:reply, from, {:error, :invalid_card}}]}
    end
  end

  def playing({:call, from}, :pick_from_deck, %Game{deck: []} = game) do
    EventManager.notify(game.name, {:game_over, who_wins?(game)})
    actions = [{:reply, from, :game_over}, {:state_timeout, @max_ended_time, :terminate}]
    {:next_state, :ended, game, actions}
  end

  def playing({:call, from}, :pick_from_deck, %Game{pick_from_deck: 0}) do
    {:keep_state_and_data, [{:reply, from, {:error, :max_pick_from_deck}}]}
  end

  def playing({:call, from}, :pick_from_deck, game) do
    EventManager.notify(game.name, {:pick_from_deck, player_name(game)})
    {:keep_state, pick_card(game), [{:reply, from, :ok}]}
  end

  def playing({:call, from}, :pass, %Game{can_pass: false}) do
    {:keep_state_and_data, [{:reply, from, {:error, :cannot_pass}}]}
  end

  def playing({:call, from}, :pass, game) do
    previous = player_name(game)
    EventManager.notify(game.name, {:pass, previous})
    game = next_player(game)
    EventManager.notify(game.name, {:turn, player_name(game), previous})
    {:keep_state, game, [{:reply, from, :ok}]}
  end

  def playing(:info, {:DOWN, _ref, :process, player_pid, _reason}, %Game{players: players} = game) do
    players =
      case find_by_pid(game, player_pid) do
        nil ->
          players

        {_, player_name, cards, _status} ->
          EventManager.notify(game.name, {:disconnected, player_name})
          List.keyreplace(players, player_pid, 0, {nil, player_name, cards, :out})
      end

    {:keep_state, %Game{game | players: players}}
  end

  def playing(:cast, :restart, _game) do
    :keep_state_and_data
  end

  ## State: ended

  def ended({:call, from}, :is_game_over?, _state) do
    {:keep_state_and_data, [{:reply, from, true}]}
  end

  def ended({:call, from}, :is_started?, _state) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def ended(:cast, :restart, game) do
    game =
      game
      |> Map.put(:deck, shuffle_cards())
      |> give_cards()

    {:next_state, :playing, game, [{:state_timeout, @max_game_time, :game_over}]}
  end

  def ended(:cast, _msg, _game), do: :keep_state_and_data

  def ended({:call, {player_pid, _} = from}, :get_hand, game) do
    reply =
      case find_by_pid(game, player_pid) do
        nil ->
          :not_found

        {_pid, _name, cards, _status} ->
          cards
          |> Enum.with_index(1)
          |> List.foldl(%{}, fn {v, k}, acc -> Map.put_new(acc, k, v) end)
      end

    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def ended({:call, from}, :players_num, %Game{players: players}) do
    {:keep_state_and_data, [{:reply, from, length(players)}]}
  end

  def ended({:call, from}, :deck_cards_num, %Game{deck: deck}) do
    {:keep_state_and_data, [{:reply, from, length(deck)}]}
  end

  def ended({:call, from}, :get_shown, %Game{shown: [card_shown | _]}) do
    {:keep_state_and_data, [{:reply, from, card_shown}]}
  end

  def ended({:call, from}, :is_my_turn?, _game) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def ended({:call, from}, :color?, %Game{shown_color: color, shown: [{:special, _} | _]}) do
    {:keep_state_and_data, [{:reply, from, color}]}
  end

  def ended({:call, from}, :color?, %Game{shown: [{color, _} | _]}) do
    {:keep_state_and_data, [{:reply, from, color}]}
  end

  def ended({:call, from}, :whose_turn_is_it?, game) do
    {:keep_state_and_data, [{:reply, from, player_name(game)}]}
  end

  def ended({:call, from}, :players, %Game{players: players}) do
    players = for {_, name, cards, status} <- players, do: {name, length(cards), status}
    {:keep_state_and_data, [{:reply, from, players}]}
  end

  def ended({:call, from}, _request, _game) do
    {:keep_state_and_data, [{:reply, from, :game_over}]}
  end

  def ended(:info, _msg, _game), do: :keep_state_and_data

  def ended(:state_timeout, :terminate, _game), do: :stop

  ## Internal functions

  defp ready_player(game, pid) do
    if  player = find_by_pid(game, pid) do
      {^pid, name, cards, _status} = player
      %Game{game | players: [{pid, name, cards, :ready}|game.players -- [player]]}
    end
  end

  defp find_by_name(game, player_name) do
    List.keyfind(game.players, player_name, 1)
  end

  defp find_by_pid(game, player_pid) do
    List.keyfind(game.players, player_pid, 0)
  end

  defp give_cards(game) do
    times = @inital_cards * length(game.players)
    EventManager.notify(game.name, :dealing)

    players =
      Enum.map(
        game.players,
        fn {pid, name, _, status} -> {pid, name, [], status} end
      )

    game = %Game{game | players: players}

    give_card = fn _, game ->
      EventManager.notify(game.name, {:deal, player_name(game)})

      game
      |> pick_card()
      |> next_player()
    end

    game =
      List.foldl(Enum.to_list(1..times), game, give_card)
      |> shown_card()

    EventManager.notify(game.name, :dealt)
    game
  end

  defp valid?({:special, _}, _color, _type, _choosen_color), do: true
  defp valid?({color, _}, :special, _type, color), do: true
  defp valid?({color, _}, color, _type, _choosen_color), do: true
  defp valid?({_, type}, _color, type, _choosen_color), do: true
  defp valid?(_card, _color, _type, _choosen_color), do: false

  defp game_ends?(%Game{players: players}) do
    Enum.any?(players, fn {_pid, _name, cards, _status} -> cards == [] end)
  end

  defp who_wins?(%Game{players: players}) do
    [{_, name} | _] =
      players
      |> Enum.map(fn {_pid, name, cards, _status} -> {length(cards), name} end)
      |> Enum.sort()

    name
  end

  defp player_name(%Game{players: [{_, name, _, _} | _]}), do: name

  defp effects(game, {_color, :plus_2}, _choosen_color, previous) do
    EventManager.notify(game.name, {:plus_2, player_name(game), previous})

    %Game{game | pick_from_deck: @max_pick_from_deck + 2}
    |> pick_card(2)
  end

  defp effects(game, {:special, :plus_4}, choosen_color, previous) do
    EventManager.notify(game.name, {:plus_4, player_name(game), previous})
    EventManager.notify(game.name, {:color_change, choosen_color})

    %Game{game | shown_color: choosen_color, pick_from_deck: @max_pick_from_deck + 4}
    |> pick_card(4)
  end

  defp effects(game, {:special, :color_change}, choosen_color, _previous) do
    EventManager.notify(game.name, {:color_change, choosen_color})
    %Game{game | shown_color: choosen_color}
  end

  defp effects(game, {_color, :reverse}, _choosen_color, previous) do
    EventManager.notify(game.name, {:reverse, previous})
    [player | players] = Enum.reverse(game.players)
    %Game{game | players: players ++ [player]}
  end

  defp effects(game, {_color, :turn}, _choosen_color, previous) do
    EventManager.notify(game.name, {:lose_turn, player_name(game), previous})
    next_player(game)
  end

  defp effects(game, _played_card, _choosen_color, _previous), do: game

  defp play_card(
         %Game{players: [{pid, name, cards, status} | players]} = game,
         played_card
       ) do
    player = {pid, name, cards -- [played_card], status}

    %Game{game | players: [player | players]}
    |> shown_card(played_card)
    |> next_player()
  end

  defp next_player(%Game{players: [player | players]} = game) do
    %Game{
      game
      | players: players ++ [player],
        can_pass: false,
        pick_from_deck: @max_pick_from_deck
    }
  end

  defp pick_card(game, times \\ 1)

  defp pick_card(%Game{deck: []} = game, _times), do: game

  defp pick_card(game, 0), do: game

  defp pick_card(
         %Game{players: [{player, name, cards, status} | players], deck: [new_card | deck]} = game,
         times
       ) do
    %Game{
      game
      | players: [{player, name, [new_card | cards], status} | players],
        deck: deck,
        can_pass: true,
        pick_from_deck: game.pick_from_deck - 1
    }
    |> pick_card(times - 1)
  end

  defp shown_card(game, card) do
    %Game{game | shown: [card | game.shown]}
  end

  defp shown_card(%Game{deck: [{:special, _} = card | deck]} = game) do
    shown_card(%Game{game | deck: deck ++ [card]})
  end

  defp shown_card(%Game{deck: [card | deck]} = game) do
    %Game{game | shown: [card | game.shown], deck: deck}
  end

  if Mix.env() == :test do
    defp shuffle(cards), do: cards
  else
    defdelegate shuffle(cards), to: Enum
  end

  defp shuffle_cards do
    deck =
      for c <- @card_colors do
        for t <- @card_types do
          {c, t}
        end
      end ++ List.duplicate(@special_cards, 2)

    # we use 2 decks to play more time :-)
    (deck ++ deck)
    |> List.flatten()
    |> shuffle()
  end
end
