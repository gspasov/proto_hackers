defmodule ProtoHackers do
  use Application

  alias ProtoHackers.TcpServer

  @impl true
  def start(_type, _args) do
    children = [
      %{
        id: SmokeTest,
        start:
          {TcpServer, :start_link,
           [
             %{
               tcp: %{
                 port: 4000,
                 options: [:binary, {:active, false}, {:packet, 0}],
                 packet_handler: fn socket, packet -> :gen_tcp.send(socket, packet) end
               },
               server: %{
                 options: [name: SmokeTest]
               }
             }
           ]}
      },
      {Task.Supervisor, name: ProtoHackers.TaskSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: ProtoHackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
