defmodule ProtoHackers.SpeedDaemon do
  alias ProtoHackers.SpeedDaemon.Type

  defmodule Type do
    use TypedStruct

    alias ProtoHackers.SpeedDaemon.Type.IAmDispatcher
    alias ProtoHackers.SpeedDaemon.Type.IAmCamera
    alias ProtoHackers.SpeedDaemon.Type.Heartbeat
    alias ProtoHackers.SpeedDaemon.Type.WantHeartbeat
    alias ProtoHackers.SpeedDaemon.Type.Ticket
    alias ProtoHackers.SpeedDaemon.Type.Plate
    alias ProtoHackers.SpeedDaemon.Type.Error

    @type t :: Error | Plate | Ticket | WantHeartbeat | Heartbeat | IAmCamera | IAmDispatcher

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
  end

  @spec parse(binary()) :: {Type.t() | :end, binary()}
  def parse(<<16, length::unsigned-integer-8, msg::binary-size(length), rest::binary>>) do
    {%Type.Error{message: msg}, rest}
  end

  def parse(<<
        32,
        length::unsigned-integer-8,
        plate::binary-size(length),
        timestamp::unsigned-integer-32,
        rest::binary
      >>) do
    {%Type.Plate{plate: plate, timestamp: timestamp}, rest}
  end

  def parse(<<
        33,
        length::unsigned-integer-8,
        plate::binary-size(length),
        road::unsigned-integer-16,
        mile1::unsigned-integer-16,
        timestamp1::unsigned-integer-32,
        mile2::unsigned-integer-16,
        timestamp2::unsigned-integer-32,
        speed::unsigned-integer-16,
        rest::binary
      >>) do
    {%Type.Ticket{
       plate: plate,
       road: road,
       mile1: mile1,
       timestamp1: timestamp1,
       mile2: mile2,
       timestamp2: timestamp2,
       speed: speed
     }, rest}
  end

  def parse(<<64, interval::unsigned-integer-32, rest::binary>>) do
    {%Type.WantHeartbeat{interval: interval}, rest}
  end

  def parse(<<65, rest::binary>>) do
    {%Type.Heartbeat{}, rest}
  end

  def parse(<<
        128,
        road::unsigned-integer-16,
        mile::unsigned-integer-16,
        limit::unsigned-integer-16,
        rest::binary
      >>) do
    {%Type.IAmCamera{road: road, mile: mile, limit: limit}, rest}
  end

  def parse(<<129, num_roads::unsigned-integer-8, bin_roads::binary>>) do
    {roads, rest} =
      Enum.reduce(
        1..num_roads,
        {[], bin_roads},
        fn _, {roads, <<road::unsigned-integer-16, acc::binary>>} ->
          {[road | roads], acc}
        end
      )

    {%Type.IAmDispatcher{roads: roads}, rest}
  end

  def parse(binary) do
    {:end, binary}
  end
end
