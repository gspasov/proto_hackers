defmodule ProtoHackers.TcpServer.MeansToAnEnd do
  alias ProtoHackers.TcpServer
  alias ProtoHackers.MeansToAnEnd

  def spec(opts) do
    %{
      id: __MODULE__,
      start:
        {TcpServer, :start_link,
         [
           %{
             tcp: %{
               port: Keyword.fetch!(opts, :port),
               recv_length: 9,
               options: [{:mode, :binary}, {:active, false}, {:packet, 0}],
               on_receive_callback: &MeansToAnEnd.on_receive_callback/2,
               on_close_callback: &MeansToAnEnd.on_close_callback/1
             },
             server: %{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
