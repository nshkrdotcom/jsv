defmodule JSV.Resolver.BuiltIn do
  alias JSV.Resolver.Cache
  require Logger

  @moduledoc """
  This is the built-in resolver provided to simplify building schemas. This is
  an HTTP resolver that will attempt resolve resources with an HTTP GET call to
  the given URI.

  To use this resolver, you must provide a list of allowed prefixes. The
  resolver will not attempt to fetch URLs that do not start with one of those
  prefixes.

  The resolver uses two caches: a persistent cache on the disk that lives
  through multiple runtimes and compilations, and a memory cache that is only
  used within the same runtime, _i.e._ one compilation or one execution of your
  application.

  Note that there is no time-to-live at the moment, cache is _forever_ in both
  cases: until the files are deleted in the case of the disk cache, or until the
  runtime is shut down for the memory cache.

  ### Options

  This resolver supports the following options:

  - `:allowed_prefixes` - This option is mandatory and contains the allowed
    prefixes to download from.
  - `:cache_dir` - The path of a directory to cache downloaded resources. The
    default value can be retrieved with `default_cache_dir/0` and is based on
    `System.tmp_dir!/0`. The option also accepts `false` to disable that cache.

  ### Example

      resolver_opts = [allowed_prefixes: ["https://json-schema.org/"], cache_dir: "_build/custom/dir"]
      JSV.build(schema, resolver: {JSV.Resolver.BuiltIn, resolver_opts})
  """

  @behaviour JSV.Resolver

  @doc false
  # Used in scripts for development and experiments
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

    with :ok <- check_allowed(url, allowed_prefixes),
         {:ok, uri} <- check_fragment(url) do
      do_resolve(url, make_disk_cache(uri, url, cache_dir))
    end
  end

  defp check_allowed(url, allowed_prefixes) do
    if Enum.any?(allowed_prefixes, &String.starts_with?(url, &1)) do
      :ok
    else
      {:error, {:restricted_url, url}}
    end
  end

  defp check_fragment(url) do
    case URI.parse(url) do
      %{query: nil, fragment: frag} = uri when frag in [nil, ""] -> {:ok, uri}
      _ -> {:error, {:unsupported_url, url}}
    end
  end

  defp do_resolve(url, disk_cache) do
    if compile_time?() do
      disk_cached_http_get(url, disk_cache)
    else
      Cache.get_or_generate(Cache, {__MODULE__, url}, fn -> disk_cached_http_get(url, disk_cache) end)
    end
  end

  defp compile_time? do
    Code.can_await_module_compilation?()
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

  defp make_disk_cache(_uri, _url, false) do
    fn
      :fetch -> {:error, :no_cache}
      {:write!, _} -> :ok
    end
  end

  defp make_disk_cache(uri, url, cache_dir) when is_binary(cache_dir) do
    # To speed up compilation of projects with a lot of schemas we decode the
    # URL into an URI only once, so both the URI and URL are given when the
    # cache function is created. That is why the cache function does not accept
    # the URL as a key, it's a function dedicated for this URL already.
    %{scheme: scheme, host: host, path: path} = uri

    sub_dir = Path.join(cache_dir, "#{scheme}-#{host}")
    filename = "#{slugify(String.trim_leading(path, "/"))}-#{hash_url(url)}"
    path = Path.join(sub_dir, filename)
    :ok = ensure_cache_dir(sub_dir)

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
