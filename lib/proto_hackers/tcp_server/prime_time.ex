defmodule ProtoHackers.TcpServer.PrimeTime do
  @moduledoc false

  alias ProtoHackers.TcpServer
  alias ProtoHackers.TcpServer.Specification
  alias ProtoHackers.PrimeTime

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
               options: [{:mode, :binary}, {:active, false}, {:packet, :line}],
               on_receive_callback: &PrimeTime.on_receive_callback/2
             },
             server: %Specification.Server{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
