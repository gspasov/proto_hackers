defmodule ProtoHackers do
  use Application

  alias ProtoHackers.TcpServer
  alias ProtoHackers.PrimeTime

  @impl true
  def start(_type, _args) do
    children = [
      TcpServer.SmokeTest.spec(port: 4000),
      PrimeTime,
      TcpServer.PrimeTime.spec(port: 4001),
      {Task.Supervisor, name: ProtoHackers.TaskSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: ProtoHackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
