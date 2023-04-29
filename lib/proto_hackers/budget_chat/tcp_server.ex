defmodule ProtoHackers.BudgetChat.TcpServer do
  @moduledoc false

  alias ProtoHackers.TcpServer
  alias ProtoHackers.TcpServer.Specification
  alias ProtoHackers.BudgetChat

  def spec(opts) do
    %{
      id: __MODULE__,
      start:
        {TcpServer, :start_link,
         [
           %Specification{
             tcp: %Specification.Tcp{
               port: Keyword.fetch!(opts, :port),
               task_supervisor: Keyword.fetch!(opts, :task_supervisor),
               options: [mode: :binary, active: false, packet: :line],
               on_receive_callback: &BudgetChat.on_receive_callback/2,
               on_connect_callback: &BudgetChat.on_connect_callback/1,
               on_close_callback: &BudgetChat.on_close_callback/1
             },
             server: %Specification.Server{
               options: [name: __MODULE__]
             }
           }
         ]}
    }
  end
end
