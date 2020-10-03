defmodule ZeroWeb.Kiosk.Websocket do
  require Logger
  alias ZeroGame
  alias ZeroGame.{EventManager, Bot}
  alias ZeroWeb.Request

  @behaviour :cowboy_websocket

  @event_listen ZeroWeb.Kiosk.Event

  def init(req, opts) do
    Logger.info("[websocket] init req => #{inspect(req)}")
    remote_ip = Request.remote_ip(req)
    {:cowboy_websocket, req, [{:remote_ip, remote_ip} | opts]}
  end

  def websocket_init(remote_ip: remote_ip) do
    vsn = ZeroWeb.Application.vsn()
    send(self(), {:send, Jason.encode!(%{"type" => "vsn", "vsn" => vsn})})
    {:ok, hiscore} = Agent.start_link(fn -> %{} end)
    {:ok, %{name: nil, remote_ip: remote_ip, hiscore: hiscore}}
  end

  def websocket_handle({:text, msg}, state) do
    msg
    |> Jason.decode!()
    |> process_data(state)
  end

  def websocket_handle(_any, state) do
    {:reply, {:text, "eh?"}, state}
  end

  def websocket_info({:send, data}, state) do
    {:reply, {:text, data}, state}
  end

  def websocket_info({:timeout, _ref, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info({:join, player}, state) do
    update = fn value ->
      h = Map.update(value, player, 0, & &1)
      {h, h}
    end

    hiscore = Agent.get_and_update(state.hiscore, update)

    msg =
      %{"type" => "join", "username" => player}
      |> Map.put("hiscore", hiscore)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:disconnected, player}, state) do
    msg = %{"type" => "leave", "username" => player}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info(:dealt, state) do
    msg = send_update_msg("dealt", state.name)
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:turn, _username, previous}, state) do
    msg =
      send_update_msg("turn", state.name)
      |> Map.put("previous", previous)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:pick_from_deck, _username}, state) do
    msg = send_update_msg("pick_from_deck", state.name)
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:game_over, winner}, state) do
    update = fn value ->
      h = Map.update(value, winner, 1, &(&1 + 1))
      {h, h}
    end

    hiscore = Agent.get_and_update(state.hiscore, update)

    msg =
      send_update_msg("game_over", state.name)
      |> Map.put("winner", winner)
      |> Map.put("hiscore", hiscore)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:pass, player_name}, state) do
    msg =
      send_update_msg("pass", state.name)
      |> Map.put("previous", player_name)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:plus_2, _username, previous}, state) do
    msg =
      send_update_msg("plus_2", state.name)
      |> Map.put("previous", previous)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:plus_4, _username, previous}, state) do
    msg =
      send_update_msg("plus_4", state.name)
      |> Map.put("previous", previous)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:lose_turn, username, previous}, state) do
    msg =
      send_update_msg("lose_turn", state.name)
      |> Map.put("previous", previous)
      |> Map.put("skipped", username)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:change_color, _username}, state) do
    msg = send_update_msg("change_color", state.name)
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:reverse, username}, state) do
    msg =
      send_update_msg("reverse", state.name)
      |> Map.put("previous", username)

    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info(info, state) do
    Logger.info("kiosk info => #{inspect(info)}")
    {:ok, state}
  end

  def websocket_terminate(reason, _state) do
    Logger.info("kiosk reason => #{inspect(reason)}")
    :ok
  end

  defp send_update_msg(event, name) do
    %{
      "type" => event,
      "shown" => get_card(ZeroGame.get_shown(name)),
      "shown_color" => to_string(ZeroGame.color?(name)),
      "players" => get_players(ZeroGame.players(name)),
      "turn" => ZeroGame.whose_turn_is_it?(name),
      "deck" => ZeroGame.deck_cards_num(name)
    }
  end

  defp get_card(nil), do: ["", "/img/cards/backside.png"]

  defp get_card({color, type}) do
    [to_string(color), "/img/cards/#{color}#{type}.png"]
  end

  defp get_players(players) do
    for {name, num_cards} <- players do
      %{"username" => name, "num_cards" => num_cards}
    end
  end

  defp process_data(%{"type" => "ping"}, state) do
    {:reply, {:text, Jason.encode!(%{"type" => "pong"})}, state}
  end

  defp process_data(%{"type" => "create"}, state) do
    name = UUID.uuid4()
    {:ok, _game_pid} = ZeroGame.start(name)
    msg = %{"type" => "id", "id" => name}
    state = %{state | name: name}
    pid = EventManager.get_pid(name)
    GenStage.start_link(@event_listen, [pid, self()])
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "listen", "name" => name}, state) do
    if not ZeroGame.exists?(name) do
      {:ok, _game_pid} = ZeroGame.start(name)
    end

    state = %{state | name: name}
    pid = EventManager.get_pid(name)

    msg =
      if ZeroGame.is_started?(name) do
        send_update_msg("dealt", name)
      else
        players = get_players(ZeroGame.players(name))

        update = fn player ->
          Agent.update(
            state.hiscore,
            fn value ->
              Map.update(value, player, 0, & &1)
            end
          )
        end

        Enum.each(players, update)

        %{"type" => "id", "id" => name}
        |> Map.put("players", players)
      end

    GenStage.start_link(@event_listen, [pid, self()])
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "restart"}, state) do
    ZeroGame.restart(state.name)
    {:ok, state}
  end

  defp process_data(%{"type" => "bot", "name" => botname}, state) do
    botname = String.trim(botname)

    if ZeroGame.valid_name?(state.name, botname) do
      Bot.start_link(state.name, botname)
    end

    {:ok, state}
  end
end
