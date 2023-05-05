defmodule ProtoHackersTest.MobInTheMiddleTest do
  use ExUnit.Case, async: true

  alias ProtoHackers.MobInTheMiddle

  test "addresses with less than 26 characters won't be replaced" do
    message_1 = "[BigBob58] Please pay: 71dYs1e8ZxYMnBowR"
    result_1 = MobInTheMiddle.maybe_replace_boguscoin_address(message_1)
    assert result_1 == message_1

    message_2 = "[BigBob58] Please pay: 7addressrhFg5ah7eveWGC36d5"
    result_2 = MobInTheMiddle.maybe_replace_boguscoin_address(message_2)
    assert result_2 == message_2
  end

  test "addresses with more than 35 characters won't be replaced" do
    message_1 = "[BigBob58] Please pay: 71dYs1e8ZxYMnBowRFENSBUIFONIEBUIdfubgi21"
    result_1 = MobInTheMiddle.maybe_replace_boguscoin_address(message_1)
    assert result_1 == message_1

    message_2 = "[BigBob58] Please pay: 7fgfrew1234567890123456789012345678"
    result_2 = MobInTheMiddle.maybe_replace_boguscoin_address(message_2)
    assert result_2 == message_2
  end

  test "changes address when the conditions are in place" do
    result_1 =
      MobInTheMiddle.maybe_replace_boguscoin_address(
        "[BigBob58] Please pay the ticket price of 15 Boguscoins to one of these addresses: 74rGJOj9FnjILIcvW1ReTkZaAhRPwcW 71dYs1e8ZxYMnBowRsGGv2R58J 7usbfoifbirioDNAIOnfeiubaoawd123456\n"
      )

    expected_1 =
      "[BigBob58] Please pay the ticket price of 15 Boguscoins to one of these addresses: 7YWHMfk9JZe0LM0g1ZauHuiSxhI 7YWHMfk9JZe0LM0g1ZauHuiSxhI 7YWHMfk9JZe0LM0g1ZauHuiSxhI\n"

    assert result_1 == expected_1

    result_2 =
      MobInTheMiddle.maybe_replace_boguscoin_address(
        "[RichMike295] Send refunds to 7kibApDj86LFw3NpsQ2WmVCyvB1SHYJS1 please."
      )

    expected_2 = "[RichMike295] Send refunds to 7YWHMfk9JZe0LM0g1ZauHuiSxhI please."

    assert result_2 == expected_2
  end
end
