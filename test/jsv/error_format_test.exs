defmodule JSV.ErrorFormatTest do
  alias JSV
  alias JSV.AtomTools
  alias JSV.Codec
  alias JSV.Schema
  use ExUnit.Case, async: true

  defp build_schema!(json_schema, opts \\ []) do
    {:ok, schema} = JSV.build(json_schema, [resolver: JSV.Test.TestResolver] ++ opts)
    schema
  end

  defp valid_message(exception) do
    case Exception.message(exception) do
      "got " <> _ = bad_msg ->
        ["got " <> _, rest] = String.split(bad_msg, "with message ")

        flunk("""
        Exception could not produce a message:

        #{rest}
        """)

      v ->
        v
    end
  end

  @error_output_schema %Schema{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "jsv://error-output",
    "$defs": %{
      output_unit:
        Schema.object(
          properties: %{
            valid: Schema.boolean(),
            schemaLocation: Schema.string(),
            evaluationPath: Schema.string(),
            instanceLocation: Schema.string(),
            # output units have errors, a list of error annotations
            errors: Schema.items(Schema.ref("#/$defs/error_annot")),
            # output units have other nested units
            details: Schema.items(Schema.ref("#/$defs/output_unit"))
          },
          required: [:valid]
        ),
      error_annot:
        Schema.object(
          properties: %{
            kind: Schema.string(),
            message: Schema.string(),
            # Error have details, i.e. a list of sub output units
            details: Schema.items(Schema.ref("#/$defs/output_unit"))
          },
          required: [:kind, :message]
        )
    },
    "$ref": "#/$defs/output_unit"
  }

  defp assert_output_schema(formatted_error) do
    {:ok, output_schema} = JSV.build(@error_output_schema, resolver: JSV.Test.TestResolver)
    raw = AtomTools.normalize_schema(formatted_error)

    case JSV.validate(raw, output_schema) do
      {:ok, _} ->
        true

      {:error, ve} ->
        flunk("""
        Error output did not validate output schema:

        # DATA
        #{inspect(raw, pretty: true)}

        # ERRORS
        #{inspect(JSV.normalize_error(ve), pretty: true)}
        """)
    end
  end

  test "sample example from json-schema.org blog" do
    schema =
      build_schema!(
        Codec.decode!(~S"""
        {
          "$id": "https://example.com/polygon",
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$defs": {
            "point": {
              "$id": "pointSchema",
              "type": "object",
              "properties": {
                "x": { "type": "number" },
                "y": { "type": "number" }
              },
              "additionalProperties": false,
              "required": [ "x", "y" ]
            }
          },
          "type": "array",
          "items": { "$ref": "#/$defs/point" },
          "prefixItems": [
          {"type": "number"}
          ],
          "minItems": 3
        }
        """)
      )

    invalid_data = [
      %{
        "x" => 2.5,
        "y" => 1.3
      },
      %{
        "x" => 1,
        "z" => 6.7
      }
    ]

    assert {:error, validation_error} = JSV.validate(invalid_data, schema)
    formatted_error = JSV.normalize_error(validation_error)
    assert_output_schema(formatted_error)
    assert valid_message(validation_error) =~ "at:"
  end

  test "error formatting for none of anyOf" do
    schema =
      build_schema!(
        Codec.decode!(~S"""
        {
          "$id": "https://example.com/anyOfExample",
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$defs": {
            "some-def": {
              "maxProperties": 0
            }
          },
          "properties": {
            "a": {
              "properties": {
                "b": {
                  "$ref": "#/$defs/some-def",
                  "required": ["foo"],
                  "properties": {
                    "foo": {
                      "anyOf": [
                        {"type": "number"},
                        {
                          "properties": {"bar": {"type": "number"}},
                          "required": ["bar"]
                        }
                      ]
                    }
                  }
                }
              }
            }
          }
        }
        """)
      )

    invalid_data = %{"a" => %{"b" => %{"foo" => %{"bar" => "baz"}}}}

    assert {:error, validation_error} = JSV.validate(invalid_data, schema)
    formatted_error = JSV.normalize_error(validation_error)

    assert_output_schema(formatted_error)
    assert valid_message(validation_error) =~ "at:"
  end

  test "error formatting for not all of allOf" do
    schema =
      build_schema!(
        Codec.decode!(~S"""
        {
          "$id": "https://example.com/anyOfExample",
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "properties": {
            "foo": {
              "allOf": [
                {
                  "properties": {"bar": {"type": "number"}},
                  "required": ["bar"]
                },
                {
                  "properties": {"baz": {"type": "number"}},
                  "required": ["baz"]
                },
                {
                  "properties": {"qux": {"type": "number"}},
                  "required": ["qux"]
                }
              ]
            }
          },
          "required": ["foo"]
        }
        """)
      )

    invalid_data = %{"foo" => %{"bar" => 1, "baz" => "a string"}}

    assert {:error, validation_error} = JSV.validate(invalid_data, schema)
    formatted_error = JSV.normalize_error(validation_error)

    assert_output_schema(formatted_error)
    assert valid_message(validation_error) =~ "at:"
  end

  test "error formatting for more than one of oneOf" do
    schema =
      build_schema!(
        Codec.decode!(~S"""
        {
          "$id": "https://example.com/anyOfExample",
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "properties": {
            "foo": {
              "oneOf": [
                {
                  "properties": {"bar": {"type": "number"}},
                  "required": ["bar"]
                },
                {
                  "properties": {"baz": {"type": "number"}},
                  "required": ["baz"]
                },
                {
                  "properties": {"qux": {"type": "number"}},
                  "required": ["qux"]
                }
              ]
            }
          },
          "required": ["foo"]
        }
        """)
      )

    # validates only schemas of index 0 and 2, not 1
    invalid_data = %{"foo" => %{"bar" => 1, "qux" => 1}}

    assert {:error, validation_error} = JSV.validate(invalid_data, schema)
    formatted_error = JSV.normalize_error(validation_error)
    assert_output_schema(formatted_error)
    assert valid_message(validation_error) =~ "at:"
  end

  test "error formatting for if / else" do
    schema =
      build_schema!(
        Codec.decode!(~S"""
        {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "type": "object",
          "properties": {
            "age": {
              "type": "integer",
              "minimum": 0
            }
          },
          "required": ["age"],

          "if": {
            "properties": {
              "age": { "minimum": 18 }
            },
            "required": ["age"]
          },
          "then": {
            "required": ["driverLicense"],
            "properties": {
              "driverLicense": {
                "type": "string"
              }
            }
          },
          "else": {
            "properties": {
              "guardianName": {
                "type": "string"
              }
            },
            "required": ["guardianName"]
          }
        }
        """)
      )

    # validates the 'if' but not the 'then'

    invalid_data = %{"age" => 25}
    assert {:error, validation_error} = JSV.validate(invalid_data, schema)
    formatted_error = JSV.normalize_error(validation_error)
    assert_output_schema(formatted_error)
    assert valid_message(validation_error) =~ "at:"

    # does not validate 'if' nor 'else'

    invalid_data = %{"age" => 12, "guardianName" => 123}
    assert {:error, validation_error} = JSV.validate(invalid_data, schema)
    formatted_error = JSV.normalize_error(validation_error)
    assert_output_schema(formatted_error)
    assert valid_message(validation_error) =~ "at:"
  end

  test "error formatting for additionalProperties: false" do
    schema = %{properties: %{a: %{type: :integer}}, additionalProperties: false}
    root = JSV.build!(schema)

    assert {:ok, %{"a" => 1}} = JSV.validate(%{"a" => 1}, root)
    assert {:error, err} = JSV.validate(%{"a" => 1, "b" => 2}, root)

    # In case additionalProperties is a boolean schema we want a custom message,
    # so we must have the info in the error (boolean_schema_false: true) here:

    assert %JSV.ValidationError{errors: [%JSV.Validator.Error{args: [key: "b", boolean_schema_false: true]}, _]} = err

    assert %{
             valid: false,
             details: [
               %{
                 errors: [
                   # Here is the custom message in that case
                   %{
                     message: message,
                     kind: :additionalProperties
                   }
                 ],
                 valid: false,
                 schemaLocation: "",
                 evaluationPath: "",
                 instanceLocation: ""
               },
               %{
                 errors: [%{message: "value was rejected from boolean schema: false", kind: :boolean_schema}],
                 valid: false,
                 schemaLocation: "/additionalProperties",
                 evaluationPath: "/additionalProperties",
                 instanceLocation: "/b"
               }
             ]
           } =
             JSV.normalize_error(err)

    assert "additional properties are not allowed but found property 'b'" == message
  end
end
