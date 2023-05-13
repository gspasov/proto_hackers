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
  alias ProtoHackers.SpeedDaemon.OverWatch.Violation
  alias ProtoHackers.SpeedDaemon.Ticket
  alias ProtoHackers.SpeedDaemon.Request
  alias ProtoHackers.SpeedDaemon.Request.Plate
  alias ProtoHackers.SpeedDaemon.Request.IAmDispatcher
  alias ProtoHackers.SpeedDaemon.Request.IAmCamera
  alias WarmFuzzyThing.Maybe

  require Logger

  @type day :: non_neg_integer()
  @type violations :: %{{SpeedDaemon.road(), SpeedDaemon.plate()} => Violation.t()}
  @type snapshots :: %{{SpeedDaemon.road(), SpeedDaemon.plate()} => Snapshot.t()}

  @day_length 86_400
  @seconds_in_an_hour 3600
  @allowed_mph_overhead 0.5

  typedstruct module: Violation, required: true do
    field :days, [non_neg_integer(), ...]
    field :ticket, Request.Ticket.t()
    field :type, :pending | :done
  end

  typedstruct module: Snapshot, required: true do
    field :camera, IAmCamera.t()
    field :plate, Plate.t()
  end

  typedstruct module: State do
    field :dispatcher_clients, %{SpeedDaemon.road() => [pid()]}, default: %{}
    field :snapshots, OverWatch.snapshots(), default: %{}
    field :violations, OverWatch.violations(), default: %{}
  end

  def start_link(_args) do
    FunServer.start_link(__MODULE__, [name: __MODULE__], fn ->
      OverWatch.Bus.subscribe()
      {:ok, %State{}}
    end)
  end

  @impl true
  def handle_info(
        {OverWatch.Bus, {:add, dispatcher_client, %IAmDispatcher{roads: roads}} = dispatcher},
        %State{dispatcher_clients: dispatcher_clients, violations: violations} = state
      )
      when is_pid(dispatcher_client) do
    Logger.debug("[#{__MODULE__}] Adding dispatcher #{inspect(dispatcher)}")

    new_dispatchers =
      Enum.reduce(roads, dispatcher_clients, fn road, acc ->
        Map.update(acc, road, [dispatcher_client], fn dispatcher_clients ->
          [dispatcher_client | dispatcher_clients]
        end)
      end)

    new_violations =
      Enum.into(violations, %{}, fn
        {{road, _plate} = key, %Violation{ticket: ticket} = violation} = ticket_data ->
          if Enum.any?(roads, fn r -> r == road end) do
            Logger.debug(
              "[#{__MODULE__}] #{inspect(dispatcher_client)} Send[1] Violation #{inspect(violation)}"
            )

            Ticket.Bus.broadcast(dispatcher_client, ticket)
            {key, %Violation{violation | type: :done}}
          else
            ticket_data
          end

        ticket_data ->
          ticket_data
      end)

    {:noreply, %State{state | dispatcher_clients: new_dispatchers, violations: new_violations}}
  end

  @impl true
  def handle_info(
        {OverWatch.Bus, {:remove, dispatcher_client, %IAmDispatcher{roads: roads}} = dispatcher},
        %State{dispatcher_clients: dispatcher_clients} = state
      )
      when is_pid(dispatcher_client) do
    Logger.debug("[#{__MODULE__}] Removing dispatcher #{inspect(dispatcher)}")

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
         } = new_snapshot},
        %State{
          snapshots: snapshots,
          violations: violations,
          dispatcher_clients: dispatcher_clients
        } = state
      ) do
    Logger.debug("[#{__MODULE__}] New snapshot #{inspect(new_snapshot)}")

    {new_snapshots, new_violations} =
      case Map.get(snapshots, {road, plate_text}) do
        nil ->
          new_snapshots = Map.put(snapshots, {road, plate_text}, new_snapshot)
          {new_snapshots, violations}

        old_snapshot ->
          {earlier_snapshot, later_snapshot} = order_snapshots(old_snapshot, new_snapshot)

          new_violations =
            earlier_snapshot
            |> maybe_violation(later_snapshot, violations)
            |> Maybe.fmap(fn %Violation{ticket: ticket} = violation ->
              # If there is available Dispatcher, broadcast the Ticket to one Dispatcher.
              # Otherwise just store the Ticket as 'generated'.
              # It will be send as soon as a Dispatcher for that road appears.

              dispatcher_clients
              |> Enum.find(:not_found, fn {dispatcher_road, _} -> dispatcher_road == road end)
              |> tap(fn dispatcher_for_road ->
                Logger.debug(
                  "[#{__MODULE__}] Found Dispatcher for violation: #{inspect(dispatcher_for_road)}"
                )
              end)
              |> case do
                :not_found ->
                  violation

                {_key, [client | _clients]} when is_pid(client) ->
                  Logger.debug(
                    "[#{__MODULE__}] #{inspect(client)} Send[2] Violation #{inspect(violation)}"
                  )

                  Ticket.Bus.broadcast_ticket(client, ticket)

                  %Violation{violation | type: :done}
              end
            end)
            |> Maybe.fold(violations, fn %Violation{days: new_days} = new_violation ->
              Map.update(
                violations,
                {road, plate_text},
                new_violation,
                fn %Violation{days: old_days} ->
                  %Violation{new_violation | days: old_days ++ new_days}
                end
              )
            end)

          {snapshots, new_violations}
      end

    {:noreply, %State{state | snapshots: new_snapshots, violations: new_violations}}
  end

  @impl true
  def handle_info({OverWatch.Bus, unexpected_message}, state) do
    Logger.warn("[#{__MODULE__}] Got unexpected message: #{inspect(unexpected_message)}")
    {:noreply, state}
  end

  @spec maybe_violation(Snapshot.t(), Snapshot.t(), OverWatch.violations()) ::
          Maybe.t(Violation.t())
  def maybe_violation(
        %Snapshot{
          camera: %IAmCamera{road: road, limit: limit, mile: mile1},
          plate: %Plate{timestamp: timestamp1}
        } = first_snapshot,
        %Snapshot{
          camera: %IAmCamera{mile: mile2},
          plate: %Plate{plate: plate, timestamp: timestamp2}
        } = second_snapshot,
        violations
      ) do
    start_day = calculate_day(timestamp1)
    end_day = calculate_day(timestamp2)
    days_to_ticket = Enum.to_list(start_day..end_day)
    mph = calculate_mph(first_snapshot, second_snapshot)

    if speeding?(mph, limit) and
         not has_been_ticketed_these_days?(days_to_ticket, plate, violations) do
      Maybe.pure(%Violation{
        type: :pending,
        days: days_to_ticket,
        ticket: %Request.Ticket{
          mile1: mile1,
          mile2: mile2,
          road: road,
          plate: plate,
          speed: mph,
          timestamp1: timestamp1,
          timestamp2: timestamp2
        }
      })
    else
      Logger.debug(
        "[#{__MODULE__}] Should not ticket #{plate} violation: #{Enum.find(violations, fn {key, _val} -> key == {road, plate} end)}"
      )

      nil
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

    time_in_seconds =
      if timestamp1 > timestamp2, do: timestamp1 - timestamp2, else: timestamp2 - timestamp1

    distance
    |> Kernel./(seconds_to_hours(time_in_seconds))
    |> Kernel.*(100)
    |> Kernel.floor()
  end

  defp seconds_to_hours(seconds), do: seconds / @seconds_in_an_hour

  defp calculate_day(timestamp), do: Kernel.floor(timestamp / @day_length)

  defp has_been_ticketed_these_days?(days_to_ticket, plate, violations) do
    Enum.any?(violations, fn
      {{_road, ^plate}, %Violation{days: ticketed_days}} ->
        # Car should not be ticketed for days that span previous ticket
        Enum.any?(days_to_ticket, fn day -> Enum.member?(ticketed_days, day) end)

      _ ->
        false
    end)
  end
end
