import Logger

defmodule Tog.Client.ExecutionResult do
  defstruct retc: 0, stdout: "", stderr: ""
end

defmodule Tog.Client.Compiler do
  alias Tog.Client.{ExecutionResult, Cache, Compiler}
  def start_link do
    import Supervisor.Spec
    children = [
      supervisor(Task.Supervisor, [[name: Tog.Client.Compiler.TaskSupervisor]]),
      worker(Tog.Client.Cache, []),
      worker(GenServer, [__MODULE__, :ok, [name: Tog.Client.Compiler]]),
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: Tog.Client.Compiler.Supervisor)
  end

  def init(:ok), do: {:ok, %{}}

  def terminate(_reason, _state), do: nil

  def handle_call({:compile, inv = {[program|args], env, cwd}}, from, state) do
    Task.Supervisor.start_child(Tog.Client.Compiler.TaskSupervisor, fn ->
      info "Looking up compile"
      case Cache.lookup_direct(inv) do
        {:hit, res} -> {:reply, res, state}
        :miss ->
          case _preprocess(inv) do
            {source, _retc = 0} ->
              outfile = _output_file(program, args, cwd)
              case Cache.lookup_preprocessed(source, inv) do
                {:hit, _digest, {filepath, res}} ->
                  info "Found old compiled object: #{filepath}"
                  File.copy!(filepath, outfile)
                  GenServer.reply(from, res)
                {:miss, digest} ->
                  info "Invoking compiler #{program} with arguments #{inspect args}"
                  {output, retc} = System.cmd(program, args, env: env, cd: cwd)
                  result = %ExecutionResult{
                    stdout: output,
                    retc: retc,
                  }
                  if retc == 0 do
                    Cache.save_preprocessed(digest, outfile, result)
                  end
                  GenServer.reply(from, result)
              end
            {output, retc} ->
              GenServer.reply(from, %ExecutionResult{stdout: output, retc: retc})
          end
      end
    end)
    {:noreply, state}
  end

  defp _output_file(program, args, cwd) do
    relative = if String.ends_with?(program, "cl.exe") do
      hd Enum.filter_map(args, fn
        "/Fo" <> _outfile -> true
        _ -> false
      end, fn
        "/Fo" <> opath -> opath
      end)
    else
      raise "Don't know what I'm doing."
    end
    Path.absname(relative, cwd)
  end

  defp _preprocess(inv = {[program|args], env, cwd}) do
    new_args = _get_preprocessing_args(program, args)
    info "Old #{inspect args}"
    info "New #{inspect new_args}"
    System.cmd(program, new_args, env: env, cd: cwd)
  end

  defp _get_preprocessing_args(compiler, args) do
    if String.ends_with?(compiler, "cl.exe") do
      info "Old args arg #{inspect args}"
      pruned = Enum.filter(args, fn
        # Remove argumentst that are not necessary or may interfere with
        # preprocessing
        "/F" <> _rest -> false
        "/Z" <> _rest -> false
        "/O" <> _rest -> false
        "/RTC" <> _rest -> false
        "-F" <> _rest -> false
        "/showIncludes" -> false
        _ -> true
      end)
      info "New args are #{inspect pruned}"
      pruned ++ ["/E"]
    else
      raise "Don't know this compiler!"
    end
  end
end