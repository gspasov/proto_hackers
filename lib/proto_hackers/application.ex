defmodule ProtoHackers.Application do
  @moduledoc false

  use Application

  alias ProtoHackers.SmokeTest
  alias ProtoHackers.PrimeTime
  alias ProtoHackers.MeansToAnEnd
  alias ProtoHackers.BudgetChat

  @impl true
  def start(_type, _args) do
    children = [
      {SmokeTest.Supervisor, 5010},
      {PrimeTime.Supervisor, 5020},
      {MeansToAnEnd.Supervisor, 5030},
      {BudgetChat.Supervisor, 5040}
    ]

    opts = [strategy: :one_for_one, name: ProtoHackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
