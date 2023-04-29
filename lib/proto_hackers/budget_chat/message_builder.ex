defmodule ProtoHackers.BudgetChat.MessageBuilder do
  @spec welcome() :: String.t()
  def welcome, do: "Welcome to budget chat! What shall I call you?\n"

  @spec join(username :: String.t()) :: String.t()
  def join(username), do: "* #{username} has entered the room\n"

  @spec leave(username :: String.t()) :: String.t()
  def leave(username), do: "* #{username} has left the room\n"

  @spec message(username :: String.t(), message :: String.t()) :: String.t()
  def message(username, message), do: "[#{username}] #{message}\n"

  @spec participants([String.t()]) :: String.t()
  def participants(usernames)

  def participants([]), do: "* The room is empty..\n"

  def participants(usernames) do
    "* The room contains" <> Enum.join(usernames, ", ") <> "\n"
  end
end
