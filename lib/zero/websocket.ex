defmodule Zero.Websocket do
  require Logger
  alias Zero.{Game, EventManager}

  use GenStage

  def init([producer, game]) do
    Process.monitor game
    {:consumer, game, subscribe_to: [producer]}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, _state) do
    :stop
  end

  def handle_events(events, _from, game) do
    Logger.debug "events => #{inspect events}"
    for event <- events, do: send(game, event)
    {:noreply, [], game}
  end

  @behaviour :cowboy_websocket

  def init(req, opts) do
    Logger.info "[websocket] init req => #{inspect req}"
    remote_ip = case :cowboy_req.peer(req) do
      {{127, 0, 0, 1}, _} ->
        case :cowboy_req.header("x-forwarded-for", req) do
          {remote_ip, _} -> remote_ip
          _ -> "127.0.0.1"
        end
      {remote_ip, _} ->
        to_string(:inet.ntoa(remote_ip))
    end
    {:cowboy_websocket, req, [{:remote_ip, remote_ip}|opts]}
  end

  def websocket_init(remote_ip: remote_ip) do
    vsn = to_string(Application.spec(:zero)[:vsn])
    send self(), {:send, Jason.encode!(%{"type" => "vsn", "vsn" => vsn})}
    {:ok, %{name: nil, remote_ip: remote_ip}}
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
    msg = %{"type" => "join", "username" => player}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:disconnected, player}, state) do
    msg = %{"type" => "leave", "username" => player}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info(:dealt, %{name: name} = state) do
    msg = send_update_msg(name)
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:turn, _username}, %{name: name} = state) do
    msg = send_update_msg(name)
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:pick_from_deck, _username}, %{name: name} = state) do
    msg = send_update_msg(name)
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:game_over, winner}, state) do
    msg = %{"type" => "gameover", "winner" => winner}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info(info, state) do
    Logger.info "info => #{inspect info}"
    {:ok, state}
  end

  def websocket_terminate(reason, _state) do
    Logger.info "reason => #{inspect reason}"
    :ok
  end

  defp send_update_msg(name) do
    %{"type" => "dealt",
      "hand" => get_cards(Game.get_hand(name)),
      "shown" => get_card(Game.get_shown(name)),
      "shown_color" => to_string(Game.color?(name)),
      "players" => get_players(Game.players(name)),
      "turn" => Game.whose_turn_is_it?(name),
      "deck" => Game.deck_cards_num(name)}
  end

  defp get_card({color, type}) do
    [to_string(color), "/img/cards/#{color}#{type}.png"]
  end
  defp get_cards(cards) do
    for {_k, card} <- cards do
      get_card(card)
    end
  end

  defp get_players(players) do
    for {name, num_cards} <- players do
      %{"username" => name, "num_cards" => num_cards}
    end
  end

  defp process_data(%{"type" => "create"}, state) do
    name = UUID.uuid4()
    {:ok, _game_pid} = Game.start(name)
    msg = %{"type" => "id", "id" => name}
    state = %{state | name: name}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end
  defp process_data(%{"type" => "join",
                      "name" => name,
                      "username" => username}, state) do
    if Game.exists?(name) do
      pid = EventManager.get_pid(name)
      username = String.trim(username)
      # FIXME: put this process under supervision tree, registry or some way
      #        to ensure it's not added again and again.
      GenStage.start_link __MODULE__, [pid, self()]
      for {player, _} <- Game.players(name), player != username do
        send self(), {:join, player}
      end
      Game.join(name, username)
      {:ok, %{state | name: name}}
    else
      Logger.warn "doesn't exist #{inspect name}"
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end  
  end
  defp process_data(%{"type" => "deal"}, %{name: name} = state) do
    Game.deal(name)
    {:ok, state}
  end
  defp process_data(%{"type" => "play", "card" => card, "color" => color}, state) do
    color = case color do
      "red" -> :red
      "blue" -> :blue
      "yellow" -> :yellow
      "green" -> :green
    end
    Game.play(state.name, card, color)
    {:ok, state}
  end
  defp process_data(%{"type" => "pick-from-deck"}, state) do
    Game.pick_from_deck(state.name)
    {:ok, state}
  end
  defp process_data(%{"type" => "pass"}, state) do
    Game.pass(state.name)
    {:ok, state}
  end
  defp process_data(%{"type" => "restart"}, state) do
    Game.restart(state.name)
    {:ok, state}
  end
end
