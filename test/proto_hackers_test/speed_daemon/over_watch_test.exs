defmodule ProtoHackersTest.SpeedDaemon.OverWatchTest do
  use ExUnit.Case, async: true

  alias ProtoHackers.SpeedDaemon.OverWatch
  alias ProtoHackers.SpeedDaemon.OverWatch.Snapshot
  alias ProtoHackers.SpeedDaemon.Request.IAmCamera
  alias ProtoHackers.SpeedDaemon.Request.Plate
  alias ProtoHackers.SpeedDaemon.Request.Ticket

  test "gives a single ticket for speeding" do
    {:ok, new_tickets} =
      OverWatch.maybe_tickets(
        %Snapshot{
          camera: %IAmCamera{road: 123, mile: 8, limit: 60},
          plate: %Plate{plate: "UN1X", timestamp: 0}
        },
        %Snapshot{
          camera: %IAmCamera{road: 123, mile: 9, limit: 60},
          plate: %Plate{plate: "UN1X", timestamp: 45}
        },
        %{}
      )

    Enum.each(new_tickets, fn {day, ticket} ->
      assert day == 0

      assert ticket ==
               %Ticket{
                 plate: "UN1X",
                 road: 123,
                 mile1: 8,
                 mile2: 9,
                 timestamp1: 0,
                 timestamp2: 45,
                 speed: 8000
               }
    end)
  end

  test "If ticket spans multiple days you get ticket for each day" do
    {:ok, new_tickets} =
      OverWatch.maybe_tickets(
        %Snapshot{
          camera: %IAmCamera{road: 123, mile: 0, limit: 60},
          plate: %Plate{plate: "UN1X", timestamp: 1_683_655_445}
        },
        %Snapshot{
          camera: %IAmCamera{road: 123, mile: 6000, limit: 60},
          plate: %Plate{plate: "UN1X", timestamp: 1_683_965_445}
        },
        %{}
      )

    assert length(new_tickets) == 5

    Enum.each(new_tickets, fn {_day, ticket} ->
      assert ticket ==
               %Ticket{
                 plate: "UN1X",
                 road: 123,
                 mile1: 0,
                 mile2: 6000,
                 timestamp1: 1_683_655_445,
                 timestamp2: 1_683_965_445,
                 speed: 6967
               }
    end)
  end
end
