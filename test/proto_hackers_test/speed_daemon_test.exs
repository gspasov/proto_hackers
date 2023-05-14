defmodule ProtoHackersTest.SpeedDaemonTest do
  use ExUnit.Case, async: true

  alias ProtoHackers.SpeedDaemon.Request

  describe "Encoder works properly" do
    test "encodes Heartbeat correctly" do
      encode_result = Request.encode(%Request.Heartbeat{})

      assert encode_result == <<65>>
    end

    test "encodes Error correctly" do
      encode_result = Request.encode(%Request.Error{message: "illegal msg"})
      assert encode_result == <<16, 11, 105, 108, 108, 101, 103, 97, 108, 32, 109, 115, 103>>

      encode_result2 = Request.encode(%Request.Error{message: "bad"})
      assert encode_result2 == <<16, 3, 98, 97, 100>>
    end

    test "encodes Ticket correctly" do
      encode_result =
        Request.encode(%Request.Ticket{
          plate: "UN1X",
          road: 66,
          mile1: 100,
          timestamp1: 123_456,
          mile2: 110,
          timestamp2: 123_816,
          speed: 10_000
        })

      assert encode_result ==
               <<33, 4, 85, 78, 49, 88, 0, 66, 0, 100, 0, 1, 226, 64, 0, 110, 0, 1, 227, 168, 39,
                 16>>

      encode_result2 =
        Request.encode(%Request.Ticket{
          plate: "RE05BKG",
          road: 368,
          mile1: 1234,
          timestamp1: 1_000_000,
          mile2: 1235,
          timestamp2: 1_000_060,
          speed: 6000
        })

      assert encode_result2 ==
               <<33, 7, 82, 69, 48, 53, 66, 75, 71, 1, 112, 4, 210, 0, 15, 66, 64, 4, 211, 0, 15,
                 66, 124, 23, 112>>
    end
  end

  describe "decodes correctly" do
    test "decodes Plate correctly" do
      decode_result =
        "200752453035424b470001e240"
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      assert decode_result == {[%Request.Plate{plate: "RE05BKG", timestamp: 123_456}], <<>>}

      decode_result2 =
        "2004554e3158000003e8"
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      assert decode_result2 == {[%Request.Plate{plate: "UN1X", timestamp: 1000}], <<>>}
    end

    test "decodes WantHeartbeat correctly" do
      decode_result =
        "400000000a"
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      assert decode_result == {[%Request.WantHeartbeat{interval: 10}], <<>>}

      decode_result2 =
        "40000004db"
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      assert decode_result2 == {[%Request.WantHeartbeat{interval: 1243}], <<>>}
    end

    test "decodes IAmCamera correctly" do
      decode_result =
        "8000420064003c"
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      assert decode_result == {[%Request.IAmCamera{road: 66, mile: 100, limit: 60}], <<>>}

      decode_result2 =
        "80017004d20028"
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      assert decode_result2 == {[%Request.IAmCamera{road: 368, mile: 1234, limit: 40}], <<>>}
    end

    test "decodes IAmDispatcher correctly" do
      decode_result =
        "81010042"
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      assert decode_result == {[%Request.IAmDispatcher{roads: [66]}], <<>>}

      decode_result2 =
        "8103004201701388"
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      assert decode_result2 == {[%Request.IAmDispatcher{roads: [5000, 368, 66]}], <<>>}
    end

    test "decodes couple of messages in a row" do
      decode_result =
        "81010042"
        |> Kernel.<>("8103004201701388")
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      expected_result =
        {[%Request.IAmDispatcher{roads: [66]}, %Request.IAmDispatcher{roads: [5000, 368, 66]}],
         <<>>}

      assert decode_result == expected_result
    end

    test "decodes couple of messages in a row and provides leftover" do
      decode_result =
        "81010042"
        |> Kernel.<>("8103004201701388")
        |> Kernel.<>("64543265")
        |> Base.decode16!(case: :lower)
        |> Request.decode()

      expected_result =
        {[%Request.IAmDispatcher{roads: [66]}, %Request.IAmDispatcher{roads: [5000, 368, 66]}],
         <<100, 84, 50, 101>>}

      assert decode_result == expected_result
    end
  end
end
