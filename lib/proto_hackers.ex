defmodule ProtoHackers do
  use Application

  alias ProtoHackers.TcpServer

  @impl true
  def start(_type, _args) do
    children = [
      TcpServer,
      {Task.Supervisor, name: ProtoHackers.TaskSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: ProtoHackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
