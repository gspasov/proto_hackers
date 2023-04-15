defmodule Protohackers.TcpServer do
  use GenServer

  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(_) do
    {:ok, socket} = :gen_tcp.listen(4000, [:binary, {:active, false}, {:packet, 0}])
    Logger.debug("[#{__MODULE__}] listening on #{inspect(socket)}")
    {:ok, %{socket: socket, client_connections: []}, {:continue, :accept_connection}}
  end

  @impl true
  def handle_continue(
        :accept_connection,
        %{socket: socket, client_connections: client_connections} = state
      ) do
    case :gen_tcp.accept(socket) do
      {:ok, client_connection_socket} ->
        Logger.info(
          "[#{__MODULE__}] `:gen_tcp.accept/1` established connection on #{inspect(client_connection_socket)}"
        )

        Task.Supervisor.start_child(
          Protohackers.TaskSupervisor,
          __MODULE__,
          :handle_client,
          [client_connection_socket]
        )

        {:noreply, %{state | client_connections: [client_connection_socket | client_connections]},
         {:continue, :accept_connection}}

      {:error, :timeout} ->
        Logger.debug("[#{__MODULE__}] `:gen_tcp.accept/1` got :timeout")
        {:noreply, state, {:continue, :accept_connection}}

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

  def handle_client(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} ->
        Logger.debug(
          "[#{__MODULE__}] Connection #{inspect(socket)} received packet #{inspect(packet)}"
        )

        :gen_tcp.send(socket, packet) |> IO.inspect(label: "sending to #{inspect(socket)}")
        handle_client(socket)

      {:error, :timeout} ->
        Logger.debug("[#{__MODULE__}] Connection #{inspect(socket)} timed out")
        handle_client(socket)

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
