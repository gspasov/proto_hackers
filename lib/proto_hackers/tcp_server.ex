defmodule ProtoHackers.TcpServer do
  use FunServer

  require Logger

  def start_link(%{
        tcp: %{port: tcp_port, options: tcp_options, packet_handler: packet_handler},
        server: %{options: gen_options}
      }) do
    FunServer.start_link(__MODULE__, gen_options, fn ->
      {:ok, socket} = :gen_tcp.listen(tcp_port, tcp_options)
      Logger.debug("[#{__MODULE__}] listening on #{inspect(socket)}")
      state = %{socket: socket, client_connections: []}
      {:ok, state, {:continue, accept_connection(packet_handler)}}
    end)
  end

  def accept_connection(packet_handler) do
    fn %{socket: socket, client_connections: client_connections} = state ->
      case :gen_tcp.accept(socket) do
        {:ok, client_connection_socket} ->
          Logger.info(
            "[#{__MODULE__}] `:gen_tcp.accept/1` established connection on #{inspect(client_connection_socket)}"
          )

          Task.Supervisor.start_child(ProtoHackers.TaskSupervisor, fn ->
            handle_client(client_connection_socket, packet_handler)
          end)

          new_state = %{
            state
            | client_connections: [client_connection_socket | client_connections]
          }

          {:noreply, new_state, {:continue, accept_connection(packet_handler)}}

        {:error, :timeout} ->
          Logger.debug("[#{__MODULE__}] `:gen_tcp.accept/1` got :timeout")
          {:noreply, state, {:continue, accept_connection(packet_handler)}}

        {:error, :closed} ->
          Logger.warn("[#{__MODULE__}] `:gen_tcp.accept/1` was closed normally")
          :gen_tcp.close(socket)
          {:noreply, state}

        {:error, reason} ->
          Logger.error("[#{__MODULE__}] `:gen_tcp.accept/1` failed with #{inspect(reason)}")
          :gen_tcp.close(socket)
          {:noreply, state}
      end
    end
  end

  def handle_client(socket, handler) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} ->
        Logger.debug(
          "[#{__MODULE__}] Connection #{inspect(socket)} received packet #{inspect(packet)}"
        )

        handler.(socket, packet)
        handle_client(socket, handler)

      {:error, :timeout} ->
        Logger.debug("[#{__MODULE__}] Connection #{inspect(socket)} timed out")
        handle_client(socket, handler)

      {:error, :closed} ->
        Logger.warn("[#{__MODULE__}] Connection #{inspect(socket)} was closed normally")

        :gen_tcp.close(socket)

      {:error, reason} ->
        Logger.error(
          "[#{__MODULE__}] Connection #{inspect(socket)} failed with #{inspect(reason)}"
        )

        :gen_tcp.close(socket)
    end
  end
end
