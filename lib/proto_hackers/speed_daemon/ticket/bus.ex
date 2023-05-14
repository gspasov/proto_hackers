defmodule ProtoHackers.SpeedDaemon.Ticket.Bus do
  @moduledoc false

  alias ProtoHackers.NamedBus
  alias ProtoHackers.SpeedDaemon.Request.Ticket

  @behaviour NamedBus

  @impl true
  def subscribe(client) do
    :pg.join(name(client), self())
  end

  @impl true
  def unsubscribe(client), do: :pg.leave(name(client), self())

  @impl true
  def broadcast(client, message) do
    name(client)
    |> :pg.get_members()
    |> Enum.each(fn pid -> send(pid, {__MODULE__, message}) end)
  end

  @spec broadcast_ticket(client :: pid(), ticket :: Ticket.t()) :: :ok
  def broadcast_ticket(client, %Ticket{} = ticket) do
    broadcast(client, ticket)
  end

  defp name(client), do: {__MODULE__, client}
end
