defmodule JSV.Resolver.HttpcTest do
  alias JSV.Codec
  alias JSV.Resolver.Httpc
  use ExUnit.Case, async: true

  test "will not resolve an URL if the prefix is not allowed" do
    assert {:error, {:restricted_url, _}} =
             Httpc.resolve("http://json-schema.org/draft-07/schema", allowed_prefixes: [])
  end

  test "will download a json schema from a remote endpoint" do
    assert {:ok, %{"$id" => "http://json-schema.org/draft-07/schema#"}} =
             Httpc.resolve("http://json-schema.org/draft-07/schema",
               cache_dir: false,
               allowed_prefixes: ["http://json-schema.org/"]
             )
  end

  test "will use a directory cache" do
    url = "http://some-host/some/path"
    unique_id = :erlang.unique_integer([:positive])
    cached_schema = %{"id" => "jsv://test/#{unique_id}"}

    # Define a cache directory for the test that we will give to the resolver
    cache_dir = Path.join(System.tmp_dir!(), "jsv-test-#{System.system_time(:microsecond)}")

    # The Httpc module conveniently allows the test to know the cache path from
    # the URL in advance
    cached_path = Httpc.url_to_cache_path(url, cache_dir)

    # Prefill the cache. Cache is stored as plain json, not http responses
    # objects.
    cached_json = Codec.encode!(cached_schema)
    :ok = File.mkdir_p!(Path.dirname(cached_path))
    :ok = File.write!(cached_path, cached_json)

    # If the cache exists, it is returned
    assert {:ok, ^cached_schema} = Httpc.resolve(url, allowed_prefixes: [url], cache_dir: cache_dir)
  end

  test "will use ssl" do
    # :inets, :ssl and :crypto are started by the tests or a common library ... so this
    # will always work.
    assert {:ok, %{"$id" => "https://json-schema.org/draft/2020-12/schema"}} =
             Httpc.resolve("https://json-schema.org/draft/2020-12/schema",
               cache_dir: false,
               allowed_prefixes: ["https://json-schema.org/"]
             )
  end

  test "uses the internal resolver" do
    defmodule SomeSchema do
      @spec schema :: map
      def schema do
        %{"type" => "integer"}
      end
    end

    assert {:ok, %{"type" => "integer"}} == Httpc.resolve("jsv:module:#{SomeSchema}", [])
  end
end
