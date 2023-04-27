defmodule ProtoHackers.MeansToAnEnd.Supervisor do
  @moduledoc false

  use Supervisor

  alias ProtoHackers.TcpServer

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    task_supervisor = MeansToAnEnd.TaskSupervisor

    children = [
      {Task.Supervisor, name: task_supervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: Registry.MeansToAnEnd},
      {DynamicSupervisor, name: DynamicSupervisor.MeansToAnEnd, strategy: :one_for_one},
      TcpServer.MeansToAnEnd.spec(port: port, task_supervisor: task_supervisor)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
