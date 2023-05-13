defmodule ProtoHackers.SpeedDaemon.Request do
  use TypedStruct

  alias ProtoHackers.SpeedDaemon.Request
  alias ProtoHackers.SpeedDaemon.Request.IAmDispatcher
  alias ProtoHackers.SpeedDaemon.Request.IAmCamera
  alias ProtoHackers.SpeedDaemon.Request.Heartbeat
  alias ProtoHackers.SpeedDaemon.Request.WantHeartbeat
  alias ProtoHackers.SpeedDaemon.Request.Ticket
  alias ProtoHackers.SpeedDaemon.Request.Plate
  alias ProtoHackers.SpeedDaemon.Request.Error

  @type outbound :: Error.t() | Ticket.t() | Heartbeat.t()
  @type inbound :: Plate.t() | WantHeartbeat.t() | IAmCamera.t() | IAmDispatcher.t()

  typedstruct module: Error, enforce: true do
    field :message, String.t()
  end

  typedstruct module: Plate, enforce: true do
    field :plate, String.t()
    field :timestamp, non_neg_integer()
  end

  typedstruct module: Ticket, enforce: true do
    field :plate, String.t()
    field :road, non_neg_integer()
    field :mile1, non_neg_integer()
    field :timestamp1, non_neg_integer()
    field :mile2, non_neg_integer()
    field :timestamp2, non_neg_integer()
    field :speed, non_neg_integer()
  end

  typedstruct module: WantHeartbeat, required: true do
    field :interval, non_neg_integer()
  end

  typedstruct module: Heartbeat do
  end

  typedstruct module: IAmCamera, required: true do
    field :road, non_neg_integer()
    field :mile, non_neg_integer()
    field :limit, non_neg_integer()
  end

  typedstruct module: IAmDispatcher, required: true do
    field :roads, [non_neg_integer()]
  end

  @spec encode(Request.outbound()) :: binary()
  def encode(message)

  def encode(%Heartbeat{}) do
    <<65>>
  end

  def encode(%Error{message: msg}) do
    length = String.length(msg)
    <<16, length::unsigned-integer-8, msg::binary>>
  end

  def encode(%Ticket{
        plate: plate,
        road: road,
        mile1: mile1,
        timestamp1: timestamp1,
        mile2: mile2,
        timestamp2: timestamp2,
        speed: speed
      }) do
    plate_length = String.length(plate)

    <<
      33,
      plate_length::unsigned-integer-8,
      plate::binary,
      road::unsigned-integer-16,
      mile1::unsigned-integer-16,
      timestamp1::unsigned-integer-32,
      mile2::unsigned-integer-16,
      timestamp2::unsigned-integer-32,
      speed::unsigned-integer-16
    >>
  end

  @spec decode(input) :: {[Request.inbound()], leftover} when input: binary(), leftover: binary()
  def decode(binary_input)

  def decode(binary) do
    do_decode(binary, [])
  end

  defp do_decode(
         <<
           32,
           length::unsigned-integer-8,
           plate::binary-size(length),
           timestamp::unsigned-integer-32,
           rest::binary
         >>,
         acc
       ) do
    do_decode(rest, acc ++ [%Plate{plate: plate, timestamp: timestamp}])
  end

  defp do_decode(<<64, interval::unsigned-integer-32, rest::binary>>, acc) do
    do_decode(rest, acc ++ [%WantHeartbeat{interval: interval}])
  end

  defp do_decode(
         <<
           128,
           road::unsigned-integer-16,
           mile::unsigned-integer-16,
           limit::unsigned-integer-16,
           rest::binary
         >>,
         acc
       ) do
    do_decode(rest, acc ++ [%IAmCamera{road: road, mile: mile, limit: limit}])
  end

  defp do_decode(<<129, num_roads::unsigned-integer-8, bin_roads::binary>>, acc) do
    {roads, rest} =
      Enum.reduce(
        1..num_roads,
        {[], bin_roads},
        fn _, {roads, <<road::unsigned-integer-16, acc::binary>>} ->
          {[road | roads], acc}
        end
      )

    do_decode(rest, acc ++ [%IAmDispatcher{roads: roads}])
  end

  defp do_decode(binary, acc) do
    {acc, binary}
  end
end
