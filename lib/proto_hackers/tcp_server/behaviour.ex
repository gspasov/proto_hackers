defmodule ProtoHackers.TcpServer.Behaviour do
  @moduledoc """
  Callbacks for all TcpServer implementers
  """

  @callback on_tcp_receive(socket :: :gen_tcp.socket(), packet :: any()) :: any()
  @callback on_tcp_connect(socket :: :gen_tcp.socket()) :: any()
  @callback on_tcp_close(socket :: :gen_tcp.socket()) :: any()

  @optional_callbacks on_tcp_connect: 1, on_tcp_close: 1
end
