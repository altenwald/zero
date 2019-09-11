defmodule ZeroTest do
  use ExUnit.Case
  doctest Zero

  test "greets the world" do
    assert Zero.hello() == :world
  end
end
