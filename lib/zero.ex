defmodule Zero do
  @moduledoc """
  Documentation for Zero.
  """

  alias Zero.Game
  alias IO.ANSI

  defp ask(prompt) do
    "#{prompt}> "
    |> IO.gets()
    |> String.trim()
    |> String.downcase()
  end

  defp ask_num(prompt) do
    ask(prompt)
    |> String.to_integer()
  end

  def start(name) do
    Game.start name
    user = ask "name"
    waiting(name, user)
  end

  def waiting(name, user) do
    Game.join name, user
    case ask("deal? [Y/n]") do
      "n" ->
        waiting(name, user)
      _ ->
        Game.deal(name)
        playing(name, user)
    end
  end

  def playing(name, user) do
    case Game.get_shown(name) do
      :game_over ->
        IO.puts "GAME OVER!"
      card ->        
        IO.puts [ANSI.reset(), ANSI.clear()]
        IO.puts "Zero Game"
        IO.puts "Shown -->"
        draw_card(card)
        IO.puts "You hand -->"
        cards = Game.get_hand(name)
        draw_cards(cards)
        if Game.is_my_turn?(name) do
          case ask("[P]ass [G]et pla[Y]") do
            "p" -> Game.pass(name)
            "g" -> Game.pick_from_deck(name)
            "y" ->
              num = ask_num("card")
              color = case Map.get(cards, num) do
                {:special, _} -> to_color_atom(ask("color"))
                _ -> nil
              end
              Game.play(name, num, color)
          end
          playing(name, user)
        else
          IO.puts "waiting for your turn..."
          Process.sleep(1_000)
          playing(name, user)
        end
    end
  end

  defp to_color_atom("red"), do: :red
  defp to_color_atom("green"), do: :green
  defp to_color_atom("blue"), do: :blue
  defp to_color_atom("yellow"), do: :yellow

  defp to_color(:special), do: ANSI.black_background()
  defp to_color(:red), do: [ANSI.red_background(), ANSI.black()]
  defp to_color(:green), do: [ANSI.green_background(), ANSI.black()]
  defp to_color(:blue), do: [ANSI.blue_background(), ANSI.black()]
  defp to_color(:yellow), do: [ANSI.light_yellow_background(), ANSI.black()]

  defp to_type(n) when is_integer(n), do: " #{n} "
  defp to_type(:reverse), do: "<--"
  defp to_type(:turn), do: " X "
  defp to_type(:plus_2), do: "+ 2"
  defp to_type(:plus_4), do: "+ 4"
  defp to_type(:color_change), do: "COL"

  defp draw_card({color, type}) do
    color = to_color(color)
    type = to_type(type)
    [
      color, "+-----+", ANSI.reset(), "\n",
      color, "|     |", ANSI.reset(), "\n",
      color, "| #{type} |", ANSI.reset(), "\n",
      color, "|     |", ANSI.reset(), "\n",
      color, "+-----+", ANSI.reset(), "\n"
    ] |> IO.puts()
  end

  defp draw_cards(cards) do
    cards = for {_, {color, type}} <- cards, do: {to_color(color), to_type(type)}
    [
      for({color, _} <- cards, do: [color, "+-----+", ANSI.reset()]), "\n",
      for({color, _}  <- cards, do: [color, "|     |", ANSI.reset()]), "\n",
      for({color, type}  <- cards, do: [color, "| #{type} |", ANSI.reset()]), "\n",
      for({color, _}  <- cards, do: [color, "|     |", ANSI.reset()]), "\n",
      for({color, _}  <- cards, do: [color, "+-----+", ANSI.reset()]), "\n"
    ] |> IO.puts()
  end
end
