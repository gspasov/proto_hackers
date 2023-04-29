defmodule ProtoHackers.SmokeTest.TcpServer do
  @moduledoc false

  alias ProtoHackers.SmokeTest
  alias ProtoHackers.TcpServer
  alias ProtoHackers.TcpServer.Specification

  def spec(opts) do
    %{
      id: __MODULE__,
      start:
        {TcpServer, :start_link,
         [
           %Specification{
             tcp: %Specification.Tcp{
               port: Keyword.fetch!(opts, :port),
               task_supervisor: Keyword.fetch(opts, :task_supervisor),
               options: [{:mode, :binary}, {:active, false}, {:packet, 0}],
               on_tcp_receive: &SmokeTest.on_tcp_receive/2
             },
             server: %Specification.Server{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
