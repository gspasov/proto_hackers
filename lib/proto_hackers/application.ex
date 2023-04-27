defmodule ProtoHackers.Application do
  @moduledoc false

  use Application

  alias ProtoHackers.SmokeTest
  alias ProtoHackers.PrimeTime
  alias ProtoHackers.MeansToAnEnd

  @impl true
  def start(_type, _args) do
    children = [
      {SmokeTest.Supervisor, 4010},
      {PrimeTime.Supervisor, 4020},
      {MeansToAnEnd.Supervisor, 4030}
    ]

    opts = [strategy: :one_for_one, name: ProtoHackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
