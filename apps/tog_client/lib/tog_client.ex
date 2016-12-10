defmodule Tog.Client do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.configure_backend(:console, format: "$time [$level$levelpad] $message\n")
    children = [
      # worker(Tog.Client.Worker, [arg1, arg2, arg3]),
      worker(Tog.Client.Cache, []),
      worker(Tog.Client.Compiler, []),
      worker(Tog.Client.Main, []),
      supervisor(Task.Supervisor, [[name: Tog.ClientSupervisor]]),
      worker(Tog.Client.Acceptor, []),
    ]

    opts = [strategy: :one_for_one, name: Tog.Client.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
