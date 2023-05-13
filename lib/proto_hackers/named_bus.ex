defmodule ProtoHackers.NamedBus do
  @callback subscribe(name :: any()) :: :ok
  @callback unsubscribe(name :: any()) :: :ok
  @callback broadcast(name :: any(), message :: any()) :: :ok
end
