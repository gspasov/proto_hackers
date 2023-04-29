defmodule ProtoHackers.PrimeTime do
  @moduledoc false

  use FunServer
  require Logger

  alias ProtoHackers.TcpServer
  alias ProtoHackers.Utils
  alias WarmFuzzyThing.Either

  def start_link(_args) do
    FunServer.start_link(__MODULE__, [name: __MODULE__], fn -> {:ok, %{packet_part: ""}} end)
  end

  def on_tcp_receive(socket, packet) do
    FunServer.async(__MODULE__, fn state ->
      new_state = Map.update(state, :packet_portion, packet, fn prev -> prev <> packet end)

      new_state =
        if String.last(packet) == "\n" do
          handle_packet(socket, new_state.packet_portion)
          %{new_state | packet_portion: ""}
        else
          new_state
        end

      {:noreply, new_state}
    end)
  end

  defp handle_packet(socket, packet) do
    packet
    |> String.replace("\n", "")
    |> Jason.decode()
    |> Either.bind(&validate_request/1)
    |> Either.fmap(&Utils.prime?/1)
    |> Either.fmap(&build_response/1)
    |> Either.bind(&Jason.encode/1)
    |> case do
      {:ok, response} ->
        Logger.debug(
          "[#{__MODULE__}] Successfully parsed request and returning response #{inspect(response)}"
        )

        TcpServer.send(socket, "#{response}\n")

      {:error, reason} ->
        Logger.warn("[#{__MODULE__}] Failed to parse request or response with #{inspect(reason)}")
        TcpServer.send(socket, "malformed_request\n")
    end
  end

  @spec build_response(prime? :: boolean()) :: %{method: String.t(), prime: boolean()}
  defp build_response(prime?) do
    %{method: "isPrime", prime: prime?}
  end

  defp validate_request(%{"method" => "isPrime", "number" => number}) when is_number(number) do
    {:ok, trunc(number)}
  end

  defp validate_request(_) do
    {:error, :malformed_request}
  end
end
