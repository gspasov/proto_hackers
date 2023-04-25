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
               port: Keyword.fetch!(opts, :port),
               options: [{:mode, :binary}, {:active, false}, {:packet, 0}],
               on_receive_callback: &SmokeTest.on_receive_callback/2
             },
             server: %{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
