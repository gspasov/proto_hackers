defmodule ProtoHackers.SpeedDaemon.Supervisor do
  @moduledoc false

  use Supervisor

  alias ProtoHackers.SpeedDaemon

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    task_supervisor = SpeedDaemon.TaskSupervisor

    children = [
      {Task.Supervisor, name: task_supervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: SpeedDaemon.registry_name()},
      {DynamicSupervisor, name: SpeedDaemon.dynamic_supervisor_name(), strategy: :one_for_one},
      SpeedDaemon.OverWatch,
      SpeedDaemon.TcpServer.spec(port: port, task_supervisor: task_supervisor)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
