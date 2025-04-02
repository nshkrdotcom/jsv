defmodule JSV.SchemaTest do
  alias JSV.Resolver.Internal
  alias JSV.Schema
  use ExUnit.Case, async: true

  doctest JSV.Schema

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

  describe "definition helpers" do
    fun_cases = [
      boolean: %{
        valids: [true, false],
        invalids: ["hello", 0, 1, "", nil]
      },
      integer: %{
        valids: [1, 42, -10, 2.0, -2.0, +0.0, -0.0],
        invalids: [1.5, "string", true, nil]
      },
      pos_integer: %{
        valids: [1, 2, 42, 1000, 1.0],
        invalids: [0, -1, -42, 1.5, "string", true, nil]
      },
      non_neg_integer: %{
        valids: [0, 1, 2, 42, 1000, 1.0, +0.0, -0.0],
        invalids: [-1, -42, 1.5, "string", true, nil]
      },
      neg_integer: %{
        valids: [-1, -2, -42, -1000, -1.0],
        invalids: [0, 1, 42, -1.5, "string", true, nil]
      },
      items: %{
        args: [%{type: :string}],
        valids: [["a", "b", "c"], [], "not an array", nil, 123],
        invalids: [["a", 1, true]]
      },
      array_of: %{
        args: [%{type: :string}],
        valids: [["a", "b", "c"]],
        invalids: [["a", 1, true], "not an array"]
      },
      number: %{
        valids: [1, 1.5, -10.2, -0.0],
        invalids: ["string", true, nil, [], [0]]
      },
      object: %{
        valids: [%{"key" => "value"}, %{}],
        invalids: ["string", 1, nil]
      },
      properties: %{
        args: [
          # as map
          %{prop1: %{type: :string}, prop2: %{type: :integer}}
        ],
        valids: [
          %{"prop1" => "value"},
          %{"prop2" => 123},
          %{"prop1" => "value", "prop2" => 123},
          %{},
          "not an object",
          123,
          nil
        ],
        invalids: [%{"prop1" => %{}}, %{"prop2" => %{}}]
      },
      properties_as_list: %{
        fun: :properties,
        args: [
          # as list
          [prop1: %{type: :string}, prop2: %{type: :integer}]
        ],
        valids: [
          %{"prop1" => "value"},
          %{"prop2" => 123},
          %{"prop1" => "value", "prop2" => 123},
          %{},
          "not an object",
          123,
          nil
        ],
        invalids: [%{"prop1" => %{}}, %{"prop2" => %{}}]
      },
      props: %{
        args: [%{prop1: %{type: :string}, prop2: %{type: :integer}}],
        valids: [%{"prop1" => "value"}, %{"prop2" => 123}, %{"prop1" => "value", "prop2" => 123}, %{}],
        invalids: [%{"prop1" => %{}}, %{"prop2" => %{}}, "not an object", 123, nil]
      },
      ref: %{
        args: ["#/$defs/an_int"],
        base: %{"$defs": %{an_int: %{type: :integer}}},
        valids: [1],
        invalids: ["not an int", nil]
      },
      required: %{
        args: [[:some_key]],
        valids: [%{"some_key" => 1}, "not an object", 123],
        invalids: [%{}]
      },
      required_with_existing: %{
        fun: :required,
        args: [[:some_key]],
        base: %{required: [:already_required]},
        valids: [%{"some_key" => 1, "already_required" => 1}, "not an object", 123],
        invalids: [%{}, %{"some_key" => 1}, %{"already_required" => 1}]
      },
      string: %{
        valids: ["", "1234", "hello", " "],
        invalids: [true, false, 1, %{}]
      },
      format: %{
        args: ["date"],
        valids: ["2023-05-20", "1990-01-01", 123, true, nil],
        invalids: ["20-05-2023", "2023/05/20", "2023-05-20T12:30:00Z"]
      },
      string_of: %{
        args: ["date"],
        valids: ["2023-05-20", "1990-01-01"],
        invalids: ["20-05-2023", "2023/05/20", "2023-05-20T12:30:00Z", 123, true, nil]
      },
      date: %{
        valids: ["2023-05-20", "1990-01-01"],
        invalids: ["20-05-2023", "2023/05/20", "2023-05-20T12:30:00Z", 123, true, nil]
      },
      datetime: %{
        valids: ["2023-05-20T12:30:00Z", "2023-05-20T12:30:00+02:00", "2023-05-20T12:30:00.123Z"],
        invalids: ["2023-05-20", "12:30:00", "not a datetime", 123, true, nil]
      },
      uri: %{
        valids: ["https://example.com", "http://localhost:4000", "ftp://files.example.org"],
        invalids: ["example.com", "not a uri", 123, true, nil]
      },
      uuid: %{
        valids: ["550e8400-e29b-41d4-a716-446655440000", "123e4567-e89b-12d3-a456-426614174000"],
        invalids: ["not-a-uuid", "123", "550e8400e29b41d4a716446655440000", 123, true, nil]
      },
      all_of: %{
        args: [
          [
            %{type: :integer},
            %{minimum: 1, maximum: 10}
          ]
        ],
        valids: [1, 5, 10],
        invalids: [0, 11, "string", true, nil]
      },
      any_of: %{
        args: [
          [
            %{type: :string},
            %{type: :integer, minimum: 0}
          ]
        ],
        valids: ["hello", 0, 1, 42],
        invalids: [-1, true, nil, %{}]
      },
      one_of: %{
        args: [
          [
            %{type: :integer, maximum: 5},
            %{type: :integer, minimum: 10}
          ]
        ],
        valids: [1, 3, 5, 10, 15],
        invalids: [6, 7, 8, 9, "string", true, nil]
      }
    ]

    Enum.each(fun_cases, fn {fun, spec} ->
      test "#{fun} utility" do
        spec = unquote(Macro.escape(spec))

        fun = Map.get(spec, :fun, unquote(fun))

        %{valids: valids, invalids: invalids} = spec
        args = Map.get(spec, :args, [])

        # For coverage, if no base is set, we do not call the function with
        # base==nil, we expect the helper function to call its arity-2 version
        # with nil automatically.
        schema =
          case Map.get(spec, :base, nil) do
            nil -> apply(Schema, fun, args)
            base -> apply(Schema, fun, [base | args])
          end

        root = JSV.build!(schema, formats: true)

        Enum.each(valids, fn valid ->
          case JSV.validate(valid, root, cast_formats: true) do
            {:ok, _} ->
              :ok

            {:error, err} ->
              flunk(
                "Expected #{inspect(valid)} to be valid with #{fun}(#{Enum.map_join(args, ", ", &inspect/1)}), got: #{inspect(JSV.normalize_error(err), pretty: true)}"
              )
          end
        end)

        Enum.each(invalids, fn invalid ->
          case JSV.validate(invalid, root, cast_formats: true) do
            {:ok, casted} ->
              flunk("""
              Expected #{inspect(invalid)} to be invalid with #{fun}(#{Enum.map_join(args, ", ", &inspect/1)})

              CASTED TO
              #{inspect(casted)}

              SCHEMA
              #{inspect(schema, pretty: true)}
              """)

            {:error, _} ->
              :ok
          end
        end)
      end
    end)

    test "guard clauses are handled by the defcompose helper - properties" do
      # The properties helper accepts maps and lists
      assert %{properties: %{a: _}} = Schema.properties(a: true)
      assert %{properties: %{a: _}} = Schema.properties(%{a: true})

      # but no other kind
      assert_raise FunctionClauseError, fn ->
        assert %{properties: %{a: _}} = Schema.properties(1)
      end
    end

    test "guard clauses are handled by the defcompose helper - props" do
      # The properties helper accepts maps and lists
      assert %{properties: %{a: _}} = Schema.props(a: true)
      assert %{properties: %{a: _}} = Schema.props(%{a: true})

      # but no other kind
      assert_raise FunctionClauseError, fn ->
        assert %{properties: %{a: _}} = Schema.props(1)
      end
    end

    test "guard clauses are handled by the defcompose helper - all_of" do
      # The all_of helper accepts lists
      assert %{allOf: [%{type: :integer}]} = Schema.all_of([%{type: :integer}])

      # but no other kind
      assert_raise FunctionClauseError, fn ->
        Schema.all_of(%{type: :integer})
      end
    end

    test "guard clauses are handled by the defcompose helper - any_of" do
      # The any_of helper accepts lists
      assert %{anyOf: [%{type: :integer}]} = Schema.any_of([%{type: :integer}])

      # but no other kind
      assert_raise FunctionClauseError, fn ->
        Schema.any_of(%{type: :integer})
      end
    end

    test "guard clauses are handled by the defcompose helper - one_of" do
      # The one_of helper accepts lists
      assert %{oneOf: [%{type: :integer}]} = Schema.one_of([%{type: :integer}])

      # but no other kind
      assert_raise FunctionClauseError, fn ->
        Schema.one_of(%{type: :integer})
      end
    end
  end

  defmodule TestCustomStruct do
    defstruct [:properties, :foo, :required]
  end

  describe "override/2" do
    test "override accepts nil as base and returns a Schema struct" do
      result = Schema.override(nil, %{type: :string})
      assert %Schema{type: :string} = result
    end

    test "override accepts a map as base and keeps it as a map" do
      base = %{foo: "bar"}
      assert %{foo: "bar", type: :string} = result = Schema.override(base, %{type: :string})
      refute is_struct(result)
    end

    test "override accepts a Schema struct as base" do
      base = %Schema{description: "test"}
      result = Schema.override(base, %{type: :string})
      assert %Schema{description: "test", type: :string} = result
    end

    test "override fails if another struct is passed and doesn't have the keys" do
      base = %TestCustomStruct{foo: "bar"}

      # the struct accept properties

      assert %TestCustomStruct{foo: "bar", properties: %{a: %{type: :integer}}} =
               Schema.override(base, properties: %{a: %{type: :integer}})

      # the struct does not have a :type key

      assert_raise KeyError, ~r/does not accept key :type/, fn ->
        Schema.override(base, %{type: :string})
      end
    end

    test "override accepts a keyword list as base and returns a Schema struct" do
      base = [description: "some description"]
      result = Schema.override(base, %{type: :string})
      assert %Schema{description: "some description", type: :string} = result
      assert is_struct(result)
    end

    # Same tests but with a defcompose generated helper

    test "compose accepts nil as base and returns a Schema struct" do
      result = Schema.string(nil)
      assert %Schema{type: :string} = result
    end

    test "compose accepts a map as base and keeps it as a map" do
      base = %{foo: "bar"}
      assert %{foo: "bar", type: :string} = result = Schema.string(base)
      refute is_struct(result)
    end

    test "compose accepts a Schema struct as base" do
      base = %Schema{description: "test"}
      result = Schema.string(base)
      assert %Schema{description: "test", type: :string} = result
    end

    test "compose fails if another struct is passed and doesn't have the keys" do
      base = %TestCustomStruct{foo: "bar"}

      # the struct accept properties

      assert %TestCustomStruct{foo: "bar", properties: %{a: %{type: :integer}}} =
               Schema.properties(base, a: %{type: :integer})

      # the struct does not have a :type key

      assert_raise KeyError, ~r/does not accept key :type/, fn ->
        Schema.string(base)
      end
    end

    test "compose accepts a keyword list as base and returns a Schema struct" do
      base = [description: "some description"]
      result = Schema.string(base)
      assert %Schema{description: "some description", type: :string} = result
      assert is_struct(result)
    end
  end

  describe "required/2" do
    test "with a nil base" do
      result = Schema.required(nil, [:prop1, :prop2])
      assert %Schema{required: [:prop1, :prop2]} = result
    end

    test "with a map base" do
      base = %{type: :object}
      result = Schema.required(base, [:prop1, :prop2])
      assert %{type: :object, required: [:prop1, :prop2]} = result
    end

    test "with a map base with predefined required keys" do
      base = %{type: :object, required: [:existing]}
      result = Schema.required(base, [:prop1, :prop2])
      assert %{type: :object, required: [:prop1, :prop2, :existing]} = result
    end

    test "with a keyword list base" do
      base = [type: :object]
      result = Schema.required(base, [:prop1, :prop2])
      assert %Schema{type: :object, required: [:prop1, :prop2]} = result
    end

    test "with a keyword list base with predefined required keys" do
      base = [type: :object, required: [:existing]]
      result = Schema.required(base, [:prop1, :prop2])
      assert %Schema{type: :object, required: [:prop1, :prop2, :existing]} = result
    end

    test "with a %Schema{} base" do
      base = %Schema{type: :object}
      result = Schema.required(base, [:prop1, :prop2])
      assert %Schema{type: :object, required: [:prop1, :prop2]} = result
    end

    test "with a %Schema{} base with predefined required keys" do
      base = %Schema{type: :object, required: [:existing]}
      result = Schema.required(base, [:prop1, :prop2])
      assert %Schema{type: :object, required: [:prop1, :prop2, :existing]} = result
    end

    test "with a custom struct base" do
      base = %TestCustomStruct{foo: "bar"}
      result = Schema.required(base, [:prop1, :prop2])
      assert %TestCustomStruct{foo: "bar", required: [:prop1, :prop2]} = result
    end

    test "with a custom struct base with predefined required keys" do
      base = %TestCustomStruct{foo: "bar", required: [:existing]}
      result = Schema.required(base, [:prop1, :prop2])
      assert %TestCustomStruct{foo: "bar", required: [:prop1, :prop2, :existing]} = result
    end

    defmodule TestCustomStructNoRequired do
      defstruct []
    end

    test "with a custom struct that does not accept :required" do
      assert_raise KeyError, ~r/does not accept key :required/, fn ->
        Schema.required(%TestCustomStructNoRequired{}, [:prop1, :prop2])
      end
    end
  end
end
