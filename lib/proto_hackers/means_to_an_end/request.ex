defmodule ProtoHackers.MeansToAnEnd.Request do
  @moduledoc """
  Represents a single request
  """

  use TypedStruct

  alias ProtoHackers.MeansToAnEnd.Request
  alias WarmFuzzyThing.Either

  @type t :: Insert.t() | Query.t()

  typedstruct module: Insert, enforce: true do
    field :timestamp, :integer
    field :price, :integer
  end

  typedstruct module: Query, enforce: true do
    field :max_timestamp, :integer
    field :min_timestamp, :integer
  end

  @spec parse(<<_::72>>) :: Either.t(:invalid_request, Request.t())
  def parse(binary)

  def parse(<<?Q, min_timestamp::big-signed-integer-32, max_timestamp::big-signed-integer-32>>) do
    {:ok, %Request.Query{max_timestamp: max_timestamp, min_timestamp: min_timestamp}}
  end

  def parse(<<?I, timestamp::big-signed-integer-32, price::big-signed-integer-32>>) do
    {:ok, %Request.Insert{timestamp: timestamp, price: price}}
  end

  def parse(_invalid_request) do
    {:error, :invalid_request}
  end
end
