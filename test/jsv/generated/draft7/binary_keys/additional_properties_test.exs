# credo:disable-for-this-file Credo.Check.Readability.LargeNumbers
# credo:disable-for-this-file Credo.Check.Readability.StringSigils

defmodule JSV.Generated.Draft7.BinaryKeys.AdditionalPropertiesTest do
  alias JSV.Test.JsonSchemaSuite
  use ExUnit.Case, async: true

  @moduledoc """
  Test generated from deps/json_schema_test_suite/tests/draft7/additionalProperties.json
  """

  describe "additionalProperties being false does not allow other properties" do
    setup do
      json_schema = %{
        "properties" => %{"bar" => %{}, "foo" => %{}},
        "patternProperties" => %{"^v" => %{}},
        "additionalProperties" => false
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "no additional properties is valid", x do
      data = %{"foo" => 1}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "an additional property is invalid", x do
      data = %{"bar" => 2, "foo" => 1, "quux" => "boom"}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "ignores arrays", x do
      data = [1, 2, 3]
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "ignores strings", x do
      data = "foobarbaz"
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "ignores other non-objects", x do
      data = 12
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "patternProperties are not additional properties", x do
      data = %{"foo" => 1, "vroom" => 2}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "non-ASCII pattern with additionalProperties" do
    setup do
      json_schema = %{"patternProperties" => %{"^á" => %{}}, "additionalProperties" => false}
      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "matching the pattern is valid", x do
      data = %{"ármányos" => 2}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "not matching the pattern is invalid", x do
      data = %{"élmény" => 2}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "additionalProperties with schema" do
    setup do
      json_schema = %{
        "properties" => %{"bar" => %{}, "foo" => %{}},
        "additionalProperties" => %{"type" => "boolean"}
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "no additional properties is valid", x do
      data = %{"foo" => 1}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "an additional valid property is valid", x do
      data = %{"bar" => 2, "foo" => 1, "quux" => true}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "an additional invalid property is invalid", x do
      data = %{"bar" => 2, "foo" => 1, "quux" => 12}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "additionalProperties can exist by itself" do
    setup do
      json_schema = %{"additionalProperties" => %{"type" => "boolean"}}
      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "an additional valid property is valid", x do
      data = %{"foo" => true}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "an additional invalid property is invalid", x do
      data = %{"foo" => 1}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "additionalProperties are allowed by default" do
    setup do
      json_schema = %{"properties" => %{"bar" => %{}, "foo" => %{}}}
      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "additional properties are allowed", x do
      data = %{"bar" => 2, "foo" => 1, "quux" => true}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "additionalProperties does not look in applicators" do
    setup do
      json_schema = %{
        "additionalProperties" => %{"type" => "boolean"},
        "allOf" => [%{"properties" => %{"foo" => %{}}}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "properties defined in allOf are not examined", x do
      data = %{"bar" => true, "foo" => 1}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "additionalProperties with null valued instance properties" do
    setup do
      json_schema = %{"additionalProperties" => %{"type" => "null"}}
      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "allows null values", x do
      data = %{"foo" => nil}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end
end
