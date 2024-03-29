defmodule ZeroConsole do
  @moduledoc """
  Documentation for Zero.
  """
  use GenStage

  alias IO.ANSI

  defp ask(prompt) do
    "#{prompt}> "
    |> IO.gets()
    |> String.trim()
    |> String.downcase()
  end

  defp ask_num(prompt) do
    try do
      ask(prompt)
      |> String.to_integer()
    rescue
      _ in ArgumentError -> ask_num(prompt)
    end
  end

  @doc """
  Performs the start of the game using the current module as key.
  """
  def start do
    __MODULE__
    |> to_string()
    |> start()
  end

  @doc """
  Starts a game given the game ID as the only one paramter.
  """
  def start(name) do
    ZeroGame.start(name)
    pid = ZeroGame.get_event_manager_pid(name)
    GenStage.start_link(__MODULE__, [pid, self()])
    user = ask("name")
    waiting(name, user)
  end

  @impl GenStage
  @doc false
  def init([producer, game]) do
    {:consumer, game, subscribe_to: [producer]}
  end

  @impl GenStage
  @doc false
  def handle_events(events, _from, game) do
    for event <- events do
      case event do
        {:join, name} ->
          IO.puts("event: join #{name}")

        {:game_over, winner} ->
          IO.puts("\nG A M E   O V E R\n\n#{winner} WINS!!!")
          send(game, event)

        _ ->
          send(game, event)
      end
    end

    {:noreply, [], game}
  end

  defp waiting(name, user) do
    ZeroGame.join(name, user)
    IO.puts("Note that 'deal' should be made when everyone is onboarding.")

    case ask("ready, join again or add boot? [R/j/b]") do
      "j" ->
        waiting(name, user)

      "b" ->
        botname = ask("bot name")
        ZeroGame.start_bot(name, botname)
        waiting(name, user)

      _ ->
        ZeroGame.deal(name)
        waiting_until_ready(name, user)
    end
  end

  defp waiting_until_ready(name, user) do
    IO.puts("waiting until all of the players are online...")
    receive do
      :dealt -> playing(name, user)
    end
  end

  @doc """
  Plays as the player given by the first parameter, for the game based
  on the current module name.
  """
  def playing(user) do
    __MODULE__
    |> to_string()
    |> playing(user)
  end

  @doc """
  Plays as the player given by the second parameter, for the game based
  on the name provided as the first parameter.
  """
  def playing(name, user) do
    card = ZeroGame.get_shown(name)
    IO.puts([ANSI.reset(), ANSI.clear()])
    IO.puts("Zero Game - #{vsn()}")
    IO.puts("--------------------")
    draw_players(ZeroGame.players(name))

    IO.puts([
      "\nShown --> (color: ",
      print_color(ZeroGame.color?(name)),
      ")",
      "\nIn deck: #{ZeroGame.deck_cards_num(name)}\n"
    ])

    draw_card(card)
    IO.puts("Your hand -->")
    cards = ZeroGame.get_hand(name)
    draw_cards(cards)

    if ZeroGame.is_my_turn?(name) do
      choose_option(name, user, cards)
    else
      IO.puts("waiting for your turn...")
      wait_for_turn(name, user)
    end
  end

  defp print_color(color), do: [to_color(color), to_string(color), ANSI.reset()]

  defp choose_option(name, user, cards) do
    case ask("[P]ass [G]et pla[Y] [Q]uit") do
      "p" ->
        ZeroGame.pass(name)
        playing(name, user)

      "g" ->
        ZeroGame.pick_from_deck(name)
        playing(name, user)

      "y" ->
        num = ask_num("card")

        color =
          case Map.get(cards, num) do
            {:special, _} -> get_color()
            _ -> nil
          end

        ZeroGame.play(name, num, color)
        playing(name, user)

      "q" ->
        :ok

      _ ->
        choose_option(name, user, cards)
    end
  end

  defp wait_for_turn(name, user) do
    receive do
      {:turn, _whatever_user, _previous_one} ->
        playing(name, user)

      {:game_over, _} ->
        :ok

      other ->
        IO.puts("event: #{inspect(other)}")
        wait_for_turn(name, user)
    end
  end

  @doc """
  Get the version for the console application.
  """
  def vsn do
    to_string(Application.spec(:zero_console)[:vsn])
  end

  defp get_color do
    case ask("color: [R]ed [G]reen [B]lue [Y]ellow") do
      "r" -> :red
      "g" -> :green
      "b" -> :blue
      "y" -> :yellow
      _ -> get_color()
    end
  end

  defp to_color(:special), do: [ANSI.black_background(), ANSI.white()]
  defp to_color(:red), do: [ANSI.red_background(), ANSI.black()]
  defp to_color(:green), do: [ANSI.green_background(), ANSI.black()]
  defp to_color(:blue), do: [ANSI.blue_background(), ANSI.white()]
  defp to_color(:yellow), do: [ANSI.light_yellow_background(), ANSI.black()]

  defp to_type(n) when is_integer(n), do: " #{n} "
  defp to_type(:reverse), do: "<--"
  defp to_type(:turn), do: " X "
  defp to_type(:plus_2), do: "+ 2"
  defp to_type(:plus_4), do: "+ 4"
  defp to_type(:color_change), do: "COL"

  defp draw_players(players) do
    [
      "+----------------------+-----+---------+\n",
      for {name, cards_num, status} <- players do
        [
          "| ",
          name
          |> String.slice(0..19)
          |> String.pad_trailing(20),
          " | ",
          cards_num
          |> to_string()
          |> String.pad_leading(3),
          " | ",
          status
          |> to_string()
          |> String.pad_trailing(7),
          " |\n"
        ]
      end,
      "+----------------------+-----+---------+"
    ]
    |> IO.puts()
  end

  defp draw_card({color, type}) do
    color = to_color(color)
    type = to_type(type)

    [
      color,
      "+-----+",
      ANSI.reset(),
      "\n",
      color,
      "|     |",
      ANSI.reset(),
      "\n",
      color,
      "| #{type} |",
      ANSI.reset(),
      "\n",
      color,
      "|     |",
      ANSI.reset(),
      "\n",
      color,
      "+-----+",
      ANSI.reset(),
      "\n"
    ]
    |> IO.puts()
  end

  defp draw_cards(cards) do
    cards = for {i, {color, type}} <- cards, do: {i, to_color(color), to_type(type)}

    [
      for({i, _color, _} <- cards, do: ["  #{pad(i)}   "]),
      "\n",
      for({_i, color, _} <- cards, do: [color, "+-----+", ANSI.reset()]),
      "\n",
      for({_i, color, _} <- cards, do: [color, "|     |", ANSI.reset()]),
      "\n",
      for({_i, color, type} <- cards, do: [color, "| #{type} |", ANSI.reset()]),
      "\n",
      for({_i, color, _} <- cards, do: [color, "|     |", ANSI.reset()]),
      "\n",
      for({_i, color, _} <- cards, do: [color, "+-----+", ANSI.reset()]),
      "\n"
    ]
    |> IO.puts()
  end

  defp pad(i) when i > 10, do: to_string(i)
  defp pad(i), do: " #{i}"
end
