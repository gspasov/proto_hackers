defmodule ProtoHackers do
  use Application

  alias ProtoHackers.SmokeTest
  alias ProtoHackers.PrimeTime

  @impl true
  def start(_type, _args) do
    children = [
      SmokeTest.spec(port: 4001),
      PrimeTime.spec(port: 4002),
      {Task.Supervisor, name: ProtoHackers.TaskSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: ProtoHackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
