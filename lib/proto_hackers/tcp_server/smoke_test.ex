defmodule ProtoHackers.TcpServer.SmokeTest do
  alias ProtoHackers.TcpServer
  alias ProtoHackers.SmokeTest

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
               packet_handler: &SmokeTest.packet_handler/2
             },
             server: %{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
