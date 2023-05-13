defmodule ProtoHackers.SpeedDaemon.OverWatch.Bus do
  alias ProtoHackers.SpeedDaemon.OverWatch.Snapshot
  alias ProtoHackers.SpeedDaemon.Request.IAmDispatcher
  alias ProtoHackers.SpeedDaemon.Request.IAmCamera
  alias ProtoHackers.SimpleBus

  @behaviour SimpleBus

  @impl true
  def subscribe() do
    :pg.join(name(), self())
  end

  @impl true
  def unsubscribe(), do: :pg.leave(name(), self())

  @impl true
  def broadcast(message) do
    name()
    |> :pg.get_members()
    |> Enum.each(fn pid -> send(pid, {__MODULE__, message}) end)
  end

  @spec broadcast_dispatcher(client :: pid(), IAmDispatcher.t()) :: :ok
  def broadcast_dispatcher(client, %IAmDispatcher{} = dispatcher) do
    broadcast({:add, client, dispatcher})
  end

  @spec broadcast_snapshot(Snapshot.t()) :: :ok
  def broadcast_snapshot(%Snapshot{} = snapshot) do
    broadcast(snapshot)
  end

  @spec broadcast_dispatcher_remove(client :: pid(), IAmDispatcher.t()) :: :ok
  def broadcast_dispatcher_remove(client, %IAmDispatcher{} = dispatcher) do
    broadcast({:remove, client, dispatcher})
  end

  defp name(), do: __MODULE__
end
