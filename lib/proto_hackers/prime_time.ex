defmodule ProtoHackers.PrimeTime do
  use FunServer
  require Logger

  alias ProtoHackers.TcpServer
  alias WarmFuzzyThing.Either

  def start_link(_args) do
    FunServer.start_link(__MODULE__, [name: __MODULE__], fn -> {:ok, %{packet_part: ""}} end)
  end

  def on_receive_callback(socket, packet) do
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
    |> Either.fmap(&prime?/1)
    |> Either.fmap(&build_response/1)
    |> Either.bind(&Jason.encode/1)
    |> case do
      {:ok, response} ->
        Logger.debug(
          "[#{__MODULE__}] Successfully parsed request and returning response #{inspect(response)}"
        )

        TcpServer.tcp_send(socket, "#{response}\n")

      {:error, reason} ->
        Logger.warn("[#{__MODULE__}] Failed to parse request or response with #{inspect(reason)}")
        TcpServer.tcp_send(socket, "malformed_request\n")
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

  @spec prime?(number :: integer()) :: boolean()
  def prime?(num)

  def prime?(num) when num <= 1, do: false
  def prime?(num) when num in [2, 3], do: true
  def prime?(num) when rem(num, 2) == 0 or rem(num, 3) == 0, do: false

  def prime?(num) do
    not Enum.any?(5..trunc(:math.sqrt(num))//6, fn n ->
      rem(num, n) == 0 or rem(num, n + 2) == 0
    end)
  end
end
