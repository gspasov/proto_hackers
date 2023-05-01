defmodule ProtoHackers.UnusualDatabaseProgram.Supervisor do
  use Supervisor

  alias ProtoHackers.UnusualDatabaseProgram

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    children = [
      UnusualDatabaseProgram,
      UnusualDatabaseProgram.UdpServer.spec(port: port)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
