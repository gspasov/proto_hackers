defmodule ProtoHackers.MeansToAnEnd do
  use FunServer, restart: :transient

  alias ProtoHackers.MeansToAnEnd.Request
  alias ProtoHackers.TcpServer

  require Logger

  def start_link(name) do
    FunServer.start_link(
      __MODULE__,
      [name: {:via, Registry, {Registry.MeansToAnEnd, name}}],
      fn -> {:ok, %{}} end
    )
  end

  def on_receive_callback(socket, packet) do
    session_pid =
      case Registry.lookup(Registry.MeansToAnEnd, socket) do
        [] ->
          {:ok, pid} =
            DynamicSupervisor.start_child(ProtoHackers.DynamicSupervisor, {__MODULE__, socket})

          pid

        [{pid, _}] ->
          pid
      end

    case Request.parse(packet) do
      {:ok, %Request.Insert{timestamp: timestamp, price: price}} ->
        Logger.debug("[#{__MODULE__}] INSERT request with price #{inspect(price)}")
        insert(session_pid, timestamp, price)

      {:ok, %Request.Query{min_timestamp: min_timestamp, max_timestamp: max_timestamp}} ->
        Logger.debug("[#{__MODULE__}] QUERY request")
        average = query(session_pid, min_timestamp, max_timestamp)
        Logger.debug("[#{__MODULE__}] Average is #{inspect(average)}")
        TcpServer.tcp_send(socket, to_string(average))

      {:error, :invalid_request} ->
        Logger.warn("[#{__MODULE__}] Invalid request")
        TcpServer.tcp_send(socket, "bad_request")
    end
  end

  def on_close_callback(socket) do
    case Registry.lookup(Registry.MeansToAnEnd, socket) do
      [] ->
        Logger.error("[#{__MODULE__}] Unable to find FunServer for socket #{inspect(socket)}")

      [{pid, _}] ->
        Logger.debug(
          "[#{__MODULE__}] Stopping FunServer #{inspect(pid)} for socket #{inspect(socket)}"
        )

        FunServer.stop(pid)
    end
  end

  def insert(session, timestamp, price) do
    FunServer.async(session, fn state ->
      new_state = Map.update(state, timestamp, price, &id/1)
      {:noreply, new_state}
    end)
  end

  def query(session, min_timestamp, max_timestamp) do
    FunServer.sync(session, fn _from, state ->
      average =
        state
        |> Enum.filter(fn {timestamp, _} ->
          timestamp >= min_timestamp and timestamp <= max_timestamp
        end)
        |> Enum.map(fn {_timestamp, price} -> price end)
        |> case do
          [] ->
            0

          prices ->
            prices
            |> Enum.sum()
            |> Kernel./(length(prices))
            |> Kernel.floor()
        end

      {:reply, average, state}
    end)
  end

  @spec id(value) :: value when value: any()
  defp id(v), do: v
end
