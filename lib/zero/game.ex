defmodule Zero.Game do
  use GenServer

  @card_colors [:blue, :red, :yellow, :green]
  @card_types [1, 2, 3, 4, 5, 6, 7, 8, 9, :change, :turn, :plus_2, :plus_4_and_change]

  @inital_cards 5

  alias Zero.Game

  def start_link do
    GenServer.start_link __MODULE__, [], name: __MODULE__
  end

  def add_gamer do
    GenServer.cast __MODULE__, {:add, self()}
  end

  def deal do
    GenServer.cast __MODULE__, :deal
  end

  defstruct players: [],
            deck: [],
            shown: []

  def init([]) do
    {:ok, %Game{deck: shuffle_cards()}}
  end

  def handle_cast({:add, player}, game) do
    {:noreply, %Game{game | players: [{player, []}|game.players]}}
  end

  def handle_cast(:deal, game) do
    times = @inital_cards * length(game.players)
    game = List.foldl(Enum.to_list(1..times), game,
                      fn(_, game) ->
                        game
                        |> pick_card()
                        |> next_player()
                      end)
    {:noreply, game}
  end

  defp next_player(%Game{players: [player|players]} = game) do
    %Game{game | players: players ++ [player]}
  end

  defp pick_card(%Game{players: [{player, cards}|players],
                       deck: [new_card|deck]} = game) do
    %Game{game | players: [{player, [new_card|cards]}|players],
                 deck: deck}
  end

  defp shuffle_cards do
    for c <- @card_colors do
      for t <- @card_types do
        {c, t}
      end
    end
    |> List.flatten()
    |> Enum.shuffle()
  end
end
