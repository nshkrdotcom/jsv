# credo:disable-for-this-file Credo.Check.Readability.LargeNumbers
# credo:disable-for-this-file Credo.Check.Readability.StringSigils

defmodule JSV.Generated.Draft7.AtomKeys.Optional.IdTest do
  alias JSV.Test.JsonSchemaSuite
  use ExUnit.Case, async: true

  @moduledoc """
  Test generated from deps/json_schema_test_suite/tests/draft7/optional/id.json
  """

  describe "id inside an enum is not a real identifier" do
    setup do
      json_schema = %{
        definitions: %{
          id_in_enum: %JSV.Schema{
            enum: [
              %JSV.Schema{
                "$id": "https://localhost:1234/id/my_identifier.json",
                type: "null"
              }
            ]
          },
          real_id_in_schema: %JSV.Schema{
            "$id": "https://localhost:1234/id/my_identifier.json",
            type: "string"
          },
          zzz_id_in_const: %{
            const: %JSV.Schema{
              "$id": "https://localhost:1234/id/my_identifier.json",
              type: "null"
            }
          }
        },
        anyOf: [
          %JSV.Schema{"$ref": "#/definitions/id_in_enum"},
          %JSV.Schema{"$ref": "https://localhost:1234/id/my_identifier.json"}
        ]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "exact match to enum, and type matches", x do
      data = %{"$id" => "https://localhost:1234/id/my_identifier.json", "type" => "null"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "match $ref to id", x do
      data = "a string to match #/definitions/id_in_enum"
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "no match on enum or $ref to id", x do
      data = 1
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "non-schema object containing a plain-name $id property" do
    setup do
      json_schema = %{
        definitions: %{
          const_not_anchor: %{const: %JSV.Schema{"$id": "#not_a_real_anchor"}}
        },
        else: %JSV.Schema{"$ref": "#/definitions/const_not_anchor"},
        if: %{const: "skip not_a_real_anchor"},
        then: true
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "skip traversing definition for a valid result", x do
      data = "skip not_a_real_anchor"
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "const at const_not_anchor does not match", x do
      data = 1
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "non-schema object containing an $id property" do
    setup do
      json_schema = %{
        definitions: %{const_not_id: %{const: %JSV.Schema{"$id": "not_a_real_id"}}},
        else: %JSV.Schema{"$ref": "#/definitions/const_not_id"},
        if: %{const: "skip not_a_real_id"},
        then: true
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "skip traversing definition for a valid result", x do
      data = "skip not_a_real_id"
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "const at const_not_id does not match", x do
      data = 1
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end
end
