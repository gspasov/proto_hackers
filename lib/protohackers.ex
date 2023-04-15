defmodule Protohackers do
  use Application

  alias Protohackers.TcpServer

  @impl true
  def start(_type, _args) do
    children = [
      TcpServer,
      {Task.Supervisor, name: Protohackers.TaskSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
