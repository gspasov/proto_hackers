defmodule ProtoHackers.MeansToAnEnd do
  use FunServer, restart: :transient

  alias ProtoHackers.MeansToAnEnd.Request
  alias ProtoHackers.TcpServer

  require Logger

  @packet_size 9

  def start_link(tcp_socket) do
    FunServer.start_link(
      __MODULE__,
      [name: {:via, Registry, {Registry.MeansToAnEnd, tcp_socket}}],
      fn -> {:ok, %{packet: <<>>, tcp_socket: tcp_socket, price_data: %{}}} end
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

    handle_packet(session_pid, packet)

    # case Request.parse(packet) do
    #   {:ok, %Request.Insert{timestamp: timestamp, price: price}} ->
    #     Logger.debug("[#{__MODULE__}] INSERT request with price #{inspect(price)}")
    #     insert(session_pid, timestamp, price)

    #   {:ok, %Request.Query{min_timestamp: min_timestamp, max_timestamp: max_timestamp}} ->
    #     Logger.debug("[#{__MODULE__}] QUERY request")
    #     average = query(session_pid, min_timestamp, max_timestamp)
    #     Logger.debug("[#{__MODULE__}] Average is #{inspect(average)}")
    #     TcpServer.tcp_send(socket, to_string(average))

    #   {:error, :invalid_request} ->
    #     Logger.warn("[#{__MODULE__}] Invalid request")
    #     TcpServer.tcp_send(socket, "bad_request")
    # end
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

  def handle_packet(session, receive_packet) do
    FunServer.async(session, fn %{packet: packet, tcp_socket: tcp_socket, price_data: price_data} =
                                  state ->
      new_state =
        case packet do
          <<>> -> {:ok, receive_packet}
          <<?I, _rest::binary>> -> {:ok, packet <> receive_packet}
          <<?Q, _rest::binary>> -> {:ok, packet <> receive_packet}
          bad_packet -> {:error, {:bad_packet, bad_packet}}
        end
        |> case do
          {:ok, <<request::binary-size(@packet_size), rest::binary>> = bin}
          when byte_size(bin) >= @packet_size ->
            new_price_data =
              case Request.parse(request) do
                {:ok, %Request.Insert{timestamp: timestamp, price: price}} ->
                  Logger.debug("[#{__MODULE__}] INSERT request with price #{inspect(price)}")
                  Map.update(price_data, timestamp, price, &id/1)

                {:ok, %Request.Query{min_timestamp: min_timestamp, max_timestamp: max_timestamp}} ->
                  Logger.debug("[#{__MODULE__}] QUERY request")

                  average =
                    price_data
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

                  Logger.debug("[#{__MODULE__}] Average is #{inspect(average)}")
                  TcpServer.tcp_send(tcp_socket, to_string(average))
                  price_data

                {:error, :invalid_request} ->
                  Logger.warn("[#{__MODULE__}] Invalid request with 'failed to parse packet'")
                  TcpServer.tcp_send(tcp_socket, "bad_request")
                  price_data
              end

            %{state | price_data: new_price_data, packet: rest}

          {:ok, new_packet} ->
            %{state | packet: new_packet}

          {:error, reason} ->
            Logger.warn("[#{__MODULE__}] Invalid request with #{inspect(reason)}")
            TcpServer.tcp_send(tcp_socket, "bad_request")

            state
        end

      {:noreply, new_state}
    end)
  end

  # def insert(session, timestamp, price) do
  #   FunServer.async(session, fn state ->
  #     new_state = Map.update(state, timestamp, price, &id/1)
  #     {:noreply, new_state}
  #   end)
  # end

  # def query(session, min_timestamp, max_timestamp) do
  #   FunServer.sync(session, fn _from, state ->
  #     average =
  #       state
  #       |> Enum.filter(fn {timestamp, _} ->
  #         timestamp >= min_timestamp and timestamp <= max_timestamp
  #       end)
  #       |> Enum.map(fn {_timestamp, price} -> price end)
  #       |> case do
  #         [] ->
  #           0

  #         prices ->
  #           prices
  #           |> Enum.sum()
  #           |> Kernel./(length(prices))
  #           |> Kernel.floor()
  #       end

  #     {:reply, average, state}
  #   end)
  # end

  @spec id(value) :: value when value: any()
  defp id(v), do: v
end
