defmodule ProtoHackers.Utils do
  @moduledoc false

  @spec prime?(number :: integer()) :: boolean()
  def prime?(num)

  def prime?(num) when num <= 1, do: false
  def prime?(num) when num in [2, 3], do: true
  def prime?(num) when rem(num, 2) == 0 or rem(num, 3) == 0, do: false

  def prime?(num) do
    not Enum.any?(5..trunc(:math.sqrt(num))//6, fn n ->
      rem(num, n) == 0 or rem(num, n + 2) == 0
    end)
  end

  @spec id(value) :: value when value: any()
  def id(v), do: v
end