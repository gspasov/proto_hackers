defmodule ProtoHackers.MobInTheMiddle do
  @moduledoc false

  use FunServer

  alias ProtoHackers.TcpServer

  @behaviour TcpServer.Behaviour

  require Logger

  @server_host 'chat.protohackers.com'
  @server_port 16_963
  @tony_boguscoin_address "7YWHMfk9JZe0LM0g1ZauHuiSxhI"

  def dynamic_supervisor_name, do: DynamicSupervisor.MobInTheMiddle
  def registry_name, do: Registry.MobInTheMiddle

  def start_link(client_socket) do
    FunServer.start_link(
      __MODULE__,
      [name: {:via, Registry, {registry_name(), client_socket}}],
      fn ->
        {:ok, server_socket} =
          :gen_tcp.connect(@server_host, @server_port, mode: :binary, packet: :line, active: true)

        Logger.debug("[#{__MODULE__}] Start server socket #{inspect(server_socket)}")

        {:ok, %{server_socket: server_socket, client_socket: client_socket}}
      end
    )
  end

  @impl true
  def on_tcp_connect(socket) do
    start_upstream_server(socket)
  end

  @impl true
  def on_tcp_receive(socket, packet) do
    {:ok, server_pid} = maybe_session_pid(socket)
    Logger.debug("[#{__MODULE__}] Received packet: #{inspect(packet)}")

    FunServer.async(server_pid, fn %{server_socket: server_socket} = state ->
      packet_with_replaced_address = maybe_replace_boguscoin_address(packet)

      Logger.debug(
        "[#{__MODULE__}] Sending packet to upstream: #{inspect(packet_with_replaced_address)}"
      )

      TcpServer.send(server_socket, packet_with_replaced_address)

      {:noreply, state}
    end)
  end

  @impl true
  def on_tcp_close(socket) do
    {:ok, server_pid} = maybe_session_pid(socket)

    FunServer.async(server_pid, fn %{server_socket: server_socket} = state ->
      Logger.debug("[#{__MODULE__}] Stopping upstream server")
      TcpServer.close(server_socket)

      {:noreply, state}
    end)
  end

  @impl true
  def handle_info({:tcp, server, packet}, %{server_socket: server, client_socket: socket} = state) do
    Logger.debug("[#{__MODULE__}] Receiving packet from upstream: #{inspect(packet)}")
    packet_with_replaced_address = maybe_replace_boguscoin_address(packet)

    Logger.debug(
      "[#{__MODULE__}] Sending packet from upstream: #{inspect(packet_with_replaced_address)}"
    )

    TcpServer.send(socket, packet_with_replaced_address)

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, server}, %{server_socket: server, client_socket: socket} = state) do
    Logger.debug("[#{__MODULE__}] Upstream is closing")
    TcpServer.close(socket)

    {:noreply, state}
  end

  defp start_upstream_server(socket) do
    case DynamicSupervisor.start_child(dynamic_supervisor_name(), {__MODULE__, socket}) do
      {:ok, _} ->
        Logger.debug("[#{__MODULE__}] Connected to server for socket #{inspect(socket)}")
        :ok

      {:error, reason} ->
        Logger.error(
          "[#{__MODULE__}] Stopping tcp socket #{inspect(socket)} with #{inspect(reason)}"
        )

        TcpServer.close(socket)
    end
  end

  @spec maybe_replace_boguscoin_address(message) :: message when message: String.t()
  def maybe_replace_boguscoin_address(message) do
    ~r/\s?7[a-zA-Z0-9]{25,34}(\s|\n)/
    |> Regex.replace(message, fn match ->
      case match do
        <<first::binary-1, _address::binary-size(byte_size(match) - 2), last::binary-1>> ->
          "#{parse_first_char(first)}#{@tony_boguscoin_address}#{parse_last_char(last)}"
      end
    end)
    |> case do
      ^message -> message
      new_message -> new_message
    end
  end

  defp parse_first_char(<<?\s>>), do: <<?\s>>
  defp parse_first_char(_), do: ""

  defp parse_last_char(<<?\s>>), do: <<?\s>>
  defp parse_last_char(<<?\n>>), do: <<?\n>>
  defp parse_last_char(_), do: ""

  defp maybe_session_pid(socket) do
    case Registry.lookup(registry_name(), socket) do
      [] -> nil
      [{pid, _}] -> {:ok, pid}
    end
  end
end
