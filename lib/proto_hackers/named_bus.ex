defmodule ProtoHackers.NamedBus do
  @moduledoc """
  Describes function that should be exposed in a Named BUS
  """

  @callback subscribe(name :: any()) :: :ok
  @callback unsubscribe(name :: any()) :: :ok
  @callback broadcast(name :: any(), message :: any()) :: :ok
end
