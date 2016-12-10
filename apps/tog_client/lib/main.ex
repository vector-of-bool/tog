import Logger

defmodule Tog.Client.Main do
  def start_link do
    spec =
    GenServer.start_link(__MODULE__, :ok, name: Tog.Client.Main)
  end

  def init(:ok), do: {:ok, %{}}

  def terminate(_reason, _state), do: nil

  def handle_call({:request, req}, from, state) do
    case req do
      %{"method" => "compile"} ->
        params = req["params"]
        env = req["environ"]
        cwd = req["working_dir"]
        Task.Supervisor.start_child(Tog.ClientSupervisor, fn ->
          reply = GenServer.call(Tog.Client.Compiler, {:compile, {params, env, cwd}}, 10 * 60 * 1000)
          GenServer.reply(from, {:reply, reply})
        end)
        {:noreply, state}
    end
  end
end