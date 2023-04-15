defmodule ProtoHackersTest do
  use ExUnit.Case
  doctest ProtoHackers

  test "greets the world" do
    assert ProtoHackers.hello() == :world
  end
end
