defmodule ProtoHackers.TcpServer.PrimeTime do
  alias ProtoHackers.TcpServer
  alias ProtoHackers.PrimeTime

  def spec(opts) do
    %{
      id: __MODULE__,
      start:
        {TcpServer, :start_link,
         [
           %{
             tcp: %{
               port: Keyword.fetch!(opts, :port),
               options: [{:mode, :binary}, {:active, false}, {:packet, :line}],
               on_receive_callback: &PrimeTime.on_receive_callback/2
             },
             server: %{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
