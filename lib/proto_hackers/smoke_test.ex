defmodule ProtoHackers.SmokeTest do
  require Logger

  alias ProtoHackers.TcpServer

  def spec(opts) do
    %{
      id: __MODULE__,
      start:
        {TcpServer, :start_link,
         [
           %{
             tcp: %{
               port: Keyword.get(opts, :port, 4000),
               options: [{:mode, :binary}, {:active, false}, {:packet, 0}],
               packet_handler: &packet_handler/2
             },
             server: %{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end

  def packet_handler(socket, packet) do
    TcpServer.send(socket, packet)
  end
end
