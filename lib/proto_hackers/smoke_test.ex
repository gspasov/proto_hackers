defmodule ProtoHackers.SmokeTest do
  @moduledoc false

  alias ProtoHackers.TcpServer

  def on_tcp_receive(socket, packet) do
    TcpServer.send(socket, packet)
  end
end
