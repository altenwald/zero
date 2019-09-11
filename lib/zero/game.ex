defmodule Zero.Game do
  use GenStateMachine, callback_mode: :state_functions

  @card_colors [:blue, :red, :yellow, :green]
  @card_types [1, 2, 3, 4, 5, 6, 7, 8, 9, :reverse, :turn, :plus_2]
  @special_cards [{:special, :plus_4},
                  {:special, :color_change}]

  @inital_cards 5

  alias Zero.Game

  defstruct players: [],
            deck: [],
            shown: [],
            shown_color: nil

  def start_link do
    game = %Game{deck: shuffle_cards()}
    GenStateMachine.start_link __MODULE__, {:waiting_players, game}
  end

  def join(game_pid, code) do
    GenStateMachine.cast game_pid, {:join, self(), code}
  end

  def deal(game_pid) do
    GenStateMachine.cast game_pid, :deal
  end

  def get_hand(game_pid) do
    GenStateMachine.call game_pid, :get_hand
  end

  def get_players_number(game_pid) do
    GenStateMachine.call game_pid, :players_num
  end

  def get_shown(game_pid) do
    GenStateMachine.call game_pid, :get_shown
  end

  def play(game_pid, num, color \\ nil) do
    GenStateMachine.call game_pid, {:play, num, color}
  end

  def pick_from_deck(game_pid) do
    GenStateMachine.call game_pid, :pick_from_deck
  end

  def pass(game_pid) do
    GenStateMachine.call game_pid, :pass
  end

  def is_my_turn?(game_pid) do
    GenStateMachine.call game_pid, :is_my_turn?
  end

  def stop(game_pid) do
    GenStateMachine.stop game_pid
  end

  ## State: waiting for players

  def waiting_players(:cast, {:join, player_pid, code}, game) do
    Process.monitor player_pid
    {:keep_state, %Game{game | players: [{player_pid, code, []}|game.players]}}
  end

  def waiting_players(:cast, :deal, game) do
    times = @inital_cards * length(game.players)
    give_card = fn(_, game) ->
                  game
                  |> pick_card()
                  |> next_player()
                end
    game = List.foldl(Enum.to_list(1..times), game, give_card)
           |> shown_card()
    {:next_state, :playing, game}
  end

  def waiting_players({:call, from}, :players_num, %Game{players: players}) do
    {:keep_state_and_data, [{:reply, from, length(players)}]}
  end

  def waiting_players(:info, {:DOWN, _ref, :process, player_pid, _reason},
                      %Game{players: players} = game) do
    players = List.keydelete(players, player_pid, 0)
    {:keep_state, %Game{game | players: players}}
  end

  ## State: playing

  def playing(:cast, {:join, player_pid, code}, %Game{players: players} = game) do
    players = case List.keyfind(players, code, 1) do
      nil ->
        players
      {nil, code, cards} ->
        Process.monitor player_pid
        List.keyreplace(players, code, 1, {player_pid, code, cards})
      {old_pid, code, cards} ->
        Process.exit old_pid, :kicked
        Process.monitor player_pid
        List.keyreplace(players, code, 1, {player_pid, code, cards})
    end
    {:keep_state, %Game{game | players: players}}
  end

  def playing(:cast, :deal, _game) do
    :keep_state_and_data
  end

  def playing({:call, {player_pid, _} = from}, :get_hand,
              %Game{players: players}) do
    reply = case List.keyfind(players, player_pid, 0) do
      nil ->
        :not_found
      {_pid, _code, cards} ->
        cards
        |> Enum.with_index()
        |> List.foldl(%{}, fn {v, k}, acc -> Map.put_new(acc, k, v) end)
    end
    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def playing({:call, from}, :players_num, %Game{players: players}) do
    {:keep_state_and_data, [{:reply, from, length(players)}]}
  end

  def playing({:call, from}, :get_shown, %Game{shown: [card_shown|_]}) do
    {:keep_state_and_data, [{:reply, from, card_shown}]}
  end

  def playing({:call, from}, :is_my_turn?, %Game{players: [{pid, _, _}|_]}) do
    reply = case from do
      {^pid, _} -> true
      {_, _} -> false
    end
    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def playing({:call, {player_pid, _} = from}, _action,
              %Game{players: [{other_pid, _, _}|_]})
      when player_pid != other_pid do
    {:keep_state_and_data, [{:reply, from, {:error, :not_your_turn}}]}
  end

  def playing({:call, from}, {:play, num, _color},
              %Game{players: [{_, _, cards}|_]})
      when length(cards) <= num or num < 0 do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_number}}]}
  end
  def playing({:call, from}, {:play, num, choosen_color},
              %Game{players: [{_pid, _code, cards}|_players],
                    shown: [{color, type}|_]} = game) do
    played_card = Enum.at(cards, num)
    if valid?(played_card, color, type, game.shown_color) do
      game = game
             |> play_card(played_card)
             |> effects(played_card, choosen_color)
      if game_ends?(game) do
        {:next_state, :ended, game, [{:reply, from, :ok}]}
      else
        {:keep_state, game, [{:reply, from, :ok}]}
      end
    else
      {:keep_state_and_data, [{:reply, from, {:error, :not_valid_card}}]}
    end
  end

  def playing({:call, from}, :pick_from_deck, %Game{deck: []}) do
    {:keep_state_and_data, [{:reply, from, {:error, :empty_deck}}]}
  end
  def playing({:call, from}, :pick_from_deck, game) do
    {:keep_state, pick_card(game), [{:reply, from, :ok}]}
  end

  def playing({:call, from}, :pass, game) do
    {:keep_state, next_player(game), [{:reply, from, :ok}]}
  end

  def playing(:info, {:DOWN, _ref, :process, player_pid, _reason},
              %Game{players: players} = game) do
    players = case List.keyfind(players, player_pid, 0) do
      nil ->
        players
      {_, code, cards} ->
        List.keyreplace(players, player_pid, 0, {nil, code, cards})
    end
    {:keep_state, %Game{game | players: players}}
  end

  ## State: ended

  def ended(:cast, _msg, _game), do: :keep_state_and_data

  def ended({:call, from}, _request, _game) do
    {:keep_state_and_data, [{:reply, from, :game_over}]}
  end

  def ended(:info, _msg, _game), do: :keep_state_and_data

  ## Internal functions

  defp valid?({:special, _}, _color, _type, _choosen_color), do: true
  defp valid?({color, _}, :special, _type, color), do: true
  defp valid?({color, _}, color, _type, _choosen_color), do: true
  defp valid?({_, type}, _color, type, _choosen_color), do: true
  defp valid?(_card, _color, _type, _choosen_color), do: false

  defp game_ends?(%Game{players: players}) do
    Enum.any? players, fn({_pid, _code, cards}) -> cards == [] end
  end

  defp effects(game, {_color, :plus_2}, _choosen_color) do
    game
    |> pick_card()
    |> pick_card()
  end
  defp effects(game, {:special, :plus_4}, choosen_color) do
    %Game{game | shown_color: choosen_color}
    |> pick_card()
    |> pick_card()
    |> pick_card()
    |> pick_card()    
  end
  defp effects(game, {:special, :color_change}, choosen_color) do
    %Game{game | shown_color: choosen_color}
  end
  defp effects(game, {_color, :reverse}, _choosen_color) do
    [player|players] = Enum.reverse(game.players)
    %Game{game | players: players ++ [player]}
  end
  defp effects(game, {_color, :turn}, _choosen_color) do
    next_player(game)
  end
  defp effects(game, _played_card, _choosen_color), do: game

  defp play_card(%Game{players: [{pid, code, cards}|players]} = game,
                 played_card) do
    player = {pid, code, cards -- [played_card]}
    %Game{game | shown: [played_card|game.shown],
                 players: players ++ [player]}
  end

  defp next_player(%Game{players: [player|players]} = game) do
    %Game{game | players: players ++ [player]}
  end

  defp pick_card(%Game{players: [{player, code, cards}|players],
                       deck: [new_card|deck]} = game) do
    %Game{game | players: [{player, code, [new_card|cards]}|players],
                 deck: deck}
  end

  defp shown_card(%Game{deck: [card|deck]} = game) do
    %Game{game | shown: [card|game.shown], deck: deck}
  end

  defp shuffle_cards do
    deck = for c <- @card_colors do
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
