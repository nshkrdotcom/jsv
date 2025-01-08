# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule JSV.ResolverTest do
  alias JSV.Schema
  use ExUnit.Case, async: true

  defmodule ResolverRejectsFragments do
    alias JSV.Codec
    alias JSV.Resolver.Embedded

    def resolve(uri, _) do
      case URI.parse(uri) do
        %{fragment: nil} ->
          do_resolve(uri)

        %{fragment: frag} ->
          flunk("""
          resolver was called with fragment: #{inspect(frag)}

          URI
          #{uri}
          """)
      end
    end

    embedded = Embedded.embedded_normalized_ids()

    defp do_resolve(url) do
      case url do
        "jsv://test/local" ->
          {:ok, local()}

        "jsv://test/meta-format-assertion" ->
          {:ok, meta_format_assertion()}

        known when known in unquote(embedded) ->
          Embedded.resolve(known, [])

        _ ->
          flunk("unresolved: #{inspect(url)}")
      end
    end

    defp local do
      %{"$defs" => %{"string" => %{"type" => "string"}}, "type" => "integer"}
    end

    defp meta_format_assertion do
      Codec.decode!("""
      {
          "$id": "http://localhost:1234/draft2020-12/format-assertion-true.json",
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$vocabulary": {
              "https://json-schema.org/draft/2020-12/vocab/core": true,
              "https://json-schema.org/draft/2020-12/vocab/format-assertion": true
          },
          "$dynamicAnchor": "meta",
          "allOf": [
              { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
              { "$ref": "https://json-schema.org/draft/2020-12/meta/format-assertion" }
          ]
      }
      """)
    end
  end

  describe "fragments are removed when resolver is called" do
    test "in meta schema" do
      # adding a fragment here should not have any effect
      raw_schema = %Schema{"$schema": "https://json-schema.org/draft/2020-12/schema#", type: :integer}
      assert {:ok, _} = JSV.build(raw_schema, resolver: ResolverRejectsFragments)
    end

    test "in refs" do
      raw_schema = %JSV.Schema{
        properties: %{
          a_string: %{"$ref": "jsv://test/local#/$defs/string"},
          an_int: %{"$ref": "jsv://test/local#"}
        }
      }

      assert {:ok, root} = JSV.build(raw_schema, resolver: ResolverRejectsFragments)
      assert {:ok, _} = JSV.validate(%{"a_string" => "hello", "an_int" => 123}, root)
    end

    test "meta schema as ref" do
      # Nothing special but this test was used to fill the embedded resolver by
      # failing on URLs whe should have embedded.
      raw_schema = %Schema{
        oneOf: [
          %{"$ref": "https://json-schema.org/draft/2020-12/schema#"},
          %{"$ref": "http://json-schema.org/draft-07/schema#"}
        ]
      }

      assert {:ok, _} = JSV.build(raw_schema, resolver: ResolverRejectsFragments)
    end

    test "meta schema as ref with format-assertion" do
      raw_schema = %Schema{
        "$schema": "jsv://test/meta-format-assertion",
        oneOf: [
          %{"$ref": "https://json-schema.org/draft/2020-12/schema#"},
          %{"$ref": "http://json-schema.org/draft-07/schema#"},
          %{"$ref": "jsv://test/meta-format-assertion#"}
        ]
      }

      assert {:ok, _} = JSV.build(raw_schema, resolver: ResolverRejectsFragments)
    end
  end
end
