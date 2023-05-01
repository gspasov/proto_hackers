defmodule ProtoHackers.UdpServer.Specification do
  use TypedStruct

  alias ProtoHackers.UdpServer.Specification

  # @type on_udp_connect :: (:gen_tcp.socket() -> :ok)
  @type on_udp_receive :: (:gen_udp.socket(), any() -> :ok)
  # @type on_udp_close :: on_tcp_connect()

  typedstruct module: Udp do
    field :port, non_neg_integer(), enforce: true
    field :options, :inet.inet_backend() | :gen_udp.open_option(), enforce: true
    field :on_udp_receive, Specification.on_udp_receive(), enforce: true
  end

  typedstruct module: Server do
    field :options, GenServer.options(), default: []
  end

  typedstruct enforce: true do
    field :tcp, Tcp.t()
    field :server, Server.t()
  end
end
