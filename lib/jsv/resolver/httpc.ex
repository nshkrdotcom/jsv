defmodule JSV.Resolver.Httpc do
  require Logger
  @behaviour JSV.Resolver

  @moduledoc """
  A `JSV.Resolver` implementation that will fetch the schemas from the web with
  the help of the `:httpc` module.

  This resolver must be configured when used to build a schema. It also needs a
  proper JSON library to decode fetched schemas:

  * From Elixir 1.18, the `JSON` module is automatically available in the
    standard library.
  * JSV can use [Jason](https://hex.pm/packages/jason) if listed in your
    dependencies with the  `"~> 1.0"` requirement.
  * JSV also supports [Poison](https://hex.pm/packages/poison) with the `"~> 6.0
    or ~> 5.0"` requirement.

  ### Options

  This resolver supports the following options:

  - `:allowed_prefixes` - This option is mandatory and contains the allowed
    prefixes to download from.
  - `:cache_dir` - The path of a directory to cache downloaded resources. The
    default value can be retrieved with `default_cache_dir/0` and is based on
    `System.tmp_dir!/0`. The option also accepts `false` to disable that cache.
    Note that there is no cache expiration mechanism.

  ### Example

      resolver_opts = [allowed_prefixes: ["https://json-schema.org/"], cache_dir: "_build/custom/dir"]
      JSV.build(schema, resolver: {JSV.Resolver.BuiltIn, resolver_opts})

  """

  @doc false
  # Used in scripts for development and experiments
  @spec as_default :: {module, keyword()}
  def as_default do
    {JSV.Resolver.BuiltIn, allowed_prefixes: ["https://json-schema.org/"]}
  end

  @impl true
  def resolve("http://" <> _ = url, opts) do
    allow_and_resolve(url, opts)
  end

  def resolve("https://" <> _ = url, opts) do
    allow_and_resolve(url, opts)
  end

  def resolve(url, _opts) do
    {:error, {:invalid_scheme, url}}
  end

  defp allow_and_resolve(url, opts) do
    allowed_prefixes = Keyword.fetch!(opts, :allowed_prefixes)
    cache_dir = Keyword.get_lazy(opts, :cache_dir, &default_cache_dir/0)

    with :ok <- check_allowed(url, allowed_prefixes) do
      do_resolve(url, make_disk_cache(url, cache_dir))
    end
  end

  defp check_allowed(url, allowed_prefixes) do
    if Enum.any?(allowed_prefixes, &String.starts_with?(url, &1)) do
      :ok
    else
      {:error, {:restricted_url, url}}
    end
  end

  defp do_resolve(url, disk_cache) do
    disk_cached_http_get(url, disk_cache)
  end

  defp disk_cached_http_get(url, disk_cache) do
    with {:ok, json} <- fetch_disk_or_http(url, disk_cache) do
      JSV.Codec.decode(json)
    end
  end

  defp fetch_disk_or_http(url, disk_cache) do
    case disk_cache.(:fetch) do
      {:ok, json} ->
        {:ok, json}

      {:error, :no_cache} ->
        case http_get(url) do
          {:ok, json} ->
            :ok = disk_cache.({:write!, json})
            {:ok, json}

          {:error, _} = err ->
            err
        end
    end
  end

  defp http_get(url) do
    Logger.debug("Downloading JSON schema #{url}")

    headers = []
    http_options = []

    url = String.to_charlist(url)

    http_result = :httpc.request(:get, {url, headers}, http_options, body_format: :binary)

    case http_result do
      {:ok, {{_, status, _}, _, body}} when status == 200 -> {:ok, body}
      {:ok, {{_, status, _}, _, _body}} -> {:error, {:http_status, status, url}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp make_disk_cache(_url, false) do
    fn
      :fetch -> {:error, :no_cache}
      {:write!, _} -> :ok
    end
  end

  defp make_disk_cache(url, cache_dir) when is_binary(cache_dir) do
    path = url_to_cache_path(url, cache_dir)
    :ok = ensure_cache_dir(Path.dirname(path))

    fn
      :fetch ->
        case File.read(path) do
          {:ok, json} -> {:ok, json}
          {:error, :enoent} -> {:error, :no_cache}
          # For other disk errors we better raise, the cache directory is
          # misconfigured
          {:error, _} -> File.read!(path)
        end

      {:write!, json} ->
        File.write!(path, json)
    end
  end

  @doc false
  def url_to_cache_path(url, cache_dir) do
    %{scheme: scheme, host: host, path: path} = URI.parse(url)
    sub_dir = Path.join(cache_dir, "#{scheme}-#{host}")
    filename = "#{slugify(String.trim_leading(path, "/"))}-#{hash_url(url)}.json"

    Path.join(sub_dir, filename)
  end

  defp slugify(<<c::utf8, rest::binary>>) when c in ?a..?z when c in ?A..?Z when c in ?0..?9 when c in [?-, ?_] do
    <<c::utf8>> <> slugify(rest)
  end

  defp slugify(<<_::utf8, rest::binary>>) do
    "-" <> slugify(rest)
  end

  defp slugify(<<>>) do
    ""
  end

  defp hash_url(url) do
    Base.encode32(:crypto.hash(:sha, url), padding: false)
  end

  @doc """
  Returns the default directory used by the disk-based cache.
  """
  @spec default_cache_dir :: binary
  def default_cache_dir do
    Path.join(System.tmp_dir!(), "jsv-resolver-http-cache")
  end

  defp ensure_cache_dir(dir) do
    case File.mkdir_p(dir) do
      :ok ->
        :ok

      {:error, reason} ->
        raise "could not create cache dir #{inspect(dir)} for #{inspect(__MODULE__)}: #{inspect(reason)}"
    end
  end
end
