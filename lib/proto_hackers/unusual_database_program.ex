defmodule ProtoHackers.UnusualDatabaseProgram do
  use FunServer

  alias ProtoHackers.UdpServer
  alias ProtoHackers.UnusualDatabaseProgram.Request
  alias WarmFuzzyThing.Maybe

  require Logger

  @behaviour UdpServer.Behaviour

  @equal_sign ?=

  def start_link() do
    FunServer.start_link(__MODULE__, fn ->
      {:ok, %{"version" => "Ken's Key-Value Store 1.0"}}
    end)
  end

  @impl true
  def on_udp_open(socket) do
    FunServer.async(__MODULE__, fn state ->
      {:noreply, %{state | udp_socket: socket}}
    end)
  end

  @impl true
  def on_udp_receive(socket, packet) when byte_size(packet) < 1000 do
    packet
    |> parse_request()
    |> handle_request(socket)
  end

  @impl true
  def on_udp_receive(_socket, packet) do
    Logger.warn("[#{__MODULE__}] Packet too large: #{byte_size(packet)} bytes")
    :ignore
  end

  def handle_request(%Request.Insert{key: "version"}, _socket) do
    Logger.warn("[#{__MODULE__}] Client tries to modify 'version'")
    :ignore
  end

  def handle_request(%Request.Insert{key: key, value: value}, _socket) do
    FunServer.async(__MODULE__, fn state ->
      new_state = Map.update(state, key, value, fn _ -> value end)
      {:noreply, new_state}
    end)
  end

  def handle_request(%Request.Retrieve{key: key}, socket) do
    FunServer.async(__MODULE__, fn state ->
      state
      |> Map.get(key)
      |> Maybe.pure()
      |> Maybe.on_just(fn value -> UdpServer.send(socket, "#{key}=#{value}") end)

      {:noreply, state}
    end)
  end

  def parse_request(request) do
    byte_list = :binary.bin_to_list(request)

    if @equal_sign in byte_list do
      {key_bytes, [_separator | value_bytes]} =
        Enum.split_while(byte_list, fn byte -> byte != @equal_sign end)

      %Request.Insert{
        key: :erlang.iolist_to_binary(key_bytes),
        value: :erlang.iolist_to_binary(value_bytes)
      }
    else
      %Request.Retrieve{key: request}
    end
  end
end
