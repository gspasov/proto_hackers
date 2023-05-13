defmodule ProtoHackers.SpeedDaemon.OverWatch do
  @defmodule """
  Knows about all available cameras on all the roads. Therefore responsible for figuring out the
  speed of a plate whenever it crosses a camera.
  If the speed limit has been exceeded, it will fire a ticket Event.
  """

  use FunServer
  use TypedStruct

  alias ProtoHackers.SpeedDaemon
  alias ProtoHackers.SpeedDaemon.OverWatch
  alias ProtoHackers.SpeedDaemon.OverWatch.State
  alias ProtoHackers.SpeedDaemon.OverWatch.Snapshot
  alias ProtoHackers.SpeedDaemon.Ticket
  alias ProtoHackers.SpeedDaemon.Request
  alias ProtoHackers.SpeedDaemon.Request.Plate
  alias ProtoHackers.SpeedDaemon.Request.IAmDispatcher
  alias ProtoHackers.SpeedDaemon.Request.IAmCamera
  alias WarmFuzzyThing.Maybe

  require Logger

  @type day :: non_neg_integer()
  @type tickets :: %{
          {OverWatch.day(), SpeedDaemon.road(), SpeedDaemon.plate(), :pending | :done} =>
            Request.Ticket.t()
        }

  @day_length 86_400
  @seconds_in_an_hour 3600
  @allowed_mph_overhead 0.5

  typedstruct module: Snapshot, required: true do
    field :camera, IAmCamera.t()
    field :plate, Plate.t()
  end

  typedstruct module: State do
    field :dispatcher_clients, %{SpeedDaemon.road() => [pid()]}, default: %{}

    field :observed_plates,
          %{{SpeedDaemon.road(), SpeedDaemon.plate()} => Snapshot.t()},
          default: %{}

    field :tickets, OverWatch.tickets(), default: %{}
  end

  def start_link(_args) do
    FunServer.start_link(__MODULE__, [name: __MODULE__], fn ->
      OverWatch.Bus.subscribe()
      {:ok, %State{}}
    end)
  end

  @impl true
  def handle_info(
        {OverWatch.Bus, {dispatcher_client, %IAmDispatcher{roads: roads}}},
        %State{dispatcher_clients: dispatcher_clients, tickets: tickets} = state
      )
      when is_pid(dispatcher_client) do
    new_dispatchers =
      Enum.reduce(roads, dispatcher_clients, fn road, acc ->
        Map.update(acc, road, [dispatcher_client], fn dispatcher_clients ->
          [dispatcher_client | dispatcher_clients]
        end)
      end)

    new_tickets =
      Enum.into(tickets, %{}, fn
        {{day, road, plate, :pending}, ticket} = ticket_data ->
          if Enum.any?(roads, fn r -> r == road end) do
            Logger.debug("[#{__MODULE__}] Send ticket #{inspect(ticket)}")
            Ticket.Bus.broadcast(dispatcher_client, ticket)
            {{day, road, plate, :done}, ticket}
          else
            ticket_data
          end

        ticket_data ->
          ticket_data
      end)

    {:noreply, %State{state | dispatcher_clients: new_dispatchers, tickets: new_tickets}}
  end

  @impl true
  def handle_info(
        {OverWatch.Bus, {:close, dispatcher_client, %IAmDispatcher{roads: roads}}},
        %State{dispatcher_clients: dispatcher_clients} = state
      )
      when is_pid(dispatcher_client) do
    left_dispatchers =
      roads
      |> Enum.reduce(dispatcher_clients, fn road, acc ->
        Map.update(acc, road, nil, fn clients -> clients -- [dispatcher_client] end)
      end)
      |> Enum.reject(fn
        {_key, []} -> true
        {_key, nil} -> true
        _ -> false
      end)
      |> Enum.into(%{})

    {:noreply, %State{state | dispatcher_clients: left_dispatchers}}
  end

  @impl true
  def handle_info(
        {OverWatch.Bus,
         %Snapshot{
           camera: %IAmCamera{road: road},
           plate: %Plate{plate: plate_text}
         } = snapshot1},
        %State{
          observed_plates: observed_plates,
          tickets: tickets,
          dispatcher_clients: dispatcher_clients
        } = state
      ) do
    {new_observed_plates, new_tickets} =
      case Map.get(observed_plates, {road, plate_text}) do
        nil ->
          op = Map.put(observed_plates, {road, plate_text}, snapshot1)
          {op, tickets}

        snapshot2 ->
          {first_snapshot, second_snapshot} = order_snapshots(snapshot1, snapshot2)

          new_tickets =
            first_snapshot
            |> maybe_tickets(second_snapshot, tickets)
            |> Maybe.fmap(fn tickets ->
              # If there is available Dispatcher, broadcast the Ticket to one Dispatcher.
              # Otherwise just store the Ticket as 'generated'.
              # It will be send as soon as a Dispatcher for that road appears.

              dispatcher_clients
              |> Enum.find(fn {dispatcher_road, _} -> dispatcher_road == road end)
              |> case do
                nil ->
                  Enum.into(tickets, %{}, fn {day, ticket} ->
                    {{day, road, plate_text, :pending}, ticket}
                  end)

                {_key, [client | _clients]} when is_pid(client) ->
                  Enum.each(tickets, fn {day, ticket} ->
                    Logger.debug(
                      "[#{__MODULE__}] On Day #{day} sending Ticket #{inspect(ticket)}"
                    )

                    Ticket.Bus.broadcast_ticket(client, ticket)
                  end)

                  Enum.into(tickets, %{}, fn {day, ticket} ->
                    {{day, road, plate_text, :done}, ticket}
                  end)
              end
            end)
            |> Maybe.fold(tickets, fn new_tickets -> Map.merge(tickets, new_tickets) end)

          op = Map.put(observed_plates, {road, plate_text}, snapshot2)
          {op, new_tickets}
      end

    {:noreply, %State{state | observed_plates: new_observed_plates, tickets: new_tickets}}
  end

  @impl true
  def handle_info({OverWatch.Bus, unexpected_message}, state) do
    Logger.warn("[#{__MODULE__}] Got unexpected message: #{inspect(unexpected_message)}")
    {:noreply, state}
  end

  @spec maybe_tickets(Snapshot.t(), Snapshot.t(), OverWatch.tickets()) ::
          Maybe.t([{day :: non_neg_integer(), Request.Ticket.t()}, ...])
  def maybe_tickets(
        %Snapshot{
          camera: %IAmCamera{road: road, limit: limit, mile: mile1},
          plate: %Plate{timestamp: timestamp1}
        } = first_snapshot,
        %Snapshot{
          camera: %IAmCamera{mile: mile2},
          plate: %Plate{plate: plate, timestamp: timestamp2}
        } = second_snapshot,
        tickets
      ) do
    start_day = calculate_day(timestamp1)
    end_day = calculate_day(timestamp2)
    mph = calculate_mph(first_snapshot, second_snapshot)

    unless speeding?(mph, limit) do
      Logger.debug("[#{__MODULE__}] Should not ticket for speed #{mph}")
      nil
    else
      Enum.reduce(start_day..end_day, [], fn day, acc ->
        if has_been_ticketed_that_day?(day, road, plate, tickets) do
          acc
        else
          [
            {day,
             %Request.Ticket{
               mile1: mile1,
               mile2: mile2,
               road: road,
               plate: plate,
               speed: mph,
               timestamp1: timestamp1,
               timestamp2: timestamp2
             }}
            | acc
          ]
        end
      end)
      |> case do
        [] ->
          Logger.debug(
            "[#{__MODULE__}] The car is already ticketed for all days between #{start_day} and #{end_day}"
          )

          nil

        tickets ->
          Maybe.pure(tickets)
      end
    end
  end

  @spec order_snapshots(Snapshot.t(), Snapshot.t()) :: {Snapshot.t(), Snapshot.t()}
  defp order_snapshots(snapshot1, snapshot2)

  defp order_snapshots(
         %Snapshot{plate: %Plate{timestamp: timestamp1}} = snapshot1,
         %Snapshot{plate: %Plate{timestamp: timestamp2}} = snapshot2
       )
       when timestamp1 > timestamp2 do
    {snapshot2, snapshot1}
  end

  defp order_snapshots(snapshot1, snapshot2), do: {snapshot1, snapshot2}

  defp speeding?(speed, limit), do: speed - limit * 100 > @allowed_mph_overhead

  defp calculate_mph(
         %Snapshot{
           camera: %IAmCamera{mile: mile1, road: road, limit: limit},
           plate: %Plate{timestamp: timestamp1}
         },
         %Snapshot{
           camera: %IAmCamera{mile: mile2, road: road, limit: limit},
           plate: %Plate{timestamp: timestamp2}
         }
       ) do
    distance = if mile1 > mile2, do: mile1 - mile2, else: mile2 - mile1
    time_in_seconds = if mile1 > mile2, do: timestamp1 - timestamp2, else: timestamp2 - timestamp1

    distance
    |> Kernel./(seconds_to_hours(time_in_seconds))
    |> Kernel.*(100)
    |> Kernel.floor()
  end

  defp seconds_to_hours(seconds), do: seconds / @seconds_in_an_hour

  defp calculate_day(timestamp), do: Kernel.floor(timestamp / @day_length)

  defp has_been_ticketed_that_day?(day, road, plate, tickets) do
    Enum.find(tickets, false, fn
      {{^day, ^road, ^plate, _type}, _ticket} -> true
      _ -> false
    end)
  end
end
