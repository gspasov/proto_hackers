defmodule ProtoHackers.UnusualDatabaseProgram.UdpServer do
  @moduledoc false

  alias ProtoHackers.UdpServer
  alias ProtoHackers.UdpServer.Specification
  alias ProtoHackers.UnusualDatabaseProgram

  def spec(options) do
    %{
      id: __MODULE__,
      start:
        {UdpServer, :start_link,
         [
           %Specification{
             tcp: %Specification.Udp{
               port: Keyword.fetch!(options, :port),
               options: [mode: :binary, active: true],
               on_udp_receive: &UnusualDatabaseProgram.on_udp_receive/2
             },
             server: %Specification.Server{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
