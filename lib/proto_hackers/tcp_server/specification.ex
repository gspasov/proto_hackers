defmodule ProtoHackers.TcpServer.Specification do
  @moduledoc false

  use TypedStruct

  alias ProtoHackers.TcpServer.Specification

  typedstruct module: Tcp do
    field :port, non_neg_integer(), enforce: true
    field :options, [:inet.inet_backend() | :gen_tcp.listen_option()], enforce: true
    field :task_supervisor, atom(), enforce: true
    field :on_receive_callback, (:gen_tcp.socket(), iodata() -> any), enforce: true
    field :on_connect_callback, (:gen_tcp.socket() -> any), default: &Specification.callback/1
    field :on_close_callback, (:gen_tcp.socket() -> any), default: &Specification.callback/1
    field :receive_length, non_neg_integer(), default: 0
  end

  typedstruct module: Server do
    field :options, GenServer.options()
  end

  typedstruct enforce: true do
    field :tcp, Tcp.t()
    field :server, Server.t()
  end

  @spec callback(:gen_tcp.socket()) :: :ok
  def callback(_), do: :ok
end
