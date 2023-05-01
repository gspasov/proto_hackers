defmodule ProtoHackers.Application do
  @moduledoc false

  use Application

  alias ProtoHackers.SmokeTest
  alias ProtoHackers.PrimeTime
  alias ProtoHackers.MeansToAnEnd
  alias ProtoHackers.BudgetChat
  alias ProtoHackers.UnusualDatabaseProgram

  @impl true
  def start(_type, _args) do
    children = [
      pg_spec(),
      {SmokeTest.Supervisor, 5010},
      {PrimeTime.Supervisor, 5020},
      {MeansToAnEnd.Supervisor, 5030},
      {BudgetChat.Supervisor, 5040},
      {UnusualDatabaseProgram.Supervisor, 6000}
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
