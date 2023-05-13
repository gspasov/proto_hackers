defmodule ProtoHackers.SpeedDaemon do
  use FunServer
  use TypedStruct

  alias ProtoHackers.SpeedDaemon.Request.Error
  alias ProtoHackers.TcpServer
  alias ProtoHackers.SpeedDaemon.OverWatch
  alias ProtoHackers.SpeedDaemon.OverWatch.Snapshot
  alias ProtoHackers.SpeedDaemon.State
  alias ProtoHackers.SpeedDaemon.Ticket
  alias ProtoHackers.SpeedDaemon.Request
  alias ProtoHackers.SpeedDaemon.Request.Heartbeat
  alias ProtoHackers.SpeedDaemon.Request.Plate
  alias ProtoHackers.SpeedDaemon.Request.WantHeartbeat
  alias ProtoHackers.SpeedDaemon.Request.IAmDispatcher
  alias ProtoHackers.SpeedDaemon.Request.IAmCamera
  alias ProtoHackers.Utils

  @behaviour TcpServer.Behaviour

  @type road :: non_neg_integer()
  @type plate :: String.t()

  require Logger

  typedstruct module: State do
    field :tcp_socket, :gen_tcp.socket(), required: true
    field :packet, binary(), required: true
    field :type, :camera | :dispatcher
    field :heartbeat, non_neg_integer()
    field :camera, IAmCamera
    field :dispatcher, IAmDispatcher
  end

  def dynamic_supervisor_name, do: DynamicSupervisor.SpeedDaemon
  def registry_name, do: Registry.SpeedDaemon

  def start_link(tcp_socket) do
    FunServer.start_link(
      __MODULE__,
      [name: {:via, Registry, {registry_name(), tcp_socket}}],
      fn -> {:ok, %State{packet: <<>>, tcp_socket: tcp_socket}} end
    )
  end

  @impl true
  def on_tcp_connect(socket) do
    case DynamicSupervisor.start_child(dynamic_supervisor_name(), {__MODULE__, socket}) do
      {:ok, _} ->
        Logger.debug("[#{__MODULE__}] New Client Connection #{inspect(socket)}")

      {:error, reason} ->
        Logger.error("[#{__MODULE__}] Stopping client #{inspect(socket)} with #{inspect(reason)}")

        TcpServer.close(socket)
    end
  end

  @impl true
  def on_tcp_receive(socket, packet) do
    {:ok, pid} = Utils.maybe_session_pid(socket, registry_name())
    handle_packet(pid, packet)
  end

  @impl true
  def on_tcp_close(socket) do
    case Utils.maybe_session_pid(socket, registry_name()) do
      nil ->
        Logger.error("[#{__MODULE__}] Unable to find Session for socket #{inspect(socket)}")

      {:ok, pid} ->
        Logger.warn(
          "[#{__MODULE__}] Stopping Session #{inspect(pid)} for socket #{inspect(socket)}"
        )

        stop(pid)
    end
  end

  def stop(server) do
    FunServer.async(server, fn %State{type: type, dispatcher: dispatcher} = state ->
      if type == :dispatcher do
        OverWatch.Bus.broadcast_dispatcher_close(self(), dispatcher)
      end

      {:stop, :normal, state}
    end)
  end

  def handle_packet(server, packet) do
    FunServer.async(server, fn %State{packet: leftover_packet} = state ->
      new_leftover_packet =
        case Request.decode(leftover_packet <> packet) do
          {[], new_leftover} ->
            Logger.debug(
              "[#{__MODULE__}] No Parsed Requests with leftover #{inspect(new_leftover)}"
            )

            new_leftover

          {requests, new_leftover} ->
            Logger.debug("[#{__MODULE__}] Parsed requests #{inspect(requests)}")

            Enum.each(requests, fn request ->
              handle_request(server, request)
            end)

            new_leftover
        end

      {:noreply, %{state | packet: new_leftover_packet}}
    end)
  end

  def handle_request(server, %WantHeartbeat{interval: interval}) do
    FunServer.async(server, fn
      %State{heartbeat: nil} = state ->
        interval_in_milliseconds = deciseconds_to_milliseconds(interval)

        if interval_in_milliseconds > 0 do
          Process.send_after(self(), :heartbeat, interval_in_milliseconds)
        end

        {:noreply, %State{state | heartbeat: interval_in_milliseconds}}

      %State{tcp_socket: tcp_socket} = state ->
        TcpServer.send(
          tcp_socket,
          Request.encode(%Error{
            message: "Cannot send multiple 'WantHeartbeat' in a single session!"
          })
        )

        {:noreply, state}
    end)
  end

  def handle_request(server, %IAmCamera{} = camera) do
    FunServer.async(server, fn state ->
      {:noreply, %State{state | type: :camera, camera: camera}}
    end)
  end

  def handle_request(server, %IAmDispatcher{} = dispatcher) do
    FunServer.async(server, fn state ->
      OverWatch.Bus.broadcast_dispatcher(self(), dispatcher)
      Ticket.Bus.subscribe(self())
      {:noreply, %State{state | type: :dispatcher, dispatcher: dispatcher}}
    end)
  end

  def handle_request(server, %Plate{} = plate) do
    FunServer.async(server, fn
      %State{type: :camera, camera: camera} = state ->
        OverWatch.Bus.broadcast_snapshot(%Snapshot{camera: camera, plate: plate})
        {:noreply, state}

      %State{type: non_camera_type, tcp_socket: tcp_socket} = state ->
        error_message =
          "Only 'camera' clients can accept a Plate request, got: #{inspect(non_camera_type)}"

        Logger.warn("[#{__MODULE__}] #{inspect(error_message)}")
        TcpServer.send(tcp_socket, Request.encode(%Request.Error{message: error_message}))

        {:noreply, state}
    end)
  end

  @impl true
  def handle_info(:heartbeat, %{tcp_socket: socket, heartbeat: interval} = state) do
    Process.send_after(self(), :heartbeat, interval)
    TcpServer.send(socket, Request.encode(%Heartbeat{}))
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {Ticket.Bus, %Request.Ticket{} = ticket},
        %State{type: :dispatcher, tcp_socket: socket} = state
      ) do
    TcpServer.send(socket, Request.encode(ticket))
    {:noreply, state}
  end

  @impl true
  def handle_info({Ticket.Bus, unexpected_message}, state) do
    Logger.warn("[#{__MODULE__}] Got unexpected message: #{inspect(unexpected_message)}")
    {:noreply, state}
  end

  defp deciseconds_to_milliseconds(interval), do: interval * 100
end
