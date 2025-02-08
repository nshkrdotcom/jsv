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
      # Sub is not required otherwise this is infinit recursion
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
      # Sub is not required otherwise this is infinit recursion
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
      # Sub is not required otherwise this is infinit recursion
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

  describe "generating modules from schemas" do
    test "can define a struct with a schema" do
      assert %BasicDefine{name: nil, age: 123} == BasicDefine.__struct__()
      assert [{"age", :age}, {"name", :name}] == BasicDefine.__jsv__(:keycast)
    end

    test "can define a struct with a raw atom schema" do
      assert %BasicDefineRawMap{name: nil, age: 123} == BasicDefineRawMap.__struct__()
      assert [{"age", :age}, {"name", :name}] == BasicDefineRawMap.__jsv__(:keycast)
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

      assert_raise ArgumentError, ~r/the following keys/, fn ->
        struct!(WithRequired, age: 123)
      end
    end

    test "a module can reference another module in its properties" do
      %RefsAnother{} = struct!(RefsAnother, with_req: :stuff)

      assert_raise ArgumentError, ~r/the following keys/, fn ->
        struct!(RefsAnother, [])
      end
    end

    test "mutually recursive modules" do
      %RecursiveA{} = struct!(RecursiveA, sub_b: :stuff)
      %RecursiveB{} = struct!(RecursiveB, sub_a: :stuff)

      assert_raise ArgumentError, ~r/the following keys/, fn ->
        struct!(RecursiveA, [])
      end
    end

    test "self recursive module" do
      %RecursiveSelf{} = struct!(RecursiveSelf, sub_self: :stuff)
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

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast_structs: false)
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

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast_structs: false)
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

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast_structs: false)
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

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast_structs: false)
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

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast_structs: false)
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

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast_structs: false)
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

      assert {:ok, ^valid_data} = JSV.validate(valid_data, root, cast_structs: false)
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
      assert {:ok, ^valid_data} = JSV.validate(valid_data, root_basic, cast_structs: false)
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

      assert [RecursiveSelfWithCustomId.schema()."$id", "jsv:module:#{Atom.to_string(RecursiveSelfWithCustomId)}"] ==
               Enum.sort(Map.keys(root.validators))

      assert {:alias_of, RecursiveSelfWithCustomId.schema()."$id"} ==
               root.validators["jsv:module:#{Atom.to_string(RecursiveSelfWithCustomId)}"]
    end
  end
end
