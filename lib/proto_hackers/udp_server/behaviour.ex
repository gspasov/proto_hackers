defmodule ProtoHackers.UdpServer.Behaviour do
  @moduledoc """
  Callbacks for all UdpServer implementers
  """

  @callback on_udp_receive(packet :: any()) :: :ok
  @callback on_udp_open(socket :: :gen_udp.socket()) :: :ok
  @callback on_udp_close() :: :ok

  @optional_callbacks on_udp_open: 1, on_udp_close: 0
end
