defmodule ZeroGameTest do
  use ExUnit.Case
  doctest ZeroGame

  test "greets the world" do
    assert ZeroGame.hello() == :world
  end
end
