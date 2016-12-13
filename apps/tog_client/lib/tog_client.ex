defmodule Tog.Client do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.configure_backend(:console, format: "$time [$level$levelpad] $message\n")
    children = [
      # The cache service manages the cache
      supervisor(Tog.Client.Main, []),
      # worker(Tog.Client.Cache, []),
      # The compiler service processes compile requests
      # worker(Tog.Client.Compiler, []),
      supervisor(Tog.Client.Acceptor, []),
    ]

    opts = [strategy: :one_for_one, name: Tog.Client.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
