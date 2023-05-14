defmodule ProtoHackers.UdpServer do
  @moduledoc """
  Generic Udp Server
  """

  use FunServer
  use TypedStruct

  alias ProtoHackers.UdpServer.Specification

  require Logger

  def start_link(%Specification{
        tcp: %Specification.Udp{
          port: udp_port,
          options: udp_options,
          on_udp_receive: on_udp_receive
        },
        server: %Specification.Server{options: fun_options}
      }) do
    FunServer.start_link(__MODULE__, fun_options, fn ->
      {:ok, socket} = :gen_udp.open(udp_port, udp_options)

      Logger.info(
        [
          "[#{__MODULE__}]",
          "Opened UDP socket #{inspect(socket)}",
          "Port #{udp_port}",
          "With options: #{inspect(udp_options)}"
        ]
        |> Enum.join("\n")
      )

      {:ok, %{socket: socket, on_udp_receive: on_udp_receive}}
    end)
  end

  def send({socket, host, port} = udp_info, packet) do
    Logger.debug("[#{__MODULE__}] Sending to #{inspect(udp_info)}: #{inspect(packet)}")
    :gen_udp.send(socket, host, port, packet)
  end

  def handle_info({:udp, socket, host, port, packet}, %{on_udp_receive: on_udp_receive} = state) do
    Logger.debug(
      [
        "[#{__MODULE__}]",
        "Socket: #{inspect(socket)}",
        "Host: #{inspect(host)}",
        "Port: #{inspect(port)}",
        "Packet: #{inspect(packet)}"
      ]
      |> Enum.join("\n")
    )

    on_udp_receive.({socket, host, port}, packet)

    {:noreply, state}
  end
end
