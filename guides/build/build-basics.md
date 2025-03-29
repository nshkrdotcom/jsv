# Building Schemas


To validate data with schemas, `JSV` turns the schemas into a custom data
structure made specifically for validation.

It does not validate data with raw schemas directly, that would be too slow and
would not work properly with advanced features of Draft 2020-12 such as
`$dynamicRef` and `$dynamicAnchor`.

Instead, raw schemas are processed by a set of different "vocabulary" modules
that are each specialized in some part of the validation. The result of this
processing is then collected as a `JSV.Root` struct.

This guide covers the configuration and customization of this process to better
serve your needs.


## The build functions

The main build function is `JSV.build/2`. It accepts a raw schema and a set of
options, and returns the root.

There are variations around that function, which is very classic in Elixir:
`JSV.build/1` with default options, `JSV.build!/1` and `JSV.build!/2` with or
without default options that raise errors instead of returning an error tuple.


## Custom build modules

The build functions are not using macros or process-based techniques. We
encourage you to wrap them and define your options in a single place:

```elixir
defmodule MyApp.SchemaBuilder do

  def build(raw_schema) do
   JSV.build(raw_schema, build_opts())
  end

  def build!(raw_schema) do
    JSV.build!(raw_schema, build_opts())
  end

  defp build_opts do
    [resolver: MyApp.CustomSchemaResolver, formats: true]
  end
end
```


## Compile-time builds


Validation roots can be built at runtime, but it is recommended to rather build
during compilation, if possible, to avoid repeating the build step for no good
reason.

Building at runtime should be done when the JSON schema is not available during
compilation.

For instance, if we have this function that should validate external data:

```elixir
# DO NOT DO THAT

defp order_schema do
  "priv/schemas/order.schema.json"
    |> File.read!()
    |> JSON.decode!()
    |> JSV.build!()
end

def validate_order(order) do
  case JSV.validate(order, order_schema()) do
    {:ok, _} -> OrderHandler.handle_order(order)
    {:error, _} = err -> err
  end
end
```

The schema will be built each time the function is called. Building a schema is
actually pretty fast but it is a waste of resources nevertheless. In this
example it is obvious that you would not want to read from a file in every call
of the ` validate_order`. But it will generally be wrapped in custom function,
or a build module as suggested above.

Make sure those builds are called at compile-time:


```elixir
# Do this instead

@order_schema "priv/schemas/order.schema.json"
              |> File.read!()
              |> JSON.decode!()
              |> JSV.build!()

defp order_schema, do: @order_schema

def validate_order(order) do
  case JSV.validate(order, order_schema()) do
    {:ok, _} -> OrderHandler.handle_order(order)
    {:error, _} = err -> err
  end
end
```


## Enable format validation

> ### No format validation by default {: .warning}
> By default, the `https://json-schema.org/draft/2020-12/schema` meta schema
> **does not perform format validation**. This is very counter intuitive, but it
> basically means that the following code is correct:

```elixir
root = JSV.build!(%{type: :string, format: :date})
{:ok, "not a date"} = JSV.validate("not a date", root)
```

The `format` schema keyword is totally ignored. This is bad, but it is the spec!
To always enable format validation when building a root schema, provide the
`formats: true` option to `JSV.build/2`:

```elixir
JSV.build(raw_schema, formats: true)
```

This is another reason to wrap `JSV.build/2` with a custom builder module, so
you don't forget to enable those.

Note that format validation is determined at build time. There is no way to
change whether it is performed once the root schema is built.


## Enable format validation using vocabularies

You can also enable format validation by using the JSON Schema specification
semantics, though **it is far simpler and less error prone to use the `:formats`
option**.

For format validation to be enabled, a schema should declare the
`https://json-schema.org/draft/2020-12/vocab/format-assertion` vocabulary
instead of the `https://json-schema.org/draft/2020-12/vocab/format-annotation`
one that is included by default in the
`https://json-schema.org/draft/2020-12/schema` meta schema.

### 1. Use a new meta schema with format-assertion

```json
{
    "$id": "custom://with-formats-on/",
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$vocabulary": {
        "https://json-schema.org/draft/2020-12/vocab/core": true,
        "https://json-schema.org/draft/2020-12/vocab/format-assertion": true
    },
    "$dynamicAnchor": "meta",
    "allOf": [
        { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
      { "$ref": "https://json-schema.org/draft/2020-12/meta/ format-assertion" }
    ]
}
```

This example is taken from the [JSON Schema Test
Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite) codebase and
does not include all the vocabularies, only the assertion for the formats and
the core vocabulary. It will not validate anything else than formats.

### 2. Declare a schema using that meta schema to perform validation.

You will need a [custom resolver](guides/build/resolvers.md) to resolve the
given URL for the new `$schema` property.

```elixir
schema =
  JSON.decode!("""
  {
    "$schema": "custom://with-formats-on/",
    "type": "string",
    "format": "date"
  }
  """)

root = JSV.build!(schema, resolver: ...)
```

### 3. Validate

Now it will work as expected, `JSV.validate/2` returns an error tuple without
needing the `formats: true`.

```elixir
{:error, _} = JSV.validate("hello", root)
```

### Reverse use-case

If one of your schemas is using such a meta-schema and you wnat to _disable_ the
formats validation then the following will work:

```elixir
JSV.build(raw_schema, formats: false)
```








