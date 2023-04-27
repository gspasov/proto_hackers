defmodule ProtoHackers.PrimeTime.Supervisor do
  @moduledoc false

  use Supervisor

  alias ProtoHackers.PrimeTime
  alias ProtoHackers.TcpServer

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    task_supervisor = PrimeTime.TaskSupervisor

    children = [
      {Task.Supervisor, name: task_supervisor, strategy: :one_for_one},
      PrimeTime,
      TcpServer.PrimeTime.spec(port: port, task_supervisor: task_supervisor)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
