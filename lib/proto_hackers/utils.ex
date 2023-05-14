defmodule ProtoHackers.Utils do
  @moduledoc false
  alias WarmFuzzyThing.Maybe

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

  @spec maybe_session_pid(socket :: :gen_tcp.socket(), registry :: atom()) :: {:ok, pid()} | nil
  def maybe_session_pid(socket, registry) do
    case Registry.lookup(registry, socket) do
      [] -> nil
      [{pid, _}] -> {:ok, pid}
    end
  end

  @spec maybe_hd([elem]) :: Maybe.pure(elem) when elem: any()
  def maybe_hd(list)

  def maybe_hd([]), do: nil
  def maybe_hd([{:ok, elem} | _]), do: maybe_hd([elem])
  def maybe_hd([elem | _]), do: Maybe.pure(elem)
end
