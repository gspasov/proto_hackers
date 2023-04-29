defmodule ProtoHackers.TcpServer do
  @moduledoc """
  General TCP Server used to handle all tasks.
  Each task is supposed to start it's own TCP server with the specified specs.
  """

  use FunServer
  use TypedStruct

  alias ProtoHackers.Utils
  alias ProtoHackers.TcpServer.Specification
  alias ProtoHackers.TcpServer.State

  require Logger

  typedstruct module: State do
    field :socket, port(), required: true
    field :task_supervisor, :atom, required: true
    field :on_receive_callback, (port(), any() -> :ok), required: true
    field :on_connect_callback, (port() -> :ok)
    field :on_close_callback, (port() -> :ok)
    field :receive_length, non_neg_integer()
  end

  def start_link(%Specification{
        tcp:
          %Specification.Tcp{
            port: tcp_port,
            options: tcp_options,
            task_supervisor: task_supervisor,
            on_receive_callback: on_receive_callback
          } = tcp_specs,
        server: %Specification.Server{options: fun_options}
      }) do
    FunServer.start_link(__MODULE__, fun_options, fn ->
      {:ok, socket} = :gen_tcp.listen(tcp_port, tcp_options)

      tcp_server_name = Keyword.get(fun_options, :name, "No name provided to server")

      Logger.debug(
        "[#{__MODULE__}] TCP for #{inspect(tcp_server_name)} listening on #{inspect(socket)}"
      )

      on_close_callback = Map.get(tcp_specs, :on_close_callback, &Utils.id/1)
      on_connect_callback = Map.get(tcp_specs, :on_connect_callback, &Utils.id/1)
      receive_length = Map.get(tcp_specs, :receive_length, 0)

      init_state = %State{
        socket: socket,
        on_receive_callback: on_receive_callback,
        on_close_callback: on_close_callback,
        on_connect_callback: on_connect_callback,
        receive_length: receive_length,
        task_supervisor: task_supervisor
      }

      Logger.debug("[#{__MODULE__}] Starting with following state #{inspect(init_state)}")

      {:ok, init_state, {:continue, &accept_connection/1}}
    end)
  end

  def tcp_send(socket, packet), do: :gen_tcp.send(socket, packet)
  def tcp_close(socket), do: :gen_tcp.close(socket)

  defp accept_connection(
         %State{
           socket: socket,
           on_receive_callback: on_receive_callback,
           on_close_callback: on_close_callback,
           on_connect_callback: on_connect_callback,
           receive_length: receive_length,
           task_supervisor: task_supervisor
         } = state
       ) do
    case :gen_tcp.accept(socket) do
      {:ok, client_connection_socket} ->
        Logger.info(
          "[#{__MODULE__}] `:gen_tcp.accept/1` established connection on #{inspect(client_connection_socket)}"
        )

        on_connect_callback.(client_connection_socket)

        Task.Supervisor.start_child(
          task_supervisor,
          __MODULE__,
          :handle_client,
          [
            %{
              socket: client_connection_socket,
              receive_length: receive_length,
              on_receive_callback: on_receive_callback,
              on_close_callback: on_close_callback
            }
          ]
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

  def handle_client(
        %{
          socket: socket,
          receive_length: receive_length,
          on_receive_callback: on_receive_callback,
          on_close_callback: on_close_callback
        } = args
      ) do
    case :gen_tcp.recv(socket, receive_length) do
      {:ok, packet} ->
        Logger.debug(
          "[#{__MODULE__}] Connection #{inspect(socket)} received packet #{inspect(packet, limit: :infinity)}"
        )

        on_receive_callback.(socket, packet)
        handle_client(args)

      {:error, :timeout} ->
        Logger.debug("[#{__MODULE__}] Connection #{inspect(socket)} timed out")

        handle_client(args)

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
