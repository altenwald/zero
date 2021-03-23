defmodule ZeroGameTest do
  use ExUnit.Case, async: false
  doctest ZeroGame

  @game_name "19a5202a-b2fd-4d1d-a4dd-b214d0f4bc68"
  @player_one "TheBest"
  @player_two "Anothe One Bite The Dust"

  setup do
    game = ZeroGame.start(@game_name)
    pid = ZeroGame.get_event_manager_pid(@game_name)
    assert is_pid(pid)
    assert ZeroGame.exists?(@game_name)
    assert {:ok, sender} = ZeroGame.ConsumerSender.start(@game_name)
    on_exit fn ->
      Process.monitor(pid)
      Process.monitor(sender)
      ZeroGame.stop(@game_name)
      assert_receive {:DOWN, _ref, :process, ^pid, _reason}, 2_000
      assert_receive {:DOWN, _ref, :process, ^sender, _reason}, 2_000
    end
    %{game: game, sender: sender}
  end

  describe "playing solo" do
    test "trying to play solo" do
      assert :ok = ZeroGame.join(@game_name, @player_one)
      assert :ok = ZeroGame.deal(@game_name)
      refute ZeroGame.is_started?(@game_name)
      assert 1 = ZeroGame.get_players_number(@game_name)
      assert_receive {:join, "TheBest"}
      refute_receive _, 200
    end

    test "playing duo" do
      assert :ok = ZeroGame.join(@game_name, @player_one)
      assert :ok = ZeroGame.deal(@game_name)
      refute ZeroGame.is_started?(@game_name)
      assert 1 = ZeroGame.get_players_number(@game_name)
      assert_receive {:join, "TheBest"}

      second_player = spawn &playing_duo_second_player/0
      assert_receive {:join, "Anothe One Bite The Dust"}

      assert ZeroGame.is_started?(@game_name)
      assert 2 = ZeroGame.get_players_number(@game_name)

      assert_receive :dealing
      for _ <- 1..10 do
        assert_receive {:deal, "Anothe One Bite The Dust"}
        assert_receive {:deal, "TheBest"}
      end
      assert_receive :dealt

      send(second_player, :play)
      assert_receive {:cards, "Anothe One Bite The Dust", 9}
      assert_receive {:turn, "TheBest", "Anothe One Bite The Dust"}

      assert %{
        1 => {:red, 6},
        2 => {:red, 4},
        3 => {:red, 2},
        4 => {:red, 0},
        5 => {:blue, :turn},
        6 => {:blue, 9},
        7 => {:blue, 7},
        8 => {:blue, 5},
        9 => {:blue, 3},
        10 => {:blue, 1}
      } = ZeroGame.get_hand(@game_name)

      assert {:red, 1} = ZeroGame.get_shown(@game_name)
      assert {:error, :invalid_card} = ZeroGame.play(@game_name, 6)
      assert :ok = ZeroGame.play(@game_name, 3)

      assert_receive {:cards, "TheBest", 9}
      assert_receive {:turn, "Anothe One Bite The Dust", "TheBest"}

      refute_receive _, 200
      send(second_player, :stop)
    end
  end

  defp playing_duo_second_player() do
    assert :ok = ZeroGame.join(@game_name, @player_two)
    assert :ok = ZeroGame.deal(@game_name)
    assert_receive :play, 2_000
    assert %{
      1 => {:red, 5},
      2 => {:red, 3},
      3 => {:red, 1},
      4 => {:blue, :plus_2},
      5 => {:blue, :reverse},
      6 => {:blue, 8},
      7 => {:blue, 6},
      8 => {:blue, 4},
      9 => {:blue, 2},
      10 => {:blue, 0}
    } = ZeroGame.get_hand(@game_name)
    assert {:red, 7} = ZeroGame.get_shown(@game_name)
    assert {:error, :invalid_card} = ZeroGame.play(@game_name, 6)
    assert :ok = ZeroGame.play(@game_name, 3)
    assert %{
      1 => {:red, 5},
      2 => {:red, 3},
      3 => {:blue, :plus_2},
      4 => {:blue, :reverse},
      5 => {:blue, 8},
      6 => {:blue, 6},
      7 => {:blue, 4},
      8 => {:blue, 2},
      9 => {:blue, 0}
    } = ZeroGame.get_hand(@game_name)
    assert_receive :stop, 2_000
  end
end
