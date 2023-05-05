defmodule ProtoHackers.MobInTheMiddle.TcpServer do
  @moduledoc false

  alias ProtoHackers.TcpServer
  alias ProtoHackers.TcpServer.Specification
  alias ProtoHackers.MobInTheMiddle

  def spec(opts) do
    %{
      id: __MODULE__,
      start:
        {TcpServer, :start_link,
         [
           %Specification{
             tcp: %Specification.Tcp{
               port: Keyword.fetch!(opts, :port),
               task_supervisor: Keyword.fetch!(opts, :task_supervisor),
               options: [mode: :binary, active: false, packet: :line],
               on_tcp_connect: &MobInTheMiddle.on_tcp_connect/1,
               on_tcp_receive: &MobInTheMiddle.on_tcp_receive/2,
               on_tcp_close: &MobInTheMiddle.on_tcp_close/1
             },
             server: %Specification.Server{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
