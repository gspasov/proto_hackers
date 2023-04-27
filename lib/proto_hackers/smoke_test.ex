defmodule ProtoHackers.SmokeTest do
  @moduledoc false

  alias ProtoHackers.TcpServer

  def on_receive_callback(socket, packet) do
    TcpServer.tcp_send(socket, packet)
  end
end
