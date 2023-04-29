defmodule ProtoHackers.BudgetChat.Supervisor do
  @moduledoc false

  use Supervisor

  alias ProtoHackers.BudgetChat

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    task_supervisor = BudgetChat.TaskSupervisor

    children = [
      {Task.Supervisor, name: task_supervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: BudgetChat.registry_name()},
      {DynamicSupervisor, name: BudgetChat.dynamic_supervisor_name(), strategy: :one_for_one},
      BudgetChat.Group,
      BudgetChat.TcpServer.spec(port: port, task_supervisor: task_supervisor)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
