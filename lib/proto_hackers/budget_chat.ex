defmodule ProtoHackers.BudgetChat do
  use FunServer
  use TypedStruct

  alias ProtoHackers.BudgetChat.MessageBuilder
  alias ProtoHackers.BudgetChat.Group
  alias ProtoHackers.TcpServer
  alias ProtoHackers.BudgetChat.State
  alias ProtoHackers.BudgetChat.Bus

  require Logger

  typedstruct module: State do
    field :status, :connected | :joined | :left, required: true
    field :tcp_socket, :gen_tcp.socket(), required: true
    field :packet, String.t(), required: true
    field :name, String.t()
  end

  def dynamic_supervisor_name, do: DynamicSupervisor.BudgetChat
  def registry_name, do: Registry.BudgetChat

  def start_link(tcp_socket) do
    FunServer.start_link(
      __MODULE__,
      [name: {:via, Registry, {registry_name(), tcp_socket}}],
      fn ->
        Bus.subscribe()
        {:ok, %State{tcp_socket: tcp_socket, status: :connected, packet: ""}}
      end
    )
  end

  def on_connect_callback(socket) do
    case DynamicSupervisor.start_child(dynamic_supervisor_name(), {__MODULE__, socket}) do
      {:ok, _} ->
        Logger.debug("[#{__MODULE__}] Sending welcome message to #{inspect(socket)}")
        TcpServer.tcp_send(socket, MessageBuilder.welcome())

      {:error, reason} ->
        Logger.error(
          "[#{__MODULE__}] Stopping tcp socket #{inspect(socket)} with #{inspect(reason)}"
        )

        TcpServer.tcp_close(socket)
    end
  end

  def on_receive_callback(socket, packet) do
    {:ok, pid} = maybe_session_pid(socket)
    handle_packet(pid, packet)
  end

  def on_close_callback(socket) do
    case maybe_session_pid(socket) do
      nil ->
        Logger.error("[#{__MODULE__}] Unable to find Session for socket #{inspect(socket)}")

      {:ok, pid} ->
        Logger.warn(
          "[#{__MODULE__}] Stopping Session #{inspect(pid)} for socket #{inspect(socket)}"
        )

        leave(pid)
    end
  end

  def handle_packet(session, packet) do
    FunServer.async(session, fn %State{packet: current_packet} = state ->
      new_packet = current_packet <> packet

      new_state =
        if end_of_request?(new_packet) do
          handle_request(session, clean_request(new_packet))
          %State{state | packet: ""}
        else
          %State{state | packet: new_packet}
        end

      {:noreply, new_state}
    end)
  end

  def handle_request(session, request) do
    FunServer.async(session, fn %State{status: status} = state ->
      case status do
        :connected -> set_name(session, request)
        :joined -> send_message(session, request)
      end

      {:noreply, state}
    end)
  end

  def set_name(session, name) do
    FunServer.async(session, fn %State{status: :connected, tcp_socket: tcp_socket} = state ->
      new_state =
        case validate_name(name) do
          :ok ->
            Logger.debug("[#{__MODULE__}] #{inspect(name)} is joining the Chat")
            Bus.broadcast_join(name)

            usernames = Group.get_users()
            TcpServer.tcp_send(tcp_socket, MessageBuilder.participants(usernames))
            Group.join(name)

            %State{state | name: name, status: :joined}

          {:error, reason} ->
            Logger.warn(
              "[#{__MODULE__}] Stopping TCP socket #{inspect(tcp_socket)} with #{inspect(reason)}"
            )

            TcpServer.tcp_close(tcp_socket)
            state
        end

      {:noreply, new_state}
    end)
  end

  def send_message(session, message) do
    FunServer.async(session, fn %State{status: :joined, name: name} = state ->
      Bus.broadcast_message(name, message)
      {:noreply, state}
    end)
  end

  def leave(session) do
    FunServer.async(session, fn %State{status: status, name: name} = state ->
      case status do
        :connected ->
          Logger.debug("[#{__MODULE__}] A User left without even joining the Chat")

        :joined ->
          Logger.debug("[#{__MODULE__}] #{inspect(name)} is leaving the Chat")
          Group.leave(name)
          Bus.broadcast_leave(name)
      end

      {:stop, :normal, %State{state | status: :left}}
    end)
  end

  @impl true
  def handle_info(
        {Bus, %Bus.Message{username: receiver}},
        %State{status: :joined, name: receiver} = state
      ) do
    {:noreply, state}
  end

  @impl true
  def handle_info({Bus, %Bus.Message{}}, %State{status: :connected} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {Bus, %Bus.Message{message: message}},
        %State{
          status: :joined,
          tcp_socket: tcp_socket
        } = state
      ) do
    TcpServer.tcp_send(tcp_socket, message)
    {:noreply, state}
  end

  @impl true
  def handle_info({Bus, unknown_message}, state) do
    Logger.error("[#{__MODULE__}] Received unexpected message #{inspect(unknown_message)}")
    {:noreply, state}
  end

  defp validate_name(""), do: {:error, "Name must contain at least one character"}

  defp validate_name(name) do
    name
    |> String.to_charlist()
    |> Enum.all?(fn char -> char in ?a..?z or char in ?A..?Z or char in ?0..?9 end)
    |> if do
      :ok
    else
      {:error, "Name should consist entirely of alphanumeric characters got #{inspect(name)}"}
    end
  end

  defp clean_request(request) do
    request
    |> String.replace("\n", "")
    |> String.replace("\r", "")
  end

  defp maybe_session_pid(socket) do
    case Registry.lookup(registry_name(), socket) do
      [] -> nil
      [{pid, _}] -> {:ok, pid}
    end
  end

  defp end_of_request?(packet), do: String.last(packet) == "\n"
end
