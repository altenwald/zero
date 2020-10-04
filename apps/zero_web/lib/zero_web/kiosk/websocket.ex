defmodule ZeroWeb.Kiosk.Websocket do
  require Logger

  alias ZeroGame
  alias ZeroGame.Bot
  alias ZeroWeb.Request

  @default_deck "timmy"

  @behaviour :cowboy_websocket

  @impl :cowboy_websocket
  def init(req, opts) do
    Logger.info("[websocket] init req => #{inspect(req)}")
    remote_ip = Request.remote_ip(req)
    {:cowboy_websocket, req, [{:remote_ip, remote_ip} | opts]}
  end

  @impl :cowboy_websocket
  def websocket_init(remote_ip: remote_ip) do
    vsn = ZeroWeb.Application.vsn()
    {:ok, hiscore} = Agent.start_link(fn -> %{} end)
    reply = Jason.encode!(%{"type" => "vsn", "vsn" => vsn})
    state = %{name: nil, remote_ip: remote_ip, hiscore: hiscore, deck: @default_deck}
    {:reply, {:text, reply}, state}
  end

  @doc """
  The information received by this function is sent from the browser
  directly to the websocket to be handle by the websocket. Most of the
  actions have direct impact into the game.
  """
  @impl :cowboy_websocket
  def websocket_handle({:text, msg}, state) do
    msg
    |> Jason.decode!()
    |> process_data(state)
  end

  def websocket_handle(_any, state) do
    {:reply, {:text, "eh?"}, state}
  end

  @doc """
  The information received by websocket is from "info" is sent mainly
  by the `ZeroWeb.Consumer` consumer regarding the information received
  from the Game where we did our subscription.
  """
  @impl :cowboy_websocket
  def websocket_info({:send, data}, state) do
    {:reply, {:text, data}, state}
  end

  def websocket_info({:timeout, _ref, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info({:join, player}, state) do
    update = fn value ->
      Logger.debug("player => #{inspect(player)}")
      h = Map.update(value, player, 0, & &1)
      {h, h}
    end

    hiscore = Agent.get_and_update(state.hiscore, update)
    msg = %{"type" => "join", "username" => player, "hiscore" => hiscore}
    Logger.debug("msg => #{inspect(msg)}")
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:disconnected, player}, state) do
    msg = %{"type" => "leave", "username" => player}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info(:dealt, state) do
    msg = send_update_msg("dealt", state.name, state.deck)
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:turn, _username, previous}, state) do
    msg =
      send_update_msg("turn", state.name, state.deck)
      |> Map.put("previous", previous)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:pick_from_deck, _username}, state) do
    msg = send_update_msg("pick_from_deck", state.name, state.deck)
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:game_over, winner}, state) do
    update = fn value ->
      h = Map.update(value, winner, 1, &(&1 + 1))
      {h, h}
    end

    hiscore = Agent.get_and_update(state.hiscore, update)

    msg =
      send_update_msg("game_over", state.name, state.deck)
      |> Map.put("winner", winner)
      |> Map.put("hiscore", hiscore)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:pass, player_name}, state) do
    msg =
      send_update_msg("pass", state.name, state.deck)
      |> Map.put("previous", player_name)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:plus_2, _username, previous}, state) do
    msg =
      send_update_msg("plus_2", state.name, state.deck)
      |> Map.put("previous", previous)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:plus_4, _username, previous}, state) do
    msg =
      send_update_msg("plus_4", state.name, state.deck)
      |> Map.put("previous", previous)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:lose_turn, username, previous}, state) do
    msg =
      send_update_msg("lose_turn", state.name, state.deck)
      |> Map.put("previous", previous)
      |> Map.put("skipped", username)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:change_color, _username}, state) do
    msg = send_update_msg("change_color", state.name, state.deck)
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:reverse, username}, state) do
    msg =
      send_update_msg("reverse", state.name, state.deck)
      |> Map.put("previous", username)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info(info, state) do
    Logger.info("kiosk info => #{inspect(info)}")
    {:ok, state}
  end

  defp send_update_msg(event, name, deck) do
    %{
      "type" => event,
      "shown" => get_card(ZeroGame.get_shown(name), deck),
      "shown_color" => to_string(ZeroGame.color?(name)),
      "players" => get_players(ZeroGame.players(name)),
      "turn" => ZeroGame.whose_turn_is_it?(name),
      "deck" => ZeroGame.deck_cards_num(name)
    }
  end

  defp get_card(nil, _deck), do: ["", "/img/cards/backside.png"]

  defp get_card({color, type}, deck) do
    [to_string(color), "/img/cards/#{deck}/#{color}#{type}.png"]
  end

  defp get_players(players) do
    for {name, num_cards} <- players do
      %{"username" => name, "num_cards" => num_cards}
    end
  end

  defp process_data(%{"type" => "deck", "name" => name}, state) do
    Logger.info "change deck to #{inspect(name)}"
    {:ok, %{state | deck: name}}
  end

  defp process_data(%{"type" => "ping"}, state) do
    {:reply, {:text, Jason.encode!(%{"type" => "pong"})}, state}
  end

  defp process_data(%{"type" => "create"}, state) do
    name = UUID.uuid4()
    {:ok, _game_pid} = ZeroGame.start(name)
    msg = %{"type" => "id", "id" => name}
    state = %{state | name: name}
    ZeroWeb.Application.start_consumer(name, self())
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "listen", "name" => name}, state) do
    if not ZeroGame.exists?(name) do
      {:ok, _game_pid} = ZeroGame.start(name)
    end

    state = %{state | name: name}

    players = ZeroGame.players(name)

    update = fn {player, _num_cards} ->
      Agent.update(
        state.hiscore,
        fn value ->
          Map.update(value, player, 0, & &1)
        end
      )
    end

    Enum.each(players, update)

    msg =
      if ZeroGame.is_started?(name) do
        send_update_msg("dealt", name, state.deck)
      else
        %{"type" => "id", "id" => name, "players" => players}
      end

    ZeroWeb.Application.start_consumer(name, self())
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "restart"}, state) do
    ZeroGame.restart(state.name)
    {:ok, state}
  end

  defp process_data(%{"type" => "hiscore"}, state) do
    hiscore = Agent.get(state.hiscore, & &1)
    msg = %{"type" => "hiscore", "hiscore" => hiscore}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "bot", "name" => botname}, state) do
    botname = String.trim(botname)

    if ZeroGame.valid_name?(state.name, botname) do
      Bot.start_link(state.name, botname)
    end

    {:ok, state}
  end
end
