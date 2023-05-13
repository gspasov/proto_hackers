defmodule ProtoHackers.SimpleBus do
  @callback subscribe() :: :ok
  @callback unsubscribe() :: :ok
  @callback broadcast(message :: any()) :: :ok
end
