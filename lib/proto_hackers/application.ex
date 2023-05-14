defmodule ProtoHackers.Application do
  @moduledoc false

  use Application

  alias ProtoHackers.SmokeTest
  alias ProtoHackers.PrimeTime
  alias ProtoHackers.MeansToAnEnd
  alias ProtoHackers.BudgetChat
  alias ProtoHackers.MobInTheMiddle
  alias ProtoHackers.SpeedDaemon
  alias ProtoHackers.UnusualDatabaseProgram

  @impl true
  def start(_type, _args) do
    children = [
      pg_spec(),
      {SmokeTest.Supervisor, 5000},
      {PrimeTime.Supervisor, 5001},
      {MeansToAnEnd.Supervisor, 5002},
      {BudgetChat.Supervisor, 5003},
      {UnusualDatabaseProgram.Supervisor, 5004},
      {MobInTheMiddle.Supervisor, 5005},
      {SpeedDaemon.Supervisor, 5006}
    ]

    opts = [strategy: :one_for_one, name: ProtoHackers.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp pg_spec do
    %{
      id: :pg,
      start: {:pg, :start_link, []}
    }
  end
end
