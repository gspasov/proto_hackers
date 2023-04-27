defmodule ProtoHackers.TcpServer.SmokeTest do
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
               on_receive_callback: &SmokeTest.on_receive_callback/2
             },
             server: %Specification.Server{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
