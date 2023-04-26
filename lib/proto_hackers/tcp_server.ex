defmodule ProtoHackers.TcpServer do
  use FunServer

  require Logger

  def start_link(%{
        tcp:
          %{
            port: tcp_port,
            options: tcp_options,
            on_receive_callback: on_receive_callback
          } = tcp_specs,
        server: %{options: gen_options}
      }) do
    FunServer.start_link(__MODULE__, gen_options, fn ->
      {:ok, socket} = :gen_tcp.listen(tcp_port, tcp_options)

      Logger.debug(
        "[#{__MODULE__}] starting tcp for #{inspect(Keyword.get(gen_options, :name, "No name provided to server"))} listening on #{inspect(socket)}"
      )

      on_close_callback = Map.get(tcp_specs, :on_close_callback, fn v -> v end)
      recv_length = Map.get(tcp_specs, :recv_length, 0)

      state = %{
        socket: socket,
        on_receive_callback: on_receive_callback,
        on_close_callback: on_close_callback,
        recv_length: recv_length
      }

      {:ok, state, {:continue, &accept_connection/1}}
    end)
  end

  def tcp_send(socket, packet) do
    tcp_send_response = :gen_tcp.send(socket, packet)
    Logger.debug("[#{__MODULE__}] TCP response to send: #{inspect(tcp_send_response)}")
  end

  defp accept_connection(
         %{
           socket: socket,
           on_receive_callback: on_receive_callback,
           on_close_callback: on_close_callback,
           recv_length: recv_length
         } = state
       ) do
    case :gen_tcp.accept(socket) do
      {:ok, client_connection_socket} ->
        Logger.info(
          "[#{__MODULE__}] `:gen_tcp.accept/1` established connection on #{inspect(client_connection_socket)}"
        )

        Task.Supervisor.start_child(
          ProtoHackers.TaskSupervisor,
          __MODULE__,
          :handle_client,
          [client_connection_socket, recv_length, on_receive_callback, on_close_callback]
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

  def handle_client(socket, recv_length, on_receive_callback, on_close_callback) do
    case :gen_tcp.recv(socket, recv_length) do
      {:ok, packet} ->
        Logger.debug(
          "[#{__MODULE__}] Connection #{inspect(socket)} received packet #{inspect(packet, limit: :infinity)}"
        )

        on_receive_callback.(socket, packet)
        handle_client(socket, recv_length, on_receive_callback, on_close_callback)

      {:error, :timeout} ->
        Logger.debug("[#{__MODULE__}] Connection #{inspect(socket)} timed out")
        handle_client(socket, recv_length, on_receive_callback, on_close_callback)

      {:error, :closed} ->
        Logger.warn("[#{__MODULE__}] Connection #{inspect(socket)} was closed normally")

        :gen_tcp.close(socket)
        on_close_callback.(socket)

      {:error, reason} ->
        Logger.error(
          "[#{__MODULE__}] Connection #{inspect(socket)} failed with #{inspect(reason)}"
        )

        :gen_tcp.close(socket)
        on_close_callback.(socket)
    end
  end
end
