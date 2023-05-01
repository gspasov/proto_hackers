defmodule ProtoHackers.UdpServer do
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

  def send(socket, packet), do: :gen_udp.send(socket, packet)

  def close(socket), do: :gen_udp.close(socket)

  def handle_info({:udp, socket, _host, _port, packet}, %{on_udp_receive: on_udp_receive} = state) do
    Logger.debug(
      "[#{__MODULE__}] Received packet on socket #{inspect(socket)}: #{inspect(packet)}"
    )

    on_udp_receive.(packet)

    {:noreply, state}
  end
end
