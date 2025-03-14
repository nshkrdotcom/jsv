defmodule JSV.SchemaTest do
  alias JSV.Resolver.Internal
  alias JSV.Schema
  use ExUnit.Case, async: true

  doctest JSV.Schema

  test "provides utility functions" do
    assert %Schema{type: :integer} = Schema.integer()
    assert %Schema{type: :integer, description: "hello"} = Schema.integer(description: "hello")
    # no override of type
    assert %Schema{type: :integer} = Schema.integer(type: :string)
  end

  test "larger example" do
    expected =
      %Schema{
        type: :object,
        properties: %{
          name: %Schema{type: :string, description: "the name of the user"},
          age: %Schema{type: :integer, description: "the age of the user"}
        },
        required: [:name, :age]
      }

    actual =
      %Schema{}
      |> Schema.props(
        name: Schema.string(description: "the name of the user"),
        age: Schema.integer(description: "the age of the user")
      )
      |> Schema.required([:name, :age])

    assert expected == actual
  end

  describe "normalize" do
    test "remove all atoms from map" do
      # handles maps with atom keys
      assert %{"hello" => "world"} == Schema.normalize(%{hello: "world"})

      # handles maps with atom values
      assert %{"hello" => "world"} == Schema.normalize(%{hello: :world})

      # keeps booleans and nil as values but not keys
      assert %{"true" => true} == Schema.normalize(%{true: true})
      assert %{"false" => false} == Schema.normalize(%{false: false})
      assert %{"nil" => nil} == Schema.normalize(%{nil: nil})

      # keeps basic types
      assert %{"i" => 1, "f" => 2.3, "l" => [4]} == Schema.normalize(%{i: 1, f: 2.3, l: [4]})
    end

    test "removes all atoms and nil values from Schema struct" do
      # handles structs with a special treatment for the schema struct, it removes
      # all nil values.

      assert %{"title" => "stuff"} == Schema.normalize(%Schema{title: "stuff"})

      assert %{"anyOf" => [%{"properties" => %{"foo" => 1}}]} ==
               Schema.normalize(%Schema{anyOf: [%Schema{properties: %{foo: 1}}]})
    end

    defmodule MyStruct do
      defstruct a: nil, b: nil
    end

    test "removes struct fields from any struct" do
      # It does not removes nil values as for JSV.Schema

      assert %{"a" => "hello", "b" => nil} == Schema.normalize(%MyStruct{a: "hello"})

      assert %{"a" => "hello", "b" => %{"a" => "goodbye", "b" => nil}} ==
               Schema.normalize(%MyStruct{a: "hello", b: %MyStruct{a: "goodbye"}})
    end

    test "incompatible values: tuple keys" do
      assert_raise ArgumentError, fn ->
        Schema.normalize(%{{:a, :b} => "value"})
      end
    end

    test "incompatible values: tuple values" do
      assert_raise ArgumentError, fn ->
        Schema.normalize(%{key: {:a, :b}})
      end
    end

    test "incompatible values: pid keys" do
      assert_raise ArgumentError, fn ->
        Schema.normalize(%{self() => "value"})
      end
    end

    test "incompatible values: pid values" do
      assert_raise ArgumentError, fn ->
        Schema.normalize(%{key: self()})
      end
    end

    test "incompatible values: ref keys" do
      assert_raise ArgumentError, fn ->
        Schema.normalize(%{make_ref() => "value"})
      end
    end

    test "incompatible values: ref values" do
      assert_raise ArgumentError, fn ->
        Schema.normalize(%{key: make_ref()})
      end
    end

    test "converts modules that export schema/0 to refs" do
      defmodule ExportsSchema do
        @spec schema :: no_return()
        def schema do
          raise "will not be called"
        end
      end

      assert %{"$ref" => Internal.module_to_uri(ExportsSchema)} == Schema.normalize(ExportsSchema)
    end

    test "converts Elixir modules that do not export schema/0 to $ref" do
      # This is enforced because we expect the atom to be a valid module
      defmodule DoesNotExportSchema do
      end

      assert %{"$ref" => Internal.module_to_uri(ExportsSchema)} == Schema.normalize(ExportsSchema)
    end

    test "converts Erlang modules that do not export schema/0 to string" do
      # This is not an Elixir module, so we cannot know if it's a custom type, format, etc.
      defmodule unquote(:test_schema_module_to_ref) do
      end

      # So it's just stringified
      assert "test_schema_module_to_ref" == Schema.normalize(:test_schema_module_to_ref)
    end

    test "converts Erlang modules that export schema/0 to $ref" do
      # This is not an Elixir module, so we cannot know if it's a custom type, format, etc.
      defmodule unquote(:test_schema_module_to_ref_with_schema) do
        @spec schema :: no_return()
        def schema do
          raise "will not be called"
        end
      end

      # Since we can find the function it's a $ref
      assert %{"$ref" => Internal.module_to_uri(:test_schema_module_to_ref_with_schema)} ==
               Schema.normalize(:test_schema_module_to_ref_with_schema)
    end
  end
end
