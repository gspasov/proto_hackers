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
               port: Keyword.get(opts, :port, 4001),
               options: [{:mode, :binary}, {:active, false}, {:packet, :line}],
               packet_handler: &PrimeTime.packet_handler/2
             },
             server: %{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
