# JSV

A JSON Schema Validation library for Elixir with support for the 2020-12 JSON
Schema specification.



## Installation

```elixir
def deps do
  [
    {:jsv, "~> 0.1"}
  ]
end
```



## Basic usage

The following snippet describes the general usage of the library in any context.
The rest of documentation describes how to build schemas at compile time and how
to simplify your workflow.

```elixir
# 1. Define a schema.
#
# It must be given as Elixir data, not as a JSON string.
# Atoms and binaries are allowed.
schema = %{
  type: :object,
  properties: %{
    name: %{type: :string}
  },
  required: [:name]
}

# 2. Define a resolver.
#
# This is mandatory and it allows the library to retrieve metadata
# information for the schemas.
#
# The built-in resolver is fine for most use cases.
resolver = {JSV.Resolver.BuiltIn, allowed_prefixes: ["https://json-schema.org/"]}

# 3. Build the schema
#
# This returns the root schema ready for validation.
root = JSV.build!(schema, resolver: resolver)

# 4. Validate your data with the root schema.
#
# Here, only binary data is accepted.
# You can convert your data to binary forms with JSV.AtomTools first.
JSV.validate(%{"name" => "Alice"}, root)
# {:ok, %{"name" => "Alice"}}

# 5. Transform errors into a JSON-able output for your API
{:error, validation_error} = JSV.validate(%{"name" => 123}, root)
validation_error |> JSV.normalize_error() |> JSON.encode!()
```

The last error from the above snippet will return a JSON output with the
following data (prettified for documentation purposes):

```JSON
{
  "valid": false,
  "details": [
    {
      "errors": [
        {
          "message": "property 'name' did not conform to the property schema",
          "kind": "properties"
        }
      ],
      "valid": false,
      "schemaLocation": "",
      "instanceLocation": "",
      "evaluationPath": ""
    },
    {
      "errors": [
        {
          "message": "value is not of type string",
          "kind": "type"
        }
      ],
      "valid": false,
      "schemaLocation": "/properties/name",
      "instanceLocation": "/name",
      "evaluationPath": "/properties/name"
    }
  ]
}
```