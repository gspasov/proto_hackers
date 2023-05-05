defmodule ProtoHackers.MobInTheMiddle.Supervisor do
  @moduledoc false

  use Supervisor

  alias ProtoHackers.MobInTheMiddle

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    task_supervisor = MobInTheMiddle.TaskSupervisor

    children = [
      {Task.Supervisor, name: task_supervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: MobInTheMiddle.registry_name()},
      {DynamicSupervisor, name: MobInTheMiddle.dynamic_supervisor_name(), strategy: :one_for_one},
      MobInTheMiddle.TcpServer.spec(port: port, task_supervisor: task_supervisor)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
