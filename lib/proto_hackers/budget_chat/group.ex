defmodule ProtoHackers.BudgetChat.Group do
  use FunServer

  def start_link(_args) do
    FunServer.start_link(__MODULE__, [name: __MODULE__], fn -> {:ok, []} end)
  end

  @spec get_users() :: [String.t()]
  def get_users do
    FunServer.sync(__MODULE__, fn _from, state -> {:reply, state, state} end)
  end

  @spec join(username :: String.t()) :: :ok
  def join(username) do
    FunServer.async(__MODULE__, fn state -> {:noreply, state ++ [username]} end)
  end

  @spec leave(username :: String.t()) :: :ok
  def leave(username) do
    FunServer.async(__MODULE__, fn state -> {:noreply, state -- [username]} end)
  end
end
