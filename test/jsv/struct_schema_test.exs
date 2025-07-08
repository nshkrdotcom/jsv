defmodule JSV.StructSchemaTest do
  alias JSV.Schema
  require JSV
  use ExUnit.Case, async: true

  defmodule BasicDefine do
    JSV.defschema(%Schema{
      type: :object,
      properties: %{
        name: %{type: :string},
        age: %{type: :integer, default: 123}
      }
    })
  end

  defmodule BasicDefineRawMap do
    JSV.defschema(%Schema{
      type: :object,
      properties: %{
        name: %{type: :string},
        age: %{type: :integer, default: 123}
      }
    })
  end

  defmodule WithRequired do
    JSV.defschema(%Schema{
      type: :object,
      properties: %{
        name: %{type: :string},
        age: %{type: :integer, default: 123}
      },
      required: [:name]
    })
  end

  defmodule RefsAnother do
    JSV.defschema(%Schema{
      type: :object,
      properties: %{
        with_req: WithRequired
      },
      required: [:with_req]
    })
  end

  defmodule RecursiveA do
    JSV.defschema(%Schema{
      type: :object,
      properties: %{
        name: Schema.string(),
        sub_b: JSV.StructSchemaTest.RecursiveB
      },
      required: [:sub_b]
    })
  end

  defmodule RecursiveB do
    JSV.defschema(%Schema{
      type: :object,
      properties: %{
        name: Schema.string(),
        sub_a: RecursiveA
      },
      # Sub is not required otherwise this is infinite recursion
      required: []
    })
  end

  defmodule RecursiveSelf do
    JSV.defschema(%Schema{
      type: :object,
      properties: %{
        name: Schema.string(),
        sub_self: __MODULE__
      },
      # Sub is not required otherwise this is infinite recursion
      required: []
    })
  end

  defmodule RecursiveSelfWithCustomId do
    JSV.defschema(%Schema{
      "$id": "custom:my-custom-id",
      type: :object,
      properties: %{
        name: Schema.string(),
        sub_self: __MODULE__
      },
      # Sub is not required otherwise this is infinite recursion
      required: []
    })
  end

  defmodule NoAdditional do
    JSV.defschema(%Schema{
      type: :object,
      properties: %{
        name: %{type: :string},
        age: %{type: :integer, default: 123}
      },
      additionalProperties: false
    })
  end

  defmodule FromGenericData do
    schema = %{
      "$defs": %{
        user: %{
          type: "object",
          properties: %{
            age: %{default: 123, type: "integer"},
            name: %{type: "string"}
          }
        }
      }
    }

    # Schema should be defineable from a function call
    JSV.defschema(get_in(schema, [:"$defs", :user]))
  end

  describe "generating modules from schemas" do
    defp call_mod(mod, data) do
      JSV.validate(data, JSV.build!(mod))
    end

    test "can define a struct with a schema" do
      assert %BasicDefine{name: nil, age: 123} == BasicDefine.__struct__()
      assert {:ok, %BasicDefine{name: "defined", age: -1}} == call_mod(BasicDefine, %{"name" => "defined", "age" => -1})
    end

    test "can define a struct with a raw atom schema" do
      assert %BasicDefineRawMap{name: nil, age: 123} == BasicDefineRawMap.__struct__()

      assert {:ok, %BasicDefineRawMap{name: "defined", age: -1}} ==
               call_mod(BasicDefineRawMap, %{"name" => "defined", "age" => -1})
    end

    test "binary keys are invalid" do
      assert_raise ArgumentError, ~r/must be defined with atom keys/, fn ->
        defmodule BasicDefineBinaryKeys do
          JSV.defschema(%{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "age" => %{"type" => "integer", "default" => 123}
            }
          })
        end
      end
    end

    test "the required keys will be defined and enforced" do
      %WithRequired{} = struct!(WithRequired, name: "hello", age: 123)

      assert_raise ArgumentError, ~r/the following keys.+\[:name\]/, fn ->
        struct!(WithRequired, age: 123)
      end
    end

    test "a module can reference another module in its properties" do
      %RefsAnother{} = struct!(RefsAnother, with_req: :stuff)

      assert_raise ArgumentError, ~r/the following keys.+\[:with_req\]/, fn ->
        struct!(RefsAnother, [])
      end
    end

    test "mutually recursive modules" do
      %RecursiveA{} = struct!(RecursiveA, sub_b: :stuff)
      %RecursiveB{} = struct!(RecursiveB, sub_a: :stuff)

      assert_raise ArgumentError, ~r/the following keys.+\[:sub_b\]/, fn ->
        struct!(RecursiveA, [])
      end
    end

    test "self recursive module" do
      %RecursiveSelf{} = struct!(RecursiveSelf, sub_self: :stuff)
    end

    test "can define a struct with a schema from a quoted function call" do
      assert %FromGenericData{name: nil, age: 123} == FromGenericData.__struct__()

      assert {:ok, %FromGenericData{name: "defined", age: -1}} ==
               call_mod(FromGenericData, %{"name" => "defined", "age" => -1})
    end
  end

  describe "building and validating schemas" do
    test "with unknown module" do
      assert {:error, %JSV.BuildError{reason: %UndefinedFunctionError{}}} = JSV.build(UnknownModule)
    end

    test "with basic schema" do
      valid_data = %{"name" => "hello"}
      invalid_data = %{"name" => "hello", "age" => "not an int"}

      # Can build the root

      assert {:ok, root} = JSV.build(BasicDefine)

      # Will reject invalid data

      assert {:error, _} = JSV.validate(invalid_data, root)

      # Casting to struct works

      assert {:ok, s} = JSV.validate(valid_data, root)
      assert is_struct(s, BasicDefine)

      # Default values are applied (not by JSV but by default structs
      # mechanisms).

      assert %BasicDefine{name: "hello", age: 123} = s

      # Disabled struct casting

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast: false)
    end

    test "with basic as sub schema" do
      schema = %{type: :object, properties: %{basic_define: BasicDefine}}
      valid_data = %{"basic_define" => %{"name" => "hello"}}
      invalid_data = %{"basic_define" => %{"name" => "hello", "age" => "not an int"}}

      # Can build the root

      assert {:ok, root} = JSV.build(schema)

      # Will reject invalid data

      assert {:error, _} = JSV.validate(invalid_data, root)

      # Casting to struct works
      #
      # Default values are applied (not by JSV but by default structs
      # mechanisms).

      assert {:ok, %{"basic_define" => %BasicDefine{name: "hello", age: 123}}} = JSV.validate(valid_data, root)

      # Disabled struct casting

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast: false)
    end

    test "with required data" do
      valid_data = %{"name" => "hello", "age" => 456}
      invalid_data = %{}

      # Can build the root

      assert {:ok, root} = JSV.build(WithRequired)

      # Will reject invalid data

      assert {:error, _} = JSV.validate(invalid_data, root)

      # Casting to struct works

      assert {:ok, s} = JSV.validate(valid_data, root)
      assert is_struct(s, WithRequired)

      # Default values are applied (not by JSV but by default structs
      # mechanisms).

      assert %WithRequired{name: "hello", age: 456} = s

      # Disabled struct casting

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast: false)
    end

    test "with required data as sub schema" do
      valid_data = %{"with_req" => %{"name" => "hello", "age" => 456}}
      invalid_data = %{"with_req" => %{}}

      # Can build the root

      schema = %{type: :object, properties: %{with_req: WithRequired}}
      assert {:ok, root} = JSV.build(schema)

      # Will reject invalid data

      assert {:error, _} = JSV.validate(invalid_data, root)

      # Casting to struct works
      #
      # Default values are applied (not by JSV but by default structs
      # mechanisms).

      assert {:ok, %{"with_req" => %WithRequired{name: "hello", age: 456}}} = JSV.validate(valid_data, root)

      # Disabled struct casting

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast: false)
    end

    test "with another module reference" do
      schema = %{properties: %{refs_another: RefsAnother}}
      valid_data = %{"refs_another" => %{"with_req" => %{"name" => "hello"}}}
      invalid_data_no_sub = %{"refs_another" => %{}}
      invalid_data_bad_sub = %{"refs_another" => %{"with_req" => %{}}}

      # Can build the root

      assert {:ok, root} = JSV.build(schema)

      # Will reject invalid data

      assert {:error, _} = JSV.validate(invalid_data_no_sub, root)
      assert {:error, _} = JSV.validate(invalid_data_bad_sub, root)

      # Validate and casts sub structs

      assert {:ok, %{"refs_another" => %RefsAnother{with_req: %WithRequired{name: "hello", age: 123}}}} =
               JSV.validate(valid_data, root)

      # Disabled struct casting

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast: false)
    end

    test "two recursive schemas" do
      schema = %{properties: %{top: RecursiveA}}

      valid_data = %{
        "top" => %{
          "name" => "a1",
          "sub_b" => %{
            "name" => "b1",
            "sub_a" => %{
              "name" => "a2",
              "sub_b" => %{"name" => "b2", "sub_a" => %{"name" => "a3", "sub_b" => %{"name" => "b3"}}}
            }
          }
        }
      }

      invalid_data = %{
        "top" => %{
          "name" => "a1",
          "sub_b" => %{
            "name" => "b1",
            "sub_a" => %{
              "name" => "a2",
              "sub_b" => %{"name" => "b2", "sub_a" => %{"name" => "a3", "sub_b" => "not an object"}}
            }
          }
        }
      }

      # Can build the root

      assert {:ok, root} = JSV.build(schema)

      # Will reject invalid data

      assert {:error, _} = JSV.validate(invalid_data, root)

      # Casts everything
      assert {:ok,
              %{
                "top" => %RecursiveA{
                  name: "a1",
                  sub_b: %RecursiveB{
                    name: "b1",
                    sub_a: %RecursiveA{
                      name: "a2",
                      sub_b: %RecursiveB{
                        name: "b2",
                        sub_a: %RecursiveA{name: "a3", sub_b: %RecursiveB{name: "b3", sub_a: nil}}
                      }
                    }
                  }
                }
              }} == JSV.validate(valid_data, root)
    end

    test "with recursive self" do
      valid_data = %{
        "name" => "s1",
        "sub_self" => %{
          "name" => "s2",
          "sub_self" => %{
            "name" => "s3",
            "sub_self" => %{"name" => "s4", "sub_self" => %{"name" => "s5"}}
          }
        }
      }

      invalid_data = %{
        "name" => "s1",
        "sub_self" => %{
          "name" => "s2",
          "sub_self" => %{
            "name" => "s3",
            "sub_self" => %{"name" => "s4", "sub_self" => %{"name" => 1235}}
          }
        }
      }

      # Can build the root

      assert {:ok, root} = JSV.build(RecursiveSelf)
      # There should be only one entry in the validators
      assert [:root, "jsv:module:Elixir.JSV.StructSchemaTest.RecursiveSelf"] == Enum.sort(Map.keys(root.validators))

      # Will reject invalid data

      assert {:error, _} = JSV.validate(invalid_data, root)

      # Casts everything
      assert {:ok,
              %RecursiveSelf{
                name: "s1",
                sub_self: %RecursiveSelf{
                  name: "s2",
                  sub_self: %RecursiveSelf{
                    name: "s3",
                    sub_self: %RecursiveSelf{
                      name: "s4",
                      sub_self: %RecursiveSelf{name: "s5", sub_self: nil}
                    }
                  }
                }
              }} == JSV.validate(valid_data, root)

      # Disabled struct casting

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast: false)
    end

    test "with recursive self as sub" do
      schema = %{properties: %{top: RecursiveSelf}}

      valid_data = %{
        "top" => %{
          "name" => "s1",
          "sub_self" => %{
            "name" => "s2",
            "sub_self" => %{
              "name" => "s3",
              "sub_self" => %{"name" => "s4", "sub_self" => %{"name" => "s5"}}
            }
          }
        }
      }

      invalid_data = %{
        "top" => %{
          "name" => "s1",
          "sub_self" => %{
            "name" => "s2",
            "sub_self" => %{
              "name" => "s3",
              "sub_self" => %{"name" => "s4", "sub_self" => %{"name" => 1235}}
            }
          }
        }
      }

      # Can build the root

      assert {:ok, root} = JSV.build(schema)

      # Will reject invalid data

      assert {:error, _} = JSV.validate(invalid_data, root)

      # Casts everything
      assert {:ok,
              %{
                "top" => %RecursiveSelf{
                  name: "s1",
                  sub_self: %RecursiveSelf{
                    name: "s2",
                    sub_self: %RecursiveSelf{
                      name: "s3",
                      sub_self: %RecursiveSelf{
                        name: "s4",
                        sub_self: %RecursiveSelf{name: "s5", sub_self: nil}
                      }
                    }
                  }
                }
              }} == JSV.validate(valid_data, root)

      # Disabled struct casting

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast: false)
    end

    test "additional properties" do
      valid_data = %{"name" => "hello", "some_other_prop" => "goodbye"}

      # Can build the root

      assert {:ok, root_basic} = JSV.build(BasicDefine)
      assert {:ok, root_noadd} = JSV.build(NoAdditional)

      # Module allowing addition properties will not have them in the struct
      assert {:ok, %BasicDefine{} = casted} = JSV.validate(valid_data, root_basic)
      refute is_map_key(casted, "some_other_prop")
      refute is_map_key(casted, :some_other_prop)

      # Module rejecting additional properties will return an error
      assert {:error, _} = JSV.validate(valid_data, root_noadd)

      # When casting is disabled, additional properties are present
      assert {:ok, ^valid_data} = JSV.validate(valid_data, root_basic, cast: false)
    end
  end

  describe "resolver concerns" do
    test "with recursive self with custom id" do
      # The root will contain the definition of the schema only once, with the
      # given $id.
      #
      # The external id, jsv:module:... will be present as the schema is
      # referenced like so in its $ref to self. So we should find that key too.

      assert {:ok, root} = JSV.build(RecursiveSelfWithCustomId)

      assert [RecursiveSelfWithCustomId.json_schema()."$id", "jsv:module:#{Atom.to_string(RecursiveSelfWithCustomId)}"] ==
               Enum.sort(Map.keys(root.validators))

      assert {:alias_of, RecursiveSelfWithCustomId.json_schema()."$id"} ==
               root.validators["jsv:module:#{Atom.to_string(RecursiveSelfWithCustomId)}"]
    end
  end

  describe "optional schemas" do
    test "schema can be given in oneOf" do
      schema = %{oneOf: [%{type: :null}, BasicDefine]}
      root = JSV.build!(schema)
      assert {:ok, nil} == JSV.validate(nil, root)

      assert {:ok, %BasicDefine{name: "Alice", age: 456}} ==
               JSV.validate(%{"name" => "Alice", "age" => 456}, root)
    end
  end

  describe "deserializing into another module with defschema_for" do
    defmodule OriginalStruct do
      @enforce_keys [:some_integer]
      defstruct some_integer: 100, some_bool: true, some_string: "hello"
    end

    defmodule DenormToStruct do
      JSV.defschema_for(OriginalStruct, %{
        type: :object,
        properties: %{
          # Orginal default is 100, but we override it
          some_integer: %{type: :integer, default: 1},
          # Default is :true
          some_bool: %{type: :boolean}
          # we do not declare :some_string
        }
      })
    end

    test "can deserialize to an existing struct" do
      assert {:ok, root} = JSV.build(DenormToStruct)

      # When deserializing, the declared default apply. So we will have
      # some_integer:1 by default.
      #
      # :some_bool does not declare a default, so it should use the default from
      # the original struct and not `nil`.
      #
      # Fields not declared like :some_string should have their original defaults
      # too.

      assert {:ok, %OriginalStruct{some_integer: 1, some_bool: true, some_string: "hello"}} =
               JSV.validate(%{}, root)

      # We can define the values

      assert {:ok, %OriginalStruct{some_integer: 1234, some_bool: false, some_string: "hello"}} =
               JSV.validate(%{"some_integer" => 1234, "some_bool" => false}, root)

      # We cannot pass extra keys that are defined in the struct but not in the schema
      assert {:ok, %OriginalStruct{some_string: "hello"}} =
               JSV.validate(%{"some_string" => "ignored"}, root)
    end

    test "requires the schema to correspond to the struct" do
      # The schema can be defined
      defmodule DenormToStructWithLessKeys do
        JSV.defschema_for(OriginalStruct, %{
          type: :object,
          properties: %{}
        })
      end

      # The root can be built
      assert {:ok, root} = JSV.build(DenormToStructWithLessKeys)

      # But it will fail here
      assert_raise ArgumentError, fn -> JSV.validate(%{}, root) end
    end

    test "cannot provide extra keys" do
      assert_raise ArgumentError, ~r/ does not define keys given in defschema_for\//, fn ->
        defmodule DenormToStructWithExtraKeys do
          JSV.defschema_for(OriginalStruct, %{
            type: :object,
            properties: %{
              some_unknown_key: %{}
            }
          })
        end
      end
    end
  end

  describe "defschema with property list syntax" do
    defmodule WithPropertyList do
      use JSV.Schema

      defschema foo: integer(),
                bar: string(default: "hello")
    end

    defmodule WithPropertyListAllRequired do
      use JSV.Schema

      defschema name: string(),
                age: integer()
    end

    defmodule WithPropertyListMixed do
      use JSV.Schema

      defschema id: integer(),
                name: string(default: "Anonymous"),
                active: boolean(default: true)
    end

    defmodule EmptyStruct do
      use JSV.Schema
      defschema []
    end

    test "can define a struct with property list syntax" do
      assert %WithPropertyList{foo: nil, bar: "hello"} == WithPropertyList.__struct__()

      %WithPropertyList{} = struct!(WithPropertyList, foo: 123)

      assert_raise ArgumentError, ~r/the following keys.+\[:foo\]/, fn ->
        struct!(WithPropertyList, bar: "world")
      end
    end

    test "exported schema has correct structure" do
      assert %{
               title: "WithPropertyList",
               type: :object,
               properties: %{
                 foo: %{type: :integer},
                 bar: %{type: :string, default: "hello"}
               },
               required: [:foo],
               "jsv-cast": [to_string(WithPropertyList), 0]
             } == WithPropertyList.json_schema()
    end

    test "validation works with property list syntax" do
      valid_data = %{"foo" => 42}
      invalid_data = %{"foo" => "not an integer"}
      assert {:ok, root} = JSV.build(WithPropertyList)
      assert {:ok, %WithPropertyList{foo: 42, bar: "hello"}} = JSV.validate(valid_data, root)
      assert {:error, _} = JSV.validate(invalid_data, root)
    end

    test "all properties without defaults are required" do
      assert %{
               title: "WithPropertyListAllRequired",
               type: :object,
               properties: %{
                 name: %{type: :string},
                 age: %{type: :integer}
               },
               required: [:name, :age],
               "jsv-cast": [to_string(WithPropertyListAllRequired), 0]
             } == WithPropertyListAllRequired.json_schema()

      assert_raise ArgumentError, ~r/the following keys.+\[:age\]/, fn ->
        struct!(WithPropertyListAllRequired, name: "Alice")
      end

      assert_raise ArgumentError, ~r/the following keys.+\[:name\]/, fn ->
        struct!(WithPropertyListAllRequired, age: 30)
      end

      %WithPropertyListAllRequired{} = struct!(WithPropertyListAllRequired, name: "Alice", age: 30)
    end

    test "mixed properties with some defaults" do
      assert %{
               title: "WithPropertyListMixed",
               type: :object,
               properties: %{
                 id: %{type: :integer},
                 name: %{type: :string, default: "Anonymous"},
                 active: %{type: :boolean, default: true}
               },
               required: [:id],
               "jsv-cast": [to_string(WithPropertyListMixed), 0]
             } == WithPropertyListMixed.json_schema()

      %WithPropertyListMixed{} = struct!(WithPropertyListMixed, id: 1)

      assert_raise ArgumentError, ~r/the following keys.+\[:id\]/, fn ->
        struct!(WithPropertyListMixed, name: "Alice", active: false)
      end
    end

    test "validation with mixed properties" do
      assert {:ok, root} = JSV.build(WithPropertyListMixed)

      assert {:ok, %WithPropertyListMixed{id: 1, name: "Anonymous", active: true}} =
               JSV.validate(%{"id" => 1}, root)

      assert {:ok, %WithPropertyListMixed{id: 2, name: "Alice", active: false}} =
               JSV.validate(%{"id" => 2, "name" => "Alice", "active" => false}, root)

      assert {:error, _} = JSV.validate(%{"name" => "Alice"}, root)
    end

    test "empty property list creates empty struct" do
      assert %EmptyStruct{} == EmptyStruct.__struct__()

      assert %{
               title: "EmptyStruct",
               type: :object,
               properties: %{},
               required: [],
               "jsv-cast": [to_string(EmptyStruct), 0]
             } == EmptyStruct.json_schema()

      assert {:ok, root} = JSV.build(EmptyStruct)
      assert {:ok, %EmptyStruct{}} = JSV.validate(%{}, root)

      assert {:ok, %EmptyStruct{}} = JSV.validate(%{"ignored" => "value"}, root)
    end

    test "property list with non-atom keys should fail" do
      assert_raise ArgumentError, ~r/properties must be defined with atom keys/, fn ->
        defmodule BadPropertyList do
          JSV.defschema([{"string_key", %{type: :string}}])
        end
      end
    end
  end
end
