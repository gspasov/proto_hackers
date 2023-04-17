defmodule ProtoHackers.PrimeTime do
  require Logger

  alias ProtoHackers.TcpServer
  alias WarmFuzzyThing.Either

  def spec(opts) do
    %{
      id: __MODULE__,
      start:
        {TcpServer, :start_link,
         [
           %{
             tcp: %{
               port: Keyword.get(opts, :port, 4001),
               options: [{:mode, :binary}, {:active, false}, {:packet, :line}],
               packet_handler: &packet_handler/2
             },
             server: %{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end

  def packet_handler(socket, packet) do
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

        TcpServer.send(socket, "#{response}\n")

      {:error, reason} ->
        Logger.warn("[#{__MODULE__}] Failed to parse request or response with #{inspect(reason)}")
        TcpServer.send(socket, "malformed_request\n")
    end
  end

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
