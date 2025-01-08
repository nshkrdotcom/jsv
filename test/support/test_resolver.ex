# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule JSV.Test.TestResolver do
  alias JSV.Codec
  alias JSV.Resolver.Embedded

  @moduledoc false

  @suite_dir Path.join([File.cwd!(), "deps", "json_schema_test_suite", "remotes"])

  def resolve("http://localhost:1234/" <> _ = url, _) do
    uri = URI.parse(url)
    return_local_file(uri.path)
  end

  def resolve(url, _opts) do
    Embedded.resolve(url, [])
  end

  defp return_local_file(path) do
    full_path = Path.join(@suite_dir, path)

    case File.read(full_path) do
      {:ok, json} -> Codec.decode(json)
      {:error, :enoent} -> {:error, {:local_not_found, path}}
    end
  end
end
