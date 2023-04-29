defmodule ProtoHackers.MeansToAnEnd do
  @moduledoc false

  use FunServer, restart: :transient

  alias ProtoHackers.MeansToAnEnd.Request
  alias ProtoHackers.TcpServer
  alias ProtoHackers.Utils

  require Logger

  @packet_size 9
  @request_types ["Q", "I"]

  def start_link(tcp_socket) do
    FunServer.start_link(
      __MODULE__,
      [name: {:via, Registry, {Registry.MeansToAnEnd, tcp_socket}}],
      fn -> {:ok, %{packet: <<>>, tcp_socket: tcp_socket, price_data: %{}}} end
    )
  end

  def on_receive_callback(socket, packet) do
    session_pid =
      case maybe_session_pid(socket) do
        nil ->
          {:ok, pid} =
            DynamicSupervisor.start_child(DynamicSupervisor.MeansToAnEnd, {__MODULE__, socket})

          pid

        {:ok, pid} ->
          pid
      end

    handle_packet(session_pid, packet)
  end

  def on_close_callback(socket) do
    case maybe_session_pid(socket) do
      nil ->
        Logger.error("[#{__MODULE__}] Unable to find FunServer for socket #{inspect(socket)}")

      {:ok, pid} ->
        Logger.debug(
          "[#{__MODULE__}] Stopping FunServer #{inspect(pid)} for socket #{inspect(socket)}"
        )

        FunServer.stop(pid)
    end
  end

  def handle_packet(session, receive_packet) do
    FunServer.async(session, fn %{packet: packet} = state ->
      Logger.debug("[#{__MODULE__}] Received packet #{inspect(receive_packet)}")

      rest_packet = do_handle_packet(packet <> receive_packet, session)
      Logger.debug("[#{__MODULE__}] Rest packet #{inspect(rest_packet)})")
      {:noreply, %{state | packet: rest_packet}}
    end)
  end

  def handle_request(
        %Request.Insert{timestamp: timestamp, price: price} = request,
        session
      ) do
    Logger.debug("[#{__MODULE__}] Handling INSERT #{inspect(request)}")

    FunServer.async(session, fn state ->
      new_state = Map.update(state, timestamp, price, &Utils.id/1)
      {:noreply, new_state}
    end)
  end

  def handle_request(
        %Request.Query{max_timestamp: max_timestamp, min_timestamp: min_timestamp} = request,
        session
      ) do
    Logger.debug("[#{__MODULE__}] Handling QUERY #{inspect(request)}")

    FunServer.async(session, fn %{tcp_socket: tcp_socket} = state ->
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

      Logger.debug("[#{__MODULE__}] Response for QUERY #{inspect(average)}")
      TcpServer.tcp_send(tcp_socket, <<average::big-signed-integer-32>>)

      {:noreply, state}
    end)
  end

  defp do_handle_packet(packet, _session) when byte_size(packet) < 9 do
    packet
  end

  defp do_handle_packet(<<type::binary-1, rest::binary>>, session)
       when type not in @request_types do
    Logger.warn("[#{__MODULE__}] Bad type #{inspect(type)}, moving forward..")
    do_handle_packet(rest, session)
  end

  defp do_handle_packet(<<request::binary-@packet_size, rest::binary>>, session) do
    request
    |> Request.parse()
    |> handle_request(session)

    do_handle_packet(rest, session)
  end

  defp maybe_session_pid(socket) do
    case Registry.lookup(Registry.MeansToAnEnd, socket) do
      [] -> nil
      [{pid, _}] -> {:ok, pid}
    end
  end
end
