defmodule ProtoHackersTest.MeansToAnEndTest do
  use ExUnit.Case, async: true

  alias ProtoHackers.MeansToAnEnd
  alias ProtoHackers.MeansToAnEnd.Request

  setup do
    {:ok, _pid} = MeansToAnEnd.start_link([])
    :ok
  end

  test "put data in" do
    :ok = MeansToAnEnd.handle_request(%Request.Insert{timestamp: 10_000, price: 100})
    :ok = MeansToAnEnd.handle_request(%Request.Insert{timestamp: 12_000, price: 50})
    :ok = MeansToAnEnd.handle_request(%Request.Insert{timestamp: 15_000, price: 200})

    request_0 =
      MeansToAnEnd.handle_request(%Request.Query{min_timestamp: 10_000, max_timestamp: 11_000})

    assert request_0 == 100

    request_1 =
      MeansToAnEnd.handle_request(%Request.Query{min_timestamp: 10_000, max_timestamp: 12_000})

    assert request_1 == 75

    request_2 =
      MeansToAnEnd.handle_request(%Request.Query{min_timestamp: 10_000, max_timestamp: 17_000})

    assert request_2 == 117
  end

  test "If there are no samples within the requested period, or if mintime comes after maxtime, the value returned must be 0" do
    :ok = MeansToAnEnd.handle_request(%Request.Insert{timestamp: 10_000, price: 100})
    :ok = MeansToAnEnd.handle_request(%Request.Insert{timestamp: 12_000, price: 50})
    :ok = MeansToAnEnd.handle_request(%Request.Insert{timestamp: 15_000, price: 200})

    request_3 =
      MeansToAnEnd.handle_request(%Request.Query{min_timestamp: 17_000, max_timestamp: 17_000})

    assert request_3 == 0
  end
end
