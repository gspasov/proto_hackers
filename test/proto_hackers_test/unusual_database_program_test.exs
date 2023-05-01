defmodule ProtoHackersTest.UnusualDatabaseProgramTest do
  use ExUnit.Case, async: true

  alias ProtoHackers.UnusualDatabaseProgram
  alias ProtoHackers.UnusualDatabaseProgram.Request

  test "parsing requests correctly" do
    request_1 = UnusualDatabaseProgram.parse_request("foo=bar")
    assert request_1 == %Request.Insert{key: "foo", value: "bar"}

    request_2 = UnusualDatabaseProgram.parse_request("foo=bar=baz")
    assert request_2 == %Request.Insert{key: "foo", value: "bar=baz"}

    request_3 = UnusualDatabaseProgram.parse_request("foo=")
    assert request_3 == %Request.Insert{key: "foo", value: ""}

    request_4 = UnusualDatabaseProgram.parse_request("foo===")
    assert request_4 == %Request.Insert{key: "foo", value: "=="}

    request_5 = UnusualDatabaseProgram.parse_request("=foo")
    assert request_5 == %Request.Insert{key: "", value: "foo"}
  end
end
