defmodule ProtoHackersTest.SpeedDaemonTest do
  use ExUnit.Case, async: true

  alias ProtoHackers.SpeedDaemon
  alias ProtoHackers.SpeedDaemon.Type

  test "parses Error correctly" do
    parse_result =
      "100b696c6c6567616c206d7367"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result == {%Type.Error{message: "illegal msg"}, <<>>}

    parse_result2 =
      "1003626164"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result2 == {%Type.Error{message: "bad"}, <<>>}
  end

  test "parses Plate correctly" do
    parse_result =
      "200752453035424b470001e240"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result == {%Type.Plate{plate: "RE05BKG", timestamp: 123_456}, <<>>}

    parse_result2 =
      "2004554e3158000003e8"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result2 == {%Type.Plate{plate: "UN1X", timestamp: 1000}, <<>>}
  end

  test "parses Ticket correctly" do
    parse_result =
      "2104554e3158004200640001e240006e0001e3a82710"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result ==
             {%Type.Ticket{
                plate: "UN1X",
                road: 66,
                mile1: 100,
                timestamp1: 123_456,
                mile2: 110,
                timestamp2: 123_816,
                speed: 10000
              }, <<>>}

    parse_result2 =
      "210752453035424b47017004d2000f424004d3000f427c1770"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result2 ==
             {%Type.Ticket{
                plate: "RE05BKG",
                road: 368,
                mile1: 1234,
                timestamp1: 1_000_000,
                mile2: 1235,
                timestamp2: 1_000_060,
                speed: 6000
              }, <<>>}
  end

  test "parses WantHeartbeat correctly" do
    parse_result =
      "400000000a"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result == {%Type.WantHeartbeat{interval: 10}, <<>>}

    parse_result2 =
      "40000004db"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result2 == {%Type.WantHeartbeat{interval: 1243}, <<>>}
  end

  test "parses Heartbeat correctly" do
    parse_result =
      "41"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result == {%Type.Heartbeat{}, <<>>}
  end

  test "parses IAmCamera correctly" do
    parse_result =
      "8000420064003c"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result == {%Type.IAmCamera{road: 66, mile: 100, limit: 60}, <<>>}

    parse_result2 =
      "80017004d20028"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result2 == {%Type.IAmCamera{road: 368, mile: 1234, limit: 40}, <<>>}
  end

  test "parses IAmDispatcher correctly" do
    parse_result =
      "81010042"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result == {%Type.IAmDispatcher{roads: [66]}, <<>>}

    parse_result2 =
      "8103004201701388"
      |> Base.decode16!(case: :lower)
      |> SpeedDaemon.parse()

    assert parse_result2 == {%Type.IAmDispatcher{roads: [5000, 368, 66]}, <<>>}
  end
end
