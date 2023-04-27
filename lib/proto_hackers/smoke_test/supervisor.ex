defmodule ProtoHackers.SmokeTest.Supervisor do
  @moduledoc false

  use Supervisor

  alias ProtoHackers.TcpServer

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    task_supervisor = SmokeTest.TaskSupervisor

    children = [
      {Task.Supervisor, name: task_supervisor, strategy: :one_for_one},
      TcpServer.SmokeTest.spec(port: port, task_supervisor: task_supervisor)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
