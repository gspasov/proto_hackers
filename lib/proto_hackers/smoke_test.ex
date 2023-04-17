defmodule ProtoHackers.SmokeTest do
  require Logger

  alias ProtoHackers.TcpServer

  def packet_handler(socket, packet) do
    TcpServer.tcp_send(socket, packet)
  end
end
