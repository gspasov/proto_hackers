defmodule ProtoHackers.TcpServer.Specification do
  @moduledoc false

  use TypedStruct

  alias ProtoHackers.TcpServer.Specification

  @type on_tcp_connect :: (:gen_tcp.socket() -> :ok)
  @type on_tcp_receive :: (:gen_tcp.socket(), any() -> :ok)
  @type on_tcp_close :: on_tcp_connect()

  typedstruct module: Tcp do
    field :port, non_neg_integer(), enforce: true
    field :options, [:inet.inet_backend() | :gen_tcp.listen_option()], enforce: true
    field :task_supervisor, atom(), enforce: true
    field :on_tcp_receive, Specification.on_tcp_receive(), enforce: true
    field :on_tcp_connect, Specification.on_tcp_connect(), default: &Specification.callback/1
    field :on_tcp_close, Specification.on_tcp_close(), default: &Specification.callback/1
    field :receive_length, non_neg_integer(), default: 0
  end

  typedstruct module: Server do
    field :options, GenServer.options(), default: []
  end

  typedstruct enforce: true do
    field :tcp, Tcp.t()
    field :server, Server.t()
  end

  def callback(_), do: :ok
end
