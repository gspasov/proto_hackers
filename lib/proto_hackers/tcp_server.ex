defmodule ProtoHackers.TcpServer do
  @moduledoc """
  General TCP Server used to handle all tasks.
  Each task is supposed to start it's own TCP server with the specified specs.
  """

  use FunServer
  use TypedStruct

  alias ProtoHackers.TcpServer.Specification
  alias ProtoHackers.TcpServer.State

  require Logger

  typedstruct module: State, required: true do
    field :socket, :gen_tcp.socket()
    field :task_supervisor, :atom
    field :on_tcp_receive, Specification.on_tcp_receive()
    field :on_tcp_connect, Specification.on_tcp_connect()
    field :on_tcp_close, Specification.on_tcp_close()
    field :receive_length, non_neg_integer()
  end

  def start_link(%Specification{
        tcp: %Specification.Tcp{
          port: tcp_port,
          options: tcp_options,
          task_supervisor: task_supervisor,
          receive_length: receive_length,
          on_tcp_connect: on_tcp_connect,
          on_tcp_receive: on_tcp_receive,
          on_tcp_close: on_tcp_close
        },
        server: %Specification.Server{options: fun_options}
      }) do
    FunServer.start_link(__MODULE__, fun_options, fn ->
      {:ok, socket} = :gen_tcp.listen(tcp_port, tcp_options)

      tcp_server_name = Keyword.get(fun_options, :name, "No name provided to server")

      init_state = %State{
        socket: socket,
        on_tcp_receive: on_tcp_receive,
        on_tcp_close: on_tcp_close,
        on_tcp_connect: on_tcp_connect,
        receive_length: receive_length,
        task_supervisor: task_supervisor
      }

      Logger.info(
        [
          "[#{__MODULE__}]",
          "Starting TCP for #{inspect(tcp_server_name)}",
          "Listening on socket #{inspect(socket)}",
          "Port #{tcp_port}",
          "Initial state #{inspect(init_state)}"
        ]
        |> Enum.join("\n")
      )

      {:ok, init_state, {:continue, &accept_connection/1}}
    end)
  end

  def send(socket, packet), do: :gen_tcp.send(socket, packet)
  def close(socket), do: :gen_tcp.close(socket)

  defp accept_connection(
         %State{
           socket: socket,
           on_tcp_connect: on_tcp_connect,
           on_tcp_receive: on_tcp_receive,
           on_tcp_close: on_tcp_close,
           receive_length: receive_length,
           task_supervisor: task_supervisor
         } = state
       ) do
    case :gen_tcp.accept(socket) do
      {:ok, connection_socket} ->
        Logger.info("[#{__MODULE__}] Established connection on #{inspect(connection_socket)}")
        on_tcp_connect.(connection_socket)

        Task.Supervisor.start_child(
          task_supervisor,
          __MODULE__,
          :handle_client,
          [
            %{
              socket: connection_socket,
              receive_length: receive_length,
              on_tcp_receive: on_tcp_receive,
              on_tcp_close: on_tcp_close
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
          on_tcp_receive: on_tcp_receive,
          on_tcp_close: on_tcp_close
        } = args
      ) do
    case :gen_tcp.recv(socket, receive_length) do
      {:ok, packet} ->
        Logger.debug(
          "[#{__MODULE__}] Connection #{inspect(socket)} received packet #{inspect(packet, limit: :infinity)}"
        )

        on_tcp_receive.(socket, packet)
        handle_client(args)

      {:error, :timeout} ->
        Logger.debug("[#{__MODULE__}] Connection #{inspect(socket)} timed out")

        handle_client(args)

      {:error, :closed} ->
        Logger.warn("[#{__MODULE__}] Connection #{inspect(socket)} was closed normally")

        :gen_tcp.close(socket)
        on_tcp_close.(socket)

      {:error, reason} ->
        Logger.error(
          "[#{__MODULE__}] Connection #{inspect(socket)} failed with #{inspect(reason)}"
        )

        :gen_tcp.close(socket)
        on_tcp_close.(socket)
    end
  end
end
