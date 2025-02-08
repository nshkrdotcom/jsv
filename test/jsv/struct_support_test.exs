defmodule JSV.StructSupportTest do
  alias JSV.Schema
  alias JSV.StructSupport
  use ExUnit.Case, async: true

  describe "validation" do
    test "ensures properties is defined" do
      good_schema_string = %{"type" => "object", "properties" => %{}}
      good_schema_atom = %{:type => :object, :properties => %{}}
      assert :ok = StructSupport.validate!(good_schema_string)
      assert :ok = StructSupport.validate!(good_schema_atom)

      bad_schema = %{type: :object}

      assert_raise ArgumentError, ~r/properties/, fn ->
        StructSupport.validate!(bad_schema)
      end
    end

    test "ensures properties is a map" do
      good_schema = %{type: :object, properties: %{}}
      assert :ok = StructSupport.validate!(good_schema)

      bad_schema = %{type: :object, properties: true}

      assert_raise ArgumentError, ~r/properties/, fn ->
        StructSupport.validate!(bad_schema)
      end
    end

    test "ensures a schema only uses atom keys for properties" do
      good_schema = %{
        "type" => "object",
        "properties" => %{
          a: %{"type" => "string"},
          b: %{"type" => "string"},
          c: %{"type" => "string"}
        }
      }

      assert :ok = StructSupport.validate!(good_schema)

      bad_schema = %{
        "type" => "object",
        "properties" => %{
          :a => %{"type" => "string"},
          "b" => %{"type" => "string"},
          :c => %{"type" => "string"}
        }
      }

      assert_raise ArgumentError, ~r/atom/, fn ->
        StructSupport.validate!(bad_schema)
      end
    end

    test "ensures the type is object" do
      good_schemas = [
        %{"properties" => %{}, "type" => "object"},
        %{"properties" => %{}, :type => :object},
        %{"properties" => %{}, "type" => :object},
        %{"properties" => %{}, :type => "object"}
      ]

      bad_schemas = [
        %{"properties" => %{}, "type" => "string"},
        %{"properties" => %{}, :type => :string},
        %{"properties" => %{}, "type" => :string},
        %{"properties" => %{}, :type => "string"},
        %{"properties" => %{}}
      ]

      Enum.each(good_schemas, fn s -> assert :ok = StructSupport.validate!(s) end)

      Enum.each(bad_schemas, fn s ->
        assert_raise ArgumentError, ~r/type/, fn ->
          StructSupport.validate!(s)
        end
      end)
    end

    test "validates nil type for schema struct" do
      # Special case. Here we want the error to be "must define type" and not that
      # the type must be "object". With a struct, the type is nil.

      assert_raise ArgumentError, ~r/must define type/, fn ->
        StructSupport.validate!(%Schema{properties: %{}})
      end
    end

    test "accepts Schema structs" do
      assert :ok = StructSupport.validate!(%Schema{properties: %{}, type: :object})
    end

    test "ensures required uses atom keys" do
      good_schemas = [
        %{"properties" => %{}, "type" => "object", "required" => []},
        %{"properties" => %{}, "type" => "object", :required => []},
        %{"properties" => %{}, "type" => "object", :required => [:a]},
        %{"properties" => %{}, "type" => "object", :required => [:a, :b]},

        # nil is accepted with the schema struct
        %Schema{properties: %{}, type: "object", required: nil}
      ]

      bad_schemas = [
        %{"properties" => %{}, "type" => "object", "required" => "not a list"},
        %{"properties" => %{}, "type" => "object", :required => ["string"]},
        %{"properties" => %{}, "type" => "object", :required => [:a, "b", :c]},
        %Schema{properties: %{}, type: "object", required: :bad_stuff}
      ]

      Enum.each(good_schemas, fn s -> assert :ok = StructSupport.validate!(s) end)

      Enum.each(bad_schemas, fn s ->
        assert_raise ArgumentError, ~r/required/, fn ->
          StructSupport.validate!(s)
        end
      end)
    end
  end

  describe "keywmaps" do
    test "empty properties" do
      assert [] == StructSupport.keycast_pairs(%{"properties" => %{}})
      assert [] == StructSupport.keycast_pairs(%{:properties => %{}})
    end

    test "returns a map of string to atom" do
      schema = %{properties: %{a: %{type: :string}, b: %{type: :string}}}
      assert [{"a", :a}, {"b", :b}] == StructSupport.keycast_pairs(schema)

      schema = %{"properties" => %{a: %{type: :string}, b: %{type: :string}}}
      assert [{"a", :a}, {"b", :b}] == StructSupport.keycast_pairs(schema)
    end
  end

  describe "struct pairs" do
    test "empty properties" do
      assert [] == StructSupport.data_pairs(%{"properties" => %{}})
      assert [] == StructSupport.data_pairs(%{:properties => %{}})
    end

    test "with multiple keys" do
      assert [a: nil, b: nil] == StructSupport.data_pairs(%{:properties => %{a: true, b: true}})
    end

    test "with boolean schema" do
      assert [some_key: nil] == StructSupport.data_pairs(%{:properties => %{some_key: true}})
      assert [some_key: nil] == StructSupport.data_pairs(%{:properties => %{some_key: false}})
    end

    test "with sub schema" do
      assert [some_key: nil] == StructSupport.data_pairs(%{:properties => %{some_key: %{type: :string}}})
    end

    test "with sub schema with default" do
      # the default is not validated

      schema = %{:properties => %{some_key: %{type: :integer, default: "not an integer"}}}
      assert [some_key: "not an integer"] == StructSupport.data_pairs(schema)

      schema = %{:properties => %{some_key: %{"type" => :integer, "default" => "not an integer"}}}
      assert [some_key: "not an integer"] == StructSupport.data_pairs(schema)

      # Actually the tool does not even validate the type of the given default
      schema = %{:properties => %{some_key: %{"type" => :integer, "default" => & &1}}}
      assert [some_key: f] = StructSupport.data_pairs(schema)
      assert is_function(f, 1)
    end
  end

  describe "required list" do
    test "no requirements" do
      assert [] == StructSupport.list_required(%{:properties => %{}})
    end

    test "unknown required" do
      # This is not checked but the error should be handled before trying to
      assert [:a, :b, :c] == StructSupport.list_required(%{:properties => %{}, required: [:a, :b, :c]})
    end
  end
end
