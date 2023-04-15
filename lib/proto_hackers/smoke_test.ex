defmodule ProtoHackers.SmokeTest do
  def start_link() do
    ProtoHackers.TcpServer.start_link(%{
      tcp: %{
        port: 4000,
        options: [:binary, {:active, false}, {:packet, 0}],
        packet_handler: fn socket, packet -> :gen_tcp.send(socket, packet) end
      },
      server: %{
        options: [name: __MODULE__]
      }
    })
  end
end
