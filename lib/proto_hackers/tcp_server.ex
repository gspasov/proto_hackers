defmodule ProtoHackers.TcpServer do
  use FunServer

  require Logger

  def start_link(%{
        tcp: %{port: tcp_port, options: tcp_options, packet_handler: packet_handler},
        server: %{options: gen_options}
      }) do
    FunServer.start_link(__MODULE__, gen_options, fn ->
      {:ok, socket} = :gen_tcp.listen(tcp_port, tcp_options)

      Logger.debug(
        "[#{__MODULE__}] starting tcp for #{inspect(Keyword.get(gen_options, :name, "No name provided to server"))} listening on #{inspect(socket)}"
      )

      state = %{socket: socket, packet_handler: packet_handler}
      {:ok, state, {:continue, &accept_connection/1}}
    end)
  end

  def tcp_send(socket, packet) do
    :gen_tcp.send(socket, packet)
  end

  defp accept_connection(%{socket: socket, packet_handler: packet_handler} = state) do
    case :gen_tcp.accept(socket) do
      {:ok, client_connection_socket} ->
        Logger.info(
          "[#{__MODULE__}] `:gen_tcp.accept/1` established connection on #{inspect(client_connection_socket)}"
        )

        Task.Supervisor.start_child(
          ProtoHackers.TaskSupervisor,
          __MODULE__,
          :handle_client,
          [client_connection_socket, packet_handler]
        )

        {:noreply, state, {:continue, &accept_connection/1}}

      {:error, :timeout} ->
        Logger.debug("[#{__MODULE__}] `:gen_tcp.accept/1` got :timeout")
        {:noreply, state, {:continue, &accept_connection/1}}

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

  def handle_client(socket, handler) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} ->
        Logger.debug(
          "[#{__MODULE__}] Connection #{inspect(socket)} received packet #{inspect(packet, limit: :infinity)}"
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
