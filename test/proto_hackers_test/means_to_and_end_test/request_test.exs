defmodule ProtoHackersTest.MeansToAnEndTest.RequestTest do
  use ExUnit.Case, async: true

  alias ProtoHackers.MeansToAnEnd.Request

  test "correctly parses incoming requests" do
    [
      {"49 00 00 30 39 00 00 00 65", %Request.Insert{timestamp: 12_345, price: 101}},
      {"49 00 00 30 3a 00 00 00 66", %Request.Insert{timestamp: 12_346, price: 102}},
      {"49 00 00 30 3b 00 00 00 64", %Request.Insert{timestamp: 12_347, price: 100}},
      {"49 00 00 a0 00 00 00 00 05", %Request.Insert{timestamp: 40_960, price: 5}},
      {"51 00 00 30 00 00 00 40 00", %Request.Query{min_timestamp: 12_288, max_timestamp: 16_384}}
    ]
    |> Enum.map(fn {raw_request, expected_response} ->
      parsed_request =
        raw_request
        |> String.replace(" ", "")
        |> Base.decode16!(case: :lower)
        |> Request.parse()

      {parsed_request, expected_response}
    end)
    |> Enum.each(fn {parsed_request, expected_request} ->
      assert parsed_request == expected_request
    end)
  end
end
