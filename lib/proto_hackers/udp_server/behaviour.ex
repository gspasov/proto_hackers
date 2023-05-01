defmodule ProtoHackers.UdpServer.Behaviour do
  @moduledoc """
  Callbacks for all UdpServer implementers
  """

  @callback on_udp_receive(socket :: :gen_udp.socket(), packet :: any()) :: :ok
end
