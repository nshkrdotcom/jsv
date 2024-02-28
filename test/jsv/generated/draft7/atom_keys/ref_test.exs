# credo:disable-for-this-file Credo.Check.Readability.LargeNumbers
# credo:disable-for-this-file Credo.Check.Readability.StringSigils

defmodule JSV.Generated.Draft7.AtomKeys.RefTest do
  alias JSV.Test.JsonSchemaSuite
  use ExUnit.Case, async: true

  @moduledoc """
  Test generated from deps/json_schema_test_suite/tests/draft7/ref.json
  """

  describe "root pointer ref" do
    setup do
      json_schema = %JSV.Schema{
        properties: %{foo: %JSV.Schema{"$ref": "#"}},
        additionalProperties: false
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "match", x do
      data = %{"foo" => false}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "recursive match", x do
      data = %{"foo" => %{"foo" => false}}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "mismatch", x do
      data = %{"bar" => false}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "recursive mismatch", x do
      data = %{"foo" => %{"bar" => false}}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "relative pointer ref to object" do
    setup do
      json_schema = %JSV.Schema{
        properties: %{
          bar: %JSV.Schema{"$ref": "#/properties/foo"},
          foo: %JSV.Schema{type: "integer"}
        }
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "match", x do
      data = %{"bar" => 3}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "mismatch", x do
      data = %{"bar" => true}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "relative pointer ref to array" do
    setup do
      json_schema = %JSV.Schema{
        items: [%JSV.Schema{type: "integer"}, %JSV.Schema{"$ref": "#/items/0"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "match array", x do
      data = [1, 2]
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "mismatch array", x do
      data = [1, "foo"]
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "escaped pointer ref" do
    setup do
      json_schema = %{
        definitions: %{
          "percent%field": %JSV.Schema{type: "integer"},
          "slash/field": %JSV.Schema{type: "integer"},
          "tilde~field": %JSV.Schema{type: "integer"}
        },
        properties: %{
          percent: %JSV.Schema{"$ref": "#/definitions/percent%25field"},
          slash: %JSV.Schema{"$ref": "#/definitions/slash~1field"},
          tilde: %JSV.Schema{"$ref": "#/definitions/tilde~0field"}
        }
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "slash invalid", x do
      data = %{"slash" => "aoeu"}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "tilde invalid", x do
      data = %{"tilde" => "aoeu"}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "percent invalid", x do
      data = %{"percent" => "aoeu"}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "slash valid", x do
      data = %{"slash" => 123}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "tilde valid", x do
      data = %{"tilde" => 123}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "percent valid", x do
      data = %{"percent" => 123}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "nested refs" do
    setup do
      json_schema = %{
        definitions: %{
          a: %JSV.Schema{type: "integer"},
          b: %JSV.Schema{"$ref": "#/definitions/a"},
          c: %JSV.Schema{"$ref": "#/definitions/b"}
        },
        allOf: [%JSV.Schema{"$ref": "#/definitions/c"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "nested ref valid", x do
      data = 5
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "nested ref invalid", x do
      data = "a"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "ref overrides any sibling keywords" do
    setup do
      json_schema = %{
        definitions: %{reffed: %JSV.Schema{type: "array"}},
        properties: %{foo: %JSV.Schema{"$ref": "#/definitions/reffed", maxItems: 2}}
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "ref valid", x do
      data = %{"foo" => []}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "ref valid, maxItems ignored", x do
      data = %{"foo" => [1, 2, 3]}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "ref invalid", x do
      data = %{"foo" => "string"}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "$ref prevents a sibling $id from changing the base uri" do
    setup do
      json_schema = %{
        "$id": "http://localhost:1234/sibling_id/base/",
        definitions: %{
          base_foo: %JSV.Schema{
            "$id": "foo.json",
            type: "number",
            "$comment": "this canonical uri is http://localhost:1234/sibling_id/base/foo.json"
          },
          foo: %JSV.Schema{
            "$id": "http://localhost:1234/sibling_id/foo.json",
            type: "string"
          }
        },
        allOf: [
          %JSV.Schema{
            "$id": "http://localhost:1234/sibling_id/",
            "$ref": "foo.json",
            "$comment":
              "$ref resolves to http://localhost:1234/sibling_id/base/foo.json, not http://localhost:1234/sibling_id/foo.json"
          }
        ]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "$ref resolves to /definitions/base_foo, data does not validate", x do
      data = "a"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "$ref resolves to /definitions/base_foo, data validates", x do
      data = 1
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "remote ref, containing refs itself" do
    setup do
      json_schema = %JSV.Schema{"$ref": "http://json-schema.org/draft-07/schema#"}
      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "remote ref valid", x do
      data = %{"minLength" => 1}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "remote ref invalid", x do
      data = %{"minLength" => -1}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "property named $ref that is not a reference" do
    setup do
      json_schema = %JSV.Schema{properties: %JSV.Schema{"$ref": %JSV.Schema{type: "string"}}}
      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "property named $ref valid", x do
      data = %{"$ref" => "a"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "property named $ref invalid", x do
      data = %{"$ref" => 2}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "property named $ref, containing an actual $ref" do
    setup do
      json_schema = %{
        definitions: %{"is-string": %JSV.Schema{type: "string"}},
        properties: %JSV.Schema{
          "$ref": %JSV.Schema{"$ref": "#/definitions/is-string"}
        }
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "property named $ref valid", x do
      data = %{"$ref" => "a"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "property named $ref invalid", x do
      data = %{"$ref" => 2}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "$ref to boolean schema true" do
    setup do
      json_schema = %{
        definitions: %{bool: true},
        allOf: [%JSV.Schema{"$ref": "#/definitions/bool"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "any value is valid", x do
      data = "foo"
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "$ref to boolean schema false" do
    setup do
      json_schema = %{
        definitions: %{bool: false},
        allOf: [%JSV.Schema{"$ref": "#/definitions/bool"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "any value is invalid", x do
      data = "foo"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "Recursive references between schemas" do
    setup do
      json_schema = %{
        "$id": "http://localhost:1234/tree",
        definitions: %{
          node: %JSV.Schema{
            "$id": "http://localhost:1234/node",
            type: "object",
            properties: %{
              subtree: %JSV.Schema{"$ref": "tree"},
              value: %JSV.Schema{type: "number"}
            },
            required: ["value"],
            description: "node"
          }
        },
        type: "object",
        properties: %{
          meta: %JSV.Schema{type: "string"},
          nodes: %JSV.Schema{type: "array", items: %JSV.Schema{"$ref": "node"}}
        },
        required: ["meta", "nodes"],
        description: "tree of nodes"
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "valid tree", x do
      data = %{
        "meta" => "root",
        "nodes" => [
          %{
            "subtree" => %{
              "meta" => "child",
              "nodes" => [%{"value" => 1.1}, %{"value" => 1.2}]
            },
            "value" => 1
          },
          %{
            "subtree" => %{
              "meta" => "child",
              "nodes" => [%{"value" => 2.1}, %{"value" => 2.2}]
            },
            "value" => 2
          }
        ]
      }

      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "invalid tree", x do
      data = %{
        "meta" => "root",
        "nodes" => [
          %{
            "subtree" => %{
              "meta" => "child",
              "nodes" => [%{"value" => "string is invalid"}, %{"value" => 1.2}]
            },
            "value" => 1
          },
          %{
            "subtree" => %{
              "meta" => "child",
              "nodes" => [%{"value" => 2.1}, %{"value" => 2.2}]
            },
            "value" => 2
          }
        ]
      }

      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "refs with quote" do
    setup do
      json_schema = %{
        definitions: %{"foo\"bar": %JSV.Schema{type: "number"}},
        properties: %{"foo\"bar": %JSV.Schema{"$ref": "#/definitions/foo%22bar"}}
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "object with numbers is valid", x do
      data = %{"foo\"bar" => 1}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "object with strings is invalid", x do
      data = %{"foo\"bar" => "1"}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "Location-independent identifier" do
    setup do
      json_schema = %{
        definitions: %{A: %JSV.Schema{"$id": "#foo", type: "integer"}},
        allOf: [%JSV.Schema{"$ref": "#foo"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "match", x do
      data = 1
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "mismatch", x do
      data = "a"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "Reference an anchor with a non-relative URI" do
    setup do
      json_schema = %{
        "$id": "https://example.com/schema-with-anchor",
        definitions: %{A: %JSV.Schema{"$id": "#foo", type: "integer"}},
        allOf: [%JSV.Schema{"$ref": "https://example.com/schema-with-anchor#foo"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "match", x do
      data = 1
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "mismatch", x do
      data = "a"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "Location-independent identifier with base URI change in subschema" do
    setup do
      json_schema = %{
        "$id": "http://localhost:1234/root",
        definitions: %{
          A: %{
            "$id": "nested.json",
            definitions: %{B: %JSV.Schema{"$id": "#foo", type: "integer"}}
          }
        },
        allOf: [%JSV.Schema{"$ref": "http://localhost:1234/nested.json#foo"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "match", x do
      data = 1
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "mismatch", x do
      data = "a"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "naive replacement of $ref with its destination is not correct" do
    setup do
      json_schema = %{
        definitions: %{a_string: %JSV.Schema{type: "string"}},
        enum: [%JSV.Schema{"$ref": "#/definitions/a_string"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "do not evaluate the $ref inside the enum, matching any string", x do
      data = "this is a string"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "do not evaluate the $ref inside the enum, definition exact match", x do
      data = %{"type" => "string"}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "match the enum exactly", x do
      data = %{"$ref" => "#/definitions/a_string"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "refs with relative uris and defs" do
    setup do
      json_schema = %JSV.Schema{
        "$id": "http://example.com/schema-relative-uri-defs1.json",
        properties: %{
          foo: %{
            "$id": "schema-relative-uri-defs2.json",
            definitions: %{
              inner: %JSV.Schema{properties: %{bar: %JSV.Schema{type: "string"}}}
            },
            allOf: [%JSV.Schema{"$ref": "#/definitions/inner"}]
          }
        },
        allOf: [%JSV.Schema{"$ref": "schema-relative-uri-defs2.json"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "invalid on inner field", x do
      data = %{"bar" => "a", "foo" => %{"bar" => 1}}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "invalid on outer field", x do
      data = %{"bar" => 1, "foo" => %{"bar" => "a"}}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "valid on both fields", x do
      data = %{"bar" => "a", "foo" => %{"bar" => "a"}}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "relative refs with absolute uris and defs" do
    setup do
      json_schema = %JSV.Schema{
        "$id": "http://example.com/schema-refs-absolute-uris-defs1.json",
        properties: %{
          foo: %{
            "$id": "http://example.com/schema-refs-absolute-uris-defs2.json",
            definitions: %{
              inner: %JSV.Schema{properties: %{bar: %JSV.Schema{type: "string"}}}
            },
            allOf: [%JSV.Schema{"$ref": "#/definitions/inner"}]
          }
        },
        allOf: [%JSV.Schema{"$ref": "schema-refs-absolute-uris-defs2.json"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "invalid on inner field", x do
      data = %{"bar" => "a", "foo" => %{"bar" => 1}}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "invalid on outer field", x do
      data = %{"bar" => 1, "foo" => %{"bar" => "a"}}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "valid on both fields", x do
      data = %{"bar" => "a", "foo" => %{"bar" => "a"}}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "$id must be resolved against nearest parent, not just immediate parent" do
    setup do
      json_schema = %{
        "$id": "http://example.com/a.json",
        definitions: %{
          x: %JSV.Schema{
            "$id": "http://example.com/b/c.json",
            not: %{definitions: %{y: %JSV.Schema{"$id": "d.json", type: "number"}}}
          }
        },
        allOf: [%JSV.Schema{"$ref": "http://example.com/b/d.json"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "number is valid", x do
      data = 1
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "non-number is invalid", x do
      data = "a"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "simple URN base URI with $ref via the URN" do
    setup do
      json_schema = %JSV.Schema{
        "$id": "urn:uuid:deadbeef-1234-ffff-ffff-4321feebdaed",
        properties: %{
          foo: %JSV.Schema{"$ref": "urn:uuid:deadbeef-1234-ffff-ffff-4321feebdaed"}
        },
        "$comment": "URIs do not have to have HTTP(s) schemes",
        minimum: 30
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "valid under the URN IDed schema", x do
      data = %{"foo" => 37}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "invalid under the URN IDed schema", x do
      data = %{"foo" => 12}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "simple URN base URI with JSON pointer" do
    setup do
      json_schema = %{
        "$id": "urn:uuid:deadbeef-1234-00ff-ff00-4321feebdaed",
        definitions: %{bar: %JSV.Schema{type: "string"}},
        properties: %{foo: %JSV.Schema{"$ref": "#/definitions/bar"}},
        "$comment": "URIs do not have to have HTTP(s) schemes"
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a string is valid", x do
      data = %{"foo" => "bar"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "a non-string is invalid", x do
      data = %{"foo" => 12}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "URN base URI with NSS" do
    setup do
      json_schema = %{
        "$id": "urn:example:1/406/47452/2",
        definitions: %{bar: %JSV.Schema{type: "string"}},
        properties: %{foo: %JSV.Schema{"$ref": "#/definitions/bar"}},
        "$comment": "RFC 8141 §2.2"
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a string is valid", x do
      data = %{"foo" => "bar"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "a non-string is invalid", x do
      data = %{"foo" => 12}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "URN base URI with r-component" do
    setup do
      json_schema = %{
        "$id": "urn:example:foo-bar-baz-qux?+CCResolve:cc=uk",
        definitions: %{bar: %JSV.Schema{type: "string"}},
        properties: %{foo: %JSV.Schema{"$ref": "#/definitions/bar"}},
        "$comment": "RFC 8141 §2.3.1"
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a string is valid", x do
      data = %{"foo" => "bar"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "a non-string is invalid", x do
      data = %{"foo" => 12}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "URN base URI with q-component" do
    setup do
      json_schema = %{
        "$id": "urn:example:weather?=op=map&lat=39.56&lon=-104.85&datetime=1969-07-21T02:56:15Z",
        definitions: %{bar: %JSV.Schema{type: "string"}},
        properties: %{foo: %JSV.Schema{"$ref": "#/definitions/bar"}},
        "$comment": "RFC 8141 §2.3.2"
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a string is valid", x do
      data = %{"foo" => "bar"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "a non-string is invalid", x do
      data = %{"foo" => 12}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "URN base URI with URN and JSON pointer ref" do
    setup do
      json_schema = %{
        "$id": "urn:uuid:deadbeef-1234-0000-0000-4321feebdaed",
        definitions: %{bar: %JSV.Schema{type: "string"}},
        properties: %{
          foo: %JSV.Schema{
            "$ref": "urn:uuid:deadbeef-1234-0000-0000-4321feebdaed#/definitions/bar"
          }
        }
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a string is valid", x do
      data = %{"foo" => "bar"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "a non-string is invalid", x do
      data = %{"foo" => 12}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "URN base URI with URN and anchor ref" do
    setup do
      json_schema = %{
        "$id": "urn:uuid:deadbeef-1234-ff00-00ff-4321feebdaed",
        definitions: %{bar: %JSV.Schema{"$id": "#something", type: "string"}},
        properties: %{
          foo: %JSV.Schema{
            "$ref": "urn:uuid:deadbeef-1234-ff00-00ff-4321feebdaed#something"
          }
        }
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a string is valid", x do
      data = %{"foo" => "bar"}
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "a non-string is invalid", x do
      data = %{"foo" => 12}
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "ref to if" do
    setup do
      json_schema = %JSV.Schema{
        allOf: [
          %JSV.Schema{"$ref": "http://example.com/ref/if"},
          %JSV.Schema{
            if: %JSV.Schema{"$id": "http://example.com/ref/if", type: "integer"}
          }
        ]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a non-integer is invalid due to the $ref", x do
      data = "foo"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "an integer is valid", x do
      data = 12
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "ref to then" do
    setup do
      json_schema = %JSV.Schema{
        allOf: [
          %JSV.Schema{"$ref": "http://example.com/ref/then"},
          %JSV.Schema{
            then: %JSV.Schema{"$id": "http://example.com/ref/then", type: "integer"}
          }
        ]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a non-integer is invalid due to the $ref", x do
      data = "foo"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "an integer is valid", x do
      data = 12
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "ref to else" do
    setup do
      json_schema = %JSV.Schema{
        allOf: [
          %JSV.Schema{"$ref": "http://example.com/ref/else"},
          %JSV.Schema{
            else: %JSV.Schema{"$id": "http://example.com/ref/else", type: "integer"}
          }
        ]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a non-integer is invalid due to the $ref", x do
      data = "foo"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "an integer is valid", x do
      data = 12
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "ref with absolute-path-reference" do
    setup do
      json_schema = %{
        "$id": "http://example.com/ref/absref.json",
        definitions: %{
          a: %JSV.Schema{
            "$id": "http://example.com/ref/absref/foobar.json",
            type: "number"
          },
          b: %JSV.Schema{
            "$id": "http://example.com/absref/foobar.json",
            type: "string"
          }
        },
        allOf: [%JSV.Schema{"$ref": "/absref/foobar.json"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "a string is valid", x do
      data = "foo"
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "an integer is invalid", x do
      data = 12
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "$id with file URI still resolves pointers - *nix" do
    setup do
      json_schema = %{
        "$id": "file:///folder/file.json",
        definitions: %{foo: %JSV.Schema{type: "number"}},
        allOf: [%JSV.Schema{"$ref": "#/definitions/foo"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "number is valid", x do
      data = 1
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "non-number is invalid", x do
      data = "a"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "$id with file URI still resolves pointers - windows" do
    setup do
      json_schema = %{
        "$id": "file:///c:/folder/file.json",
        definitions: %{foo: %JSV.Schema{type: "number"}},
        allOf: [%JSV.Schema{"$ref": "#/definitions/foo"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "number is valid", x do
      data = 1
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "non-number is invalid", x do
      data = "a"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end

  describe "empty tokens in $ref json-pointer" do
    setup do
      json_schema = %{
        definitions: %{"": %{definitions: %{"": %JSV.Schema{type: "number"}}}},
        allOf: [%JSV.Schema{"$ref": "#/definitions//definitions/"}]
      }

      schema = JsonSchemaSuite.build_schema(json_schema, default_meta: "http://json-schema.org/draft-07/schema")
      {:ok, json_schema: json_schema, schema: schema}
    end

    test "number is valid", x do
      data = 1
      expected_valid = true
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end

    test "non-number is invalid", x do
      data = "a"
      expected_valid = false
      JsonSchemaSuite.run_test(x.json_schema, x.schema, data, expected_valid, print_errors: false)
    end
  end
end
