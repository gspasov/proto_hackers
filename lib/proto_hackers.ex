defmodule ProtoHackers do
  use Application

  alias ProtoHackers.TcpServer
  alias ProtoHackers.PrimeTime

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: ProtoHackers.TaskSupervisor, strategy: :one_for_one},
      TcpServer.SmokeTest.spec(port: 4010),
      PrimeTime,
      TcpServer.PrimeTime.spec(port: 4020),
      {Registry, keys: :unique, name: Registry.MeansToAnEnd},
      {DynamicSupervisor, name: ProtoHackers.DynamicSupervisor, strategy: :one_for_one},
      TcpServer.MeansToAnEnd.spec(port: 4030)
    ]

    opts = [strategy: :one_for_one, name: ProtoHackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
