defmodule ProtoHackers.UnusualDatabaseProgram.Request do
  @moduledoc false

  use TypedStruct

  typedstruct module: Insert do
    field :key, any()
    field :value, any()
  end

  typedstruct module: Retrieve do
    field :key, any()
  end
end
