defmodule ZeroGame do
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

  alias ZeroGame
  alias ZeroGame.EventManager

  @type name :: String.t()

  @type card :: {card_color, card_type}
  @type card_color :: :blue | :red | :yellow | :green | :special
  @type card_type :: 1..9 | :reverse | :turn | :plus_2 | :plus_4 | :color_change
  @type cards :: [card]

  @type player :: {pid, name, cards}
  @type players :: [player]

  defstruct players: [],
            deck: [],
            shown: [],
            shown_color: nil,
            can_pass: false,
            pick_from_deck: @max_pick_from_deck,
            name: nil

  defp via(game) do
    {:via, Registry, {ZeroGame.Registry, game}}
  end

  defp sup_via(game) do
    {:via, Registry, {ZeroGame.Supervisor.Registry, game}}
  end

  def start_link(name) do
    GenStateMachine.start_link(__MODULE__, [name], name: via(name))
  end

  def start(game) do
    children = [
      {ZeroGame, game},
      {EventManager, game}
    ]
    opts = [strategy: :one_for_one, name: sup_via(game)]
    args = %{
      id: __MODULE__,
      start: {Supervisor, :start_link, [children, opts]}
    }
    DynamicSupervisor.start_child(ZeroGame.Games, args)
  end

  def exists?(game) do
    case Registry.lookup(ZeroGame.Registry, game) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  defp cast(name, args), do: GenStateMachine.cast(via(name), args)
  defp call(name, args), do: GenStateMachine.call(via(name), args)

  def join(name, player_name), do: cast(name, {:join, self(), player_name})
  def deal(name), do: cast(name, :deal)
  def get_hand(name), do: call(name, :get_hand)
  def get_players_number(name), do: call(name, :players_num)
  def get_shown(name), do: call(name, :get_shown)
  def play(name, num, color \\ nil), do: call(name, {:play, num, color})
  def pick_from_deck(name), do: call(name, :pick_from_deck)
  def pass(name), do: call(name, :pass)
  def is_my_turn?(name), do: call(name, :is_my_turn?)
  def color?(name), do: call(name, :color?)
  def players(name), do: call(name, :players)
  def whose_turn_is_it?(name), do: call(name, :whose_turn_is_it?)
  def deck_cards_num(name), do: call(name, :deck_cards_num)
  def restart(name), do: cast(name, :restart)
  def valid_name?(name, username), do: call(name, {:valid_name?, username})
  def is_game_over?(name), do: call(name, :is_game_over?)
  def is_started?(name), do: call(name, :is_started?)

  def get_pid(game) do
    [{pid, _}] = Registry.lookup(ZeroGame.Registry, game)
    pid
  end

  def stop(name) do
    EventManager.stop(name)
    GenStateMachine.stop(via(name))
  end

  @impl true
  def init([name]) do
    game = %ZeroGame{deck: shuffle_cards(), name: name}
    {:ok, :waiting_players, game, [{:state_timeout, @max_menu_time, :game_over}]}
  end

  @impl true
  def code_change(_old_vsn, state_name, state_data, _extra) do
    {:ok, state_name, state_data}
  end

  ## State: waiting for players

  def waiting_players(:state_timeout, :game_over, _state), do: :stop

  def waiting_players({:call, from}, :is_started?, _state) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def waiting_players({:call, from}, :is_game_over?, _state) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def waiting_players(:cast, {:join, _, _}, %ZeroGame{players: players})
      when length(players) > @max_num_players do
    :keep_state_and_data
  end

  def waiting_players(:cast, {:join, player_pid, player_name}, game) do
    case {List.keyfind(game.players, player_name, 1), List.keyfind(game.players, player_pid, 0)} do
      {nil, nil} ->
        Process.monitor(player_pid)
        EventManager.notify(game.name, {:join, player_name})
        {:keep_state, %ZeroGame{game | players: [{player_pid, player_name, []} | game.players]}}

      _ ->
        :keep_state_and_data
    end
  end

  def waiting_players(:cast, :deal, %ZeroGame{players: p}) when length(p) < 2 do
    :keep_state_and_data
  end

  def waiting_players(:cast, :deal, game) do
    game = give_cards(game)
    {:next_state, :playing, game, [{:state_timeout, @max_game_time, :game_over}]}
  end

  def waiting_players({:call, from}, :players_num, %ZeroGame{players: players}) do
    {:keep_state_and_data, [{:reply, from, length(players)}]}
  end

  def waiting_players({:call, from}, :players, %ZeroGame{players: players}) do
    players = for {_, name, cards} <- players, do: {name, length(cards)}
    {:keep_state_and_data, [{:reply, from, players}]}
  end

  def waiting_players({:call, from}, {:valid_name?, ""}, _game) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def waiting_players({:call, from}, {:valid_name?, username}, game) do
    reply =
      not Enum.any?(game.players, fn
        {_, ^username, _} -> true
        {_, _, _} -> false
      end)

    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def waiting_players(
        :info,
        {:DOWN, _ref, :process, player_pid, _reason},
        %ZeroGame{players: players} = game
      ) do
    {_, player_name, _} = player = List.keyfind(players, player_pid, 0)
    EventManager.notify(game.name, {:disconnected, player_name})
    {:keep_state, %ZeroGame{game | players: players -- [player]}}
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

  def playing(:cast, {:join, player_pid, name}, %ZeroGame{players: players} = game) do
    players =
      case List.keyfind(players, name, 1) do
        nil ->
          players

        {^player_pid, ^name, _cards} ->
          players

        {nil, ^name, cards} ->
          Process.monitor(player_pid)
          EventManager.notify(game.name, {:join, name})
          List.keyreplace(players, name, 1, {player_pid, name, cards})

        {old_pid, ^name, cards} ->
          Process.exit(old_pid, :kicked)
          Process.monitor(player_pid)
          EventManager.notify(game.name, {:join, name})
          List.keyreplace(players, name, 1, {player_pid, name, cards})
      end

    {:keep_state, %ZeroGame{game | players: players}}
  end

  def playing(:cast, :deal, game) do
    EventManager.notify(game.name, :dealt)
    :keep_state_and_data
  end

  def playing({:call, {player_pid, _} = from}, :get_hand, %ZeroGame{players: players}) do
    reply =
      case List.keyfind(players, player_pid, 0) do
        nil ->
          :not_found

        {_pid, _name, cards} ->
          cards
          |> Enum.with_index(1)
          |> List.foldl(%{}, fn {v, k}, acc -> Map.put_new(acc, k, v) end)
      end

    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def playing({:call, from}, :players_num, %ZeroGame{players: players}) do
    {:keep_state_and_data, [{:reply, from, length(players)}]}
  end

  def playing({:call, from}, :deck_cards_num, %ZeroGame{deck: deck}) do
    {:keep_state_and_data, [{:reply, from, length(deck)}]}
  end

  def playing({:call, from}, :get_shown, %ZeroGame{shown: [card_shown | _]}) do
    {:keep_state_and_data, [{:reply, from, card_shown}]}
  end

  def playing({:call, from}, :is_my_turn?, %ZeroGame{players: [{pid, _, _} | _]}) do
    reply =
      case from do
        {^pid, _} -> true
        {_, _} -> false
      end

    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def playing({:call, from}, :color?, %ZeroGame{shown_color: color, shown: [{:special, _} | _]}) do
    {:keep_state_and_data, [{:reply, from, color}]}
  end

  def playing({:call, from}, :color?, %ZeroGame{shown: [{color, _} | _]}) do
    {:keep_state_and_data, [{:reply, from, color}]}
  end

  def playing({:call, from}, :whose_turn_is_it?, game) do
    {:keep_state_and_data, [{:reply, from, player_name(game)}]}
  end

  def playing({:call, from}, :players, %ZeroGame{players: players}) do
    players = for {_, name, cards} <- players, do: {name, length(cards)}
    {:keep_state_and_data, [{:reply, from, players}]}
  end

  def playing({:call, {player_pid, _} = from}, _action, %ZeroGame{players: [{other_pid, _, _} | _]})
      when player_pid != other_pid do
    {:keep_state_and_data, [{:reply, from, {:error, :not_your_turn}}]}
  end

  def playing({:call, from}, {:play, num, _color}, %ZeroGame{players: [{_, _, cards} | _]})
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
        %ZeroGame{players: [{_pid, player_name, cards} | _players], shown: [{color, type} | _]} = game
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
      {:keep_state_and_data, [{:reply, from, {:error, :not_valid_card}}]}
    end
  end

  def playing({:call, from}, :pick_from_deck, %ZeroGame{deck: []} = game) do
    EventManager.notify(game.name, {:game_over, who_wins?(game)})
    actions = [{:reply, from, :game_over}, {:state_timeout, @max_ended_time, :terminate}]
    {:next_state, :ended, game, actions}
  end

  def playing({:call, from}, :pick_from_deck, %ZeroGame{pick_from_deck: 0}) do
    {:keep_state_and_data, [{:reply, from, {:error, :max_pick_from_deck}}]}
  end

  def playing({:call, from}, :pick_from_deck, game) do
    EventManager.notify(game.name, {:pick_from_deck, player_name(game)})
    {:keep_state, pick_card(game), [{:reply, from, :ok}]}
  end

  def playing({:call, from}, :pass, %ZeroGame{can_pass: false}) do
    {:keep_state_and_data, [{:reply, from, {:error, :cannot_pass}}]}
  end

  def playing({:call, from}, :pass, game) do
    previous = player_name(game)
    EventManager.notify(game.name, {:pass, previous})
    game = next_player(game)
    EventManager.notify(game.name, {:turn, player_name(game), previous})
    {:keep_state, game, [{:reply, from, :ok}]}
  end

  def playing(:info, {:DOWN, _ref, :process, player_pid, _reason}, %ZeroGame{players: players} = game) do
    players =
      case List.keyfind(players, player_pid, 0) do
        nil ->
          players

        {_, player_name, cards} ->
          EventManager.notify(game.name, {:disconnected, player_name})
          List.keyreplace(players, player_pid, 0, {nil, player_name, cards})
      end

    {:keep_state, %ZeroGame{game | players: players}}
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

  def ended({:call, {player_pid, _} = from}, :get_hand, %ZeroGame{players: players}) do
    reply =
      case List.keyfind(players, player_pid, 0) do
        nil ->
          :not_found

        {_pid, _name, cards} ->
          cards
          |> Enum.with_index(1)
          |> List.foldl(%{}, fn {v, k}, acc -> Map.put_new(acc, k, v) end)
      end

    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def ended({:call, from}, :players_num, %ZeroGame{players: players}) do
    {:keep_state_and_data, [{:reply, from, length(players)}]}
  end

  def ended({:call, from}, :deck_cards_num, %ZeroGame{deck: deck}) do
    {:keep_state_and_data, [{:reply, from, length(deck)}]}
  end

  def ended({:call, from}, :get_shown, %ZeroGame{shown: [card_shown | _]}) do
    {:keep_state_and_data, [{:reply, from, card_shown}]}
  end

  def ended({:call, from}, :is_my_turn?, _game) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def ended({:call, from}, :color?, %ZeroGame{shown_color: color, shown: [{:special, _} | _]}) do
    {:keep_state_and_data, [{:reply, from, color}]}
  end

  def ended({:call, from}, :color?, %ZeroGame{shown: [{color, _} | _]}) do
    {:keep_state_and_data, [{:reply, from, color}]}
  end

  def ended({:call, from}, :whose_turn_is_it?, game) do
    {:keep_state_and_data, [{:reply, from, player_name(game)}]}
  end

  def ended({:call, from}, :players, %ZeroGame{players: players}) do
    players = for {_, name, cards} <- players, do: {name, length(cards)}
    {:keep_state_and_data, [{:reply, from, players}]}
  end

  def ended({:call, from}, _request, _game) do
    {:keep_state_and_data, [{:reply, from, :game_over}]}
  end

  def ended(:info, _msg, _game), do: :keep_state_and_data

  def ended(:state_timeout, :terminate, _game), do: :stop

  ## Internal functions

  defp give_cards(game) do
    times = @inital_cards * length(game.players)
    EventManager.notify(game.name, :dealing)

    players =
      Enum.map(
        game.players,
        fn {pid, name, _} -> {pid, name, []} end
      )

    game = %ZeroGame{game | players: players}

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

  defp game_ends?(%ZeroGame{players: players}) do
    Enum.any?(players, fn {_pid, _name, cards} -> cards == [] end)
  end

  defp who_wins?(%ZeroGame{players: players}) do
    [{_, name} | _] =
      players
      |> Enum.map(fn {_pid, name, cards} -> {length(cards), name} end)
      |> Enum.sort()

    name
  end

  defp player_name(%ZeroGame{players: [{_, name, _} | _]}), do: name

  defp effects(game, {_color, :plus_2}, _choosen_color, previous) do
    EventManager.notify(game.name, {:plus_2, player_name(game), previous})

    %ZeroGame{game | pick_from_deck: @max_pick_from_deck + 2}
    |> pick_card()
    |> pick_card()
  end

  defp effects(game, {:special, :plus_4}, choosen_color, previous) do
    EventManager.notify(game.name, {:plus_4, player_name(game), previous})
    EventManager.notify(game.name, {:color_change, choosen_color})

    %ZeroGame{game | shown_color: choosen_color, pick_from_deck: @max_pick_from_deck + 4}
    |> pick_card()
    |> pick_card()
    |> pick_card()
    |> pick_card()
  end

  defp effects(game, {:special, :color_change}, choosen_color, _previous) do
    EventManager.notify(game.name, {:color_change, choosen_color})
    %ZeroGame{game | shown_color: choosen_color}
  end

  defp effects(game, {_color, :reverse}, _choosen_color, previous) do
    EventManager.notify(game.name, {:reverse, previous})
    [player | players] = Enum.reverse(game.players)
    %ZeroGame{game | players: players ++ [player]}
  end

  defp effects(game, {_color, :turn}, _choosen_color, previous) do
    EventManager.notify(game.name, {:lose_turn, player_name(game), previous})
    next_player(game)
  end

  defp effects(game, _played_card, _choosen_color, _previous), do: game

  defp play_card(
         %ZeroGame{players: [{pid, name, cards} | players]} = game,
         played_card
       ) do
    player = {pid, name, cards -- [played_card]}

    %ZeroGame{
      game
      | shown: [played_card | game.shown],
        players: players ++ [player],
        can_pass: false,
        pick_from_deck: @max_pick_from_deck
    }
  end

  defp next_player(%ZeroGame{players: [player | players]} = game) do
    %ZeroGame{
      game
      | players: players ++ [player],
        can_pass: false,
        pick_from_deck: @max_pick_from_deck
    }
  end

  defp pick_card(%ZeroGame{deck: []} = game), do: game

  defp pick_card(
         %ZeroGame{players: [{player, name, cards} | players], deck: [new_card | deck]} = game
       ) do
    %ZeroGame{
      game
      | players: [{player, name, [new_card | cards]} | players],
        deck: deck,
        can_pass: true,
        pick_from_deck: game.pick_from_deck - 1
    }
  end

  defp shown_card(%ZeroGame{deck: [{:special, _} = card | deck]} = game) do
    shown_card(%ZeroGame{game | deck: deck ++ [card]})
  end

  defp shown_card(%ZeroGame{deck: [card | deck]} = game) do
    %ZeroGame{game | shown: [card | game.shown], deck: deck}
  end

  defp shuffle_cards do
    deck =
      for c <- @card_colors do
        for t <- @card_types do
          {c, t}
        end
      end ++ @special_cards ++ @special_cards

    # we use 2 decks to play more time :-)
    (deck ++ deck)
    |> List.flatten()
    |> Enum.shuffle()
  end
end
