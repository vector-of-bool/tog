import Logger

defmodule Tog.Client.Cache do
  alias Tog.Client.Cache.Impl
  def start_link do
    Impl.start_link
  end

  def lookup_direct({[_program|_args], _env, _cwd}) do
    :miss
  end

  def lookup_preprocessed(content, inv = {[program|args], env, cwd}) do
    content_hash = :crypto.hash(:md5, content)
    inv_hash = :crypto.hash(:md5, inspect(inv))
    digest = "#{Base.encode16(content_hash)}-#{Base.encode16(inv_hash)}"
    info "Look up with digest #{digest}"
    GenServer.call Impl, {:lookup, digest}
  end

  def save_preprocessed(digest, outfile, res) do
    GenServer.call Impl, {:save, digest, outfile, res}
  end

  defmodule Impl do
    def start_link do
      info "Starting up cache"
      GenServer.start(__MODULE__, :ok, name: __MODULE__)
    end

    def init(:ok) do
      {:ok, %{
        objects: %{}
      }}
    end

    def terminate(_reason, state), do: nil

    def handle_call({:lookup, digest}, _from, state) do
      rep = case Map.fetch(state.objects, digest) do
        :error ->
          info "No cached object matching #{digest}"
          {:miss, digest}
        {:ok, {filepath, res}} ->
          info "Hit on cached object #{filepath}"
          {:hit, digest, {filepath, res}}
      end
      {:reply, rep, state}
    end

    def handle_call({:save, digest, obj_path, exc_res}, _from, state) do
      objects_dir = Application.get_env(:tog_client, :datadir, Application.app_dir(:tog_client, "objects"))
      File.mkdir_p!(objects_dir)
      ext = Path.extname(obj_path)
      saved_path = Path.join(objects_dir, digest <> ext)
      info "Caching object file to #{saved_path}"
      File.copy!(obj_path, saved_path)
      {:reply, :ok, %{objects: Map.put(state.objects, digest, {saved_path, exc_res})}}
    end
  end
end