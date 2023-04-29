defmodule ProtoHackers.BudgetChat.Bus do
  use TypedStruct

  alias ProtoHackers.BudgetChat.Bus.Message
  alias ProtoHackers.BudgetChat.MessageBuilder

  typedstruct module: Message, enforce: true do
    field :username, String.t()
    field :message, String.t()
  end

  @spec subscribe() :: :ok
  def subscribe() do
    :pg.join(name(), self())
  end

  @spec unsubscribe() :: :ok
  def unsubscribe(), do: :pg.leave(name(), self())

  @spec broadcast(message :: Message.t()) :: :ok
  def broadcast(message) do
    name()
    |> :pg.get_members()
    |> Enum.each(fn pid -> send(pid, {__MODULE__, message}) end)
  end

  @spec broadcast_join(username :: String.t()) :: :ok
  def broadcast_join(username) do
    broadcast(%Message{username: username, message: MessageBuilder.join(username)})
  end

  @spec broadcast_message(username :: String.t(), message :: String.t()) :: :ok
  def broadcast_message(username, message) do
    broadcast(%Message{username: username, message: MessageBuilder.message(username, message)})
  end

  @spec broadcast_leave(username :: String.t()) :: :ok
  def broadcast_leave(username) do
    broadcast(%Message{username: username, message: MessageBuilder.leave(username)})
  end

  defp name(), do: __MODULE__
end
