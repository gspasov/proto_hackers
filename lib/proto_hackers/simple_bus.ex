defmodule ProtoHackers.SimpleBus do
  @moduledoc """
  Describes function that should be exposed in a Simple BUS
  """

  @callback subscribe() :: :ok
  @callback unsubscribe() :: :ok
  @callback broadcast(message :: any()) :: :ok
end
