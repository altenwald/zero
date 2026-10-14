defmodule ZeroWeb.WebsocketTest do
  # Real server (Bandit) and real WebSocket connections: the whole path from the browser to the game.
  use ExUnit.Case, async: false

  defmodule Client do
    use WebSockex

    def start(path, parent) do
      WebSockex.start("ws://127.0.0.1:4115#{path}", __MODULE__, parent)
    end

    def push(pid, map), do: WebSockex.send_frame(pid, {:text, Jason.encode!(map)})

    @impl WebSockex
    def handle_frame({:text, text}, parent) do
      send(parent, {:frame, self(), Jason.decode(text)})
      {:ok, parent}
    end
  end

  defp connect(path) do
    {:ok, pid} = Client.start(path, self())
    # the first message of every connection is the version of the server
    assert {"vsn", %{"vsn" => vsn}} = receive_frame(pid)
    assert vsn == ZeroWeb.Application.vsn()
    pid
  end

  defp receive_frame(pid, timeout \\ 2_000) do
    receive do
      {:frame, ^pid, {:ok, %{"type" => type} = msg}} -> {type, msg}
      {:frame, ^pid, {:ok, other}} -> {:other, other}
      {:frame, ^pid, {:error, _}} -> {:invalid, nil}
    after
      timeout -> flunk("no message received")
    end
  end

  test "a player answers ping and creates a game" do
    player = connect("/websession")

    Client.push(player, %{"type" => "ping"})
    assert {"pong", _} = receive_frame(player)

    Client.push(player, %{"type" => "create"})
    assert {"id", %{"id" => id}} = receive_frame(player)
    assert ZeroGame.exists?(id)
  end

  test "a player joining an unknown game is told it was not found" do
    player = connect("/websession")
    Client.push(player, %{"type" => "join", "name" => "does-not-exist", "username" => "ana"})
    assert {"notfound", %{"error" => true}} = receive_frame(player)
  end

  test "messages that are not JSON are answered without crashing the connection" do
    player = connect("/websession")
    WebSockex.send_frame(player, {:text, "not json"})
    # the answer is the plain text "eh?", which is not JSON
    assert {:invalid, nil} = receive_frame(player)
    Client.push(player, %{"type" => "ping"})
    assert {"pong", _} = receive_frame(player)
  end

  test "the kiosk sees the players that join a game" do
    kiosk = connect("/kiosksession")
    Client.push(kiosk, %{"type" => "create"})
    assert {"id", %{"id" => id}} = receive_frame(kiosk)

    player = connect("/websession")
    Client.push(player, %{"type" => "join", "name" => id, "username" => "ana"})

    assert {"join", %{"username" => "ana"}} = receive_frame(kiosk)
  end

  test "the kiosk can listen to an existing game and read the hiscore" do
    kiosk = connect("/kiosksession")
    Client.push(kiosk, %{"type" => "listen", "name" => "table-#{System.unique_integer([:positive])}"})
    assert {"id", %{"players" => []}} = receive_frame(kiosk)

    Client.push(kiosk, %{"type" => "hiscore"})
    assert {"hiscore", %{"hiscore" => %{}}} = receive_frame(kiosk)
  end
end
