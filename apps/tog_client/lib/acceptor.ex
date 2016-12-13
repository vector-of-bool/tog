import Logger

defmodule Tog.Client.Acceptor do
  @doc """
  This module accepts connections on localhost and dispatches requests to the
  main server. It's primary purpose is to serialize/deserialize requests to and
  from clients.'
  """
  def start_link do
    import Supervisor.Spec
    children = [
      supervisor(Task.Supervisor, [[name: Tog.Acceptor.ClientSupervisor]]),
      worker(Task, [__MODULE__, :entry, []]),
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: Tog.Client.Acceptor.Supervisor)
  end
  def entry do
    port = Application.get_env(:tog_client, :"listen.port", 8263)
    info "Starting the tog client acceptor service. Listening on port #{port}."
    # We listen on port 8263, hardcoded ATM. We use a four byte size header.
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: 4, active: false, reuseaddr: true])
    # Start accepting connections
    accept(socket)
  end

  def accept(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info "Got new client #{inspect client}"
    {:ok, pid} = Task.Supervisor.start_child(Tog.Acceptor.ClientSupervisor, fn ->
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
            {:reply, data} = GenServer.call(Tog.Client.Main, {:request, items}, 10 * 60 * 1000)
            databuf = Poison.encode!(data)
            :ok = :gen_tcp.send(client, databuf)
            # Keep serving the client until they disconnect
            serve(client)
          {:error, what} ->
            Logger.error("Invalid JSON data from client #{inspect client}: #{inspect what}")
            # If the client sends bad data. Drop this client. We don't want to
            # talk to them anymore
            nil
        end
    end
  end
end