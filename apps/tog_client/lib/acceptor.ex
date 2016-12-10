import Logger

alias Tog.Client.ExecutionResult

defmodule Tog.Client.Acceptor do
  def start_link do
    info "Starting tog client service"
    {:ok, socket} = :gen_tcp.listen(8263, [:binary, packet: 4, active: false, reuseaddr: true])
    pid = spawn_link(fn ->
      accept(socket)
    end)
    {:ok, pid}
  end

  def accept(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info "Got new client #{inspect client}"
    {:ok, pid} = Task.Supervisor.start_child(Tog.ClientSupervisor, fn ->
      receive do
        :go -> serve(client)
      end
    end)
    :ok = :gen_tcp.controlling_process(client, pid)
    send pid, :go
    accept(socket)
  end

  def serve(client) do
    case :gen_tcp.recv(client, 0) do
      {:error, :closed} ->
        Logger.info("Client has disconnected")
        nil
      {:error, what} ->
        Logger.error("Failed to read data from client: #{inspect what}")
        nil
      {:ok, data} ->
        Logger.info("Got a message!")
        case Poison.decode(data) do
          {:ok, items} ->
            {:reply, data = %ExecutionResult{}} = GenServer.call(Tog.Client.Main, {:request, items}, 10 * 60 * 1000)
            databuf = Poison.encode!(data)
            :ok = :gen_tcp.send(client, databuf)
            serve(client)
          {:error, what} ->
            Logger.error("Invalid JSON data from client #{inspect client}: #{inspect what}")
            nil
        end
    end
  end
end