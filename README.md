# JSV

A JSON Schema Validation library for Elixir with support for the 2020-12 JSON
Schema specification.



## Installation

```elixir
def deps do
  [
    {:jsv, "~> 0.1"},
  ]
end
```

Additional dependencies can be added to support more features:

```elixir
def deps do
  [
    # Optional for JSON support prior to Elixir 1.18
    {:jason, "~> 1.0"},
    {:poison, "~> 6.0 or ~> 5.0"},

    # Optional for better formats support
    {:mail_address, "~> 1.0"},
    {:abnf_parsec, "~> 1.0"},
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

## Documentation

The [API documentation is available on hexdocs.pm](https://hexdocs.pm/jsv/).

This document describes general considerations and recipes to use the library.

## Table of contents

- [Installation](#installation)
- [Basic usage](#basic-usage)
- [Documentation](#documentation)
- [Table of contents](#table-of-contents)
- [Loading and building schemas](#loading-and-building-schemas)
  - [Introduction to vocabularies](#introduction-to-vocabularies)
  - [Schema format](#schema-format)
  - [The resolver option](#the-resolver-option)
  - [Custom build module](#custom-build-module)
  - [Compile-time builds](#compile-time-builds)
- [Resolvers](#resolvers)
  - [Built-in resolver](#built-in-resolver)
  - [Custom resolvers](#custom-resolvers)
- [Format validation](#format-validation)
  - [Disabled by default in vocabulary](#disabled-by-default-in-vocabulary)
  - [Enable / disable format validation](#enable--disable-format-validation)
  - [Supported formats \& casted values](#supported-formats--casted-values)
    - [date](#date)
    - [date-time](#date-time)
    - [duration](#duration)
    - [email](#email)
    - [hostname](#hostname)
    - [ipv4](#ipv4)
    - [ipv6](#ipv6)
    - [iri](#iri)
    - [iri-reference](#iri-reference)
    - [json-pointer](#json-pointer)
    - [regex](#regex)
    - [relative-json-pointer](#relative-json-pointer)
    - [time](#time)
    - [unknown](#unknown)
    - [uri](#uri)
    - [uri-reference](#uri-reference)
    - [uri-template](#uri-template)
    - [uuid](#uuid)
  - [Custom formats](#custom-formats)
- [Roadmap](#roadmap)



## Loading and building schemas

In this chapter we will see how to build schemas from raw resources. The
examples will mention the `JSV.build/2` or `JSV.build!/2` functions
interchangeably. Everything described here applies to both.

Schemas are built according to their meta-schema vocabulary. **JSV will assume
that the `$schema` value is `"https://json-schema.org/draft/2020-12/schema"` by
default if not provided.**

Once built, a schema is converted into a `JSV.Root`, an internal representation
of the schema that can be used to perform validation.

### Introduction to vocabularies

JSV was built in compliance with the vocabulary mechanism of JSON schema, to
support custom and optional keywords in the schemas.

It may be more clear with an example:

1. The well-known and official schema
   `https://json-schema.org/draft/2020-12/schema` defines the following
   vocabulary:

   ```json
   {
     "$vocabulary": {
       "https://json-schema.org/draft/2020-12/vocab/core": true,
       "https://json-schema.org/draft/2020-12/vocab/applicator": true,
       "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
       "https://json-schema.org/draft/2020-12/vocab/validation": true,
       "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
       "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
       "https://json-schema.org/draft/2020-12/vocab/content": true
     }
   }
   ```

   The vocabulary is split in different parts, here one by object property.
   More information can be found on the [official
   website](https://json-schema.org/learn/glossary#vocabulary).

2. Implementations such as JSV must map this vocabulary to implementations. For
   instance, in JSV, the
   `https://json-schema.org/draft/2020-12/json-schema-validation` part that
   defines the `type` keyword is implemented with the
   `JSV.Vocabulary.V202012.Validation` Elixir module.

3. Finally, we can declare a schema that would like to use the `type` keyword.
   To let the library know what implementation to use for that keyword, the
   schema declares the `https://json-schema.org/draft/2020-12/schema` as its
   meta-schema (using the `$schema` keyword).

   ```json
   {
     "$schema": "https://json-schema.org/draft/2020-12/schema",
     "type": "integer"
   }
   ```

   This tells the library to pull the vocabulary from the meta-schema and apply
   it to the schema.

4. As JSV is compliant, it will use its implementation of
   `https://json-schema.org/draft/2020-12/json-schema-validation` to validate
   types.

   This also means that you can use a custom meta schema to skip some parts of
   the vocabulary, or add your own.



### Schema format

"Raw schemas" are schemas defined in Elixir data structures such as `%{"type" =>
"integer"}`.

JSV does not accept JSON strings. You will need to decode the JSON strings
before giving them to the build function. There are three different possible
formats for a schema:

1. **A boolean**. Booleans are valid schemas that accept anything (when `true`) or
   reject everything (when `false`).
2. **A map with binary keys and values** such as `%{"type" => "integer"}`.
3. **A map with atom keys and values** such as `%{type :integer}`. The `:__struct__`
   property of such maps is safely ignored.

   The `JSV.Schema` struct can be used for autocompletion, but it does not
   provide any special behaviour over a raw map with atoms. The only difference
   is that any `nil` value found in the struct will be ignored. `nil` values in
   other maps or structs with atom keys are treated as-is (it's generally
   invalid).

   Atoms are converted to binaries internally so it is technically possible to
   mix atom with binaries in map keys, but the behaviour for duplicate keys is
   not defined: `%{"type" => "string", :type => "integer"}`.

### The resolver option

In order to build schemas properly, JSV needs to _resolve_ the schema as a first
step.

Resolving means fetching any remote resource whose data is needed and not
available ; basically resources whose
[URIs](https://fr.wikipedia.org/wiki/Uniform_Resource_Identifier) are defined as
`$schema`, `$ref` or `$dynamicRef`. Of course relative references do not need to
be fetched.

Those URIs are generally URLs with the `http://` or `https://` scheme, but there
are countless ways to fetch those URLs.

For security reasons, JSV does not provide a _default_ resolver that would fetch
those resources with an HTTP call. It is always required to provide the resolver
option.

For convenience reasons, a _built-in_ resolver (`JSV.Resolver.BuiltIn`) is
provided but it still needs to be manually declared by users of the JSV library.
That resolver will download given URLs from the web. Refer to the documentation
of this module for more information.

Also make sure to read the "Resolvers" section of this guide.

### Custom build module

With that in mind, we suggest to define a custom module to wrap the
`JSV.build/2` function, so the resolver configuration, as well as
error-handling, can be defined only once.

That module could be implemented like this:

```elixir
defmodule MyApp.SchemaBuilder do
  @moduledoc false

  def resolver do
    {JSV.Resolver.BuiltIn,
     allowed_prefixes: [
       "https://json-schema.org/",
       "https://my-company.com/schemas/"
     ]}
  end

  def build_schema!(raw_schema) do
    JSV.build!(raw_schema, resolver: resolver())
  end
end
```

Of course, using `JSV.build/2` anywhere is totally valid.

### Compile-time builds

It is strongly encouraged to build schemas at compile time, in order to avoid
repeating the build step for no good reason.

For instance, if we have this function that should validate external data:

```elixir
# Do not do this

def validate_order(order) do
  root =
    "priv/schemas/order.schema.json"
    |> File.read!()
    |> JSON.decode!()
    |> MyApp.SchemaBuilder.build_schema!()

  case JSV.validate(order, root) do
    {:ok, _} -> OrderHandler.handle_order(order)
    {:error, _} = err -> err
  end
end
```

The schema will be built each time the function is called. Building a schema is
actually pretty fast but it is a waste of resources nevertheless.

One could do the following to get a net performance gain:


```elixir
# Do this instead

@order_schema "priv/schemas/order.schema.json"
              |> File.read!()
              |> JSON.decode!()
              |> MyApp.SchemaBuilder.build_schema!()

defp order_schema, do: @order_schema

def validate_order(order) do
  case JSV.validate(order, order_schema()) do
    {:ok, _} -> OrderHandler.handle_order(order)
    {:error, _} = err -> err
  end
end
```

With that in mind, you can also define a module where all your schemas are built
and exported as functions:

```elixir
defmodule MyApp.Schemas do
  schemas = [
    order: "tmp/order.schema.json",
    shipping: "tmp/shipping.schema.json"
  ]

  Enum.each(schemas, fn {fun, path} ->
    root =
      path
      |> File.read!()
      |> JSON.decode!()
      |> MyApp.SchemaBuilder.build_schema!()

    def unquote(fun)() do
      unquote(Macro.escape(root))
    end
  end)
end
```

...and use it elsewhere:

```elixir
def validate_order(order) do
  case JSV.validate(order, MyApp.Schemas.order()) do
    {:ok, _} -> OrderHandler.handle_order(order)
    {:error, _} = err -> err
  end
end
```



## Resolvers

### Built-in resolver

As mentioned, the built-in resolver is there to help for common use cases, but
you may need to resolve resources from custom locations instead of just fetching
the web URL.

In order for that resolver to work, it must be able to decode JSON content from
the web. To do so, you will need to provide a valid JSON implementation:

* From Elixir 1.18, the `JSON` module is automatically available in the standard
  library.
* JSV can use [Jason](https://hex.pm/packages/jason) if listed in your
  dependencies with the  `"~> 1.0"` requirement.
* JSV also supports [Poison](https://hex.pm/packages/poison) with the "~> 6.0 or
  ~> 5.0" requirement.

This

### Custom resolvers

`JSV.build/2` accepts any resolver implementation as long as it implements the
`JSV.Resolver` behaviour. See the documentation of that behaviour for more
information.

It is also possible to delegate to that resolver. If for instance we support a
`my-company://` custom scheme, we could define the behaviour like so:

```elixir
defmodule MyApp.SchemaResolver do
  alias JSV.Resolver.BuiltIn

  def resolve("my-company://" <> _ = url, _opts) do
    uri = URI.parse(url)
    schema_dir = "priv/schemas"
    # In this example the hostname in URL is ignored
    schema_path = Path.join(schema_dir, uri.path)
    json_schema = File.read!(schema_path)
    JSON.decode(json_schema)
  end

  def resolve("https://" <> _url, _opts) do
    JSV.Resolver.BuiltIn.resolve(url,
      allowed_prefixes: [
        "https://json-schema.org/",
        "https://some-friend-company/",
        "https://some-other-provider/"
      ]
    )
  end
end
```

It can be used as usual:

```elixir
JSV.build(raw_schema, resolver: MyApp.SchemaResolver)
```

## Format validation

### Disabled by default in vocabulary

By default, the `https://json-schema.org/draft/2020-12/schema` meta schema
**does not perform format validation**. This is very counter intuitive, but it
basically means that the following code will return `{:ok, "hello"}`:

```elixir
schema =
  JSON.decode!("""
  {
    "type": "string",
    "format": "date"
  }
  """)

root = JSV.build!(schema, resolver: ...)

JSV.validate("hello", root)
```

JSV provides a simple way to fix this, but first we will explain the official
way of validating formats.

For format validation to be enabled, a schema should declare the
`https://json-schema.org/draft/2020-12/vocab/format-assertion` vocabulary
instead of the `https://json-schema.org/draft/2020-12/vocab/format-annotation`
one that is included by default in the
`https://json-schema.org/draft/2020-12/schema` meta schema.

So, first we would declare a new meta schema:

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
        { "$ref": "https://json-schema.org/draft/2020-12/meta/format-assertion" }
    ]
}
```

This example is taken from the [JSON Schema Test
Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite) codebase and
does not includes all the vocabularies. But it includes the assertion for the
formats.

Then we would declare our schema using that vocabulary to perform validation. Of
course our resolver must be able to resolve the given URL for the new `$schema`
property.

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

With this new meta-schema, `JSV.validate/2` would return an error tuple:

```elixir
{:error, _} = JSV.validate("hello", root)
```

### Enable / disable format validation

To always enable format validation when building a root schema, provide the
`formats: true` option to `JSV.build/2`:

```elixir
JSV.build(raw_schema, resolver: ..., formats: true)
```

This is another reason to wrap `JSV.build` with a custom builder module.

Note that format validation is determined at build time. There is no way to
change whether it is performed once the root schema is built.

It is also possible to _disable_ the validation for schemas that use a
meta-schema where the assertion vocabulary is declared:

```elixir
JSV.build(raw_schema, resolver: ..., formats: false)
```


### Supported formats & casted values

JSV supports multiple formats out of the box with its default implementation,
but some are only available under certain conditions that will be specified for
each format.

The following listing describes the condition for support and return value type
for these default implementations. You can override those implementations by
providing your own, as well as providing new formats. This will be described
later in this document.

Also, note that by default, JSV format validation will return the original
value, that is, the string form of the data. Some format validators can also
cast the string to a more interesting data structure, for instance converting a
date string to a `Date` struct. You can enable returning casted values by
passing the `cast_formats: true` option to `JSV.validate/3`.

The listing below describe values returned with that option enabled.

**Important**: Some formats require the `abnf_parsec` library to be available.
But we have numerous problems with this library, yielding false negatives with
many inputs. An alternative solution will be implemented in future versions.

<!-- block:formats-table -->
#### date

* **support**: Native.
* **input**: `"2020-04-22"`
* **output**: `~D[2020-04-22]`
* The format is implemented with the native `Date` module.
* The native `Date` module supports the `YYYY-MM-DD` format only. `2024`, `2024-W50`, `2024-12` will not be valid.

#### date-time

* **support**: Native.
* **input**: `"2025-01-02T00:11:23.416689Z"`
* **output**: `~U[2025-01-02 00:11:23.416689Z]`
* The format is implemented with the native `DateTime` module.
* The native `DateTime` module supports the `YYYY-MM-DD` format only for dates. `2024T...`, `2024-W50T...`, `2024-12T...` will not be valid.
* Decimal precision is not capped to milliseconds. `2024-12-14T23:10:00.500000001Z` will be valid.

#### duration

* **support**: Requires Elixir 1.17
* **input**: `"P1DT4,5S"`
* **output**: `%Duration{day: 1, second: 4, microsecond: {500000, 1}}`
* Elixir documentation states that _Only seconds may be specified with a decimal fraction, using either a comma or a full stop: P1DT4,5S_.
* Elixir durations accept negative values.
* Elixir durations accept out-of-range values, for instance more than 59 minutes.
* Excessive precision (as in `"PT10.0000000000001S"`) will be valid.

#### email

* **support**: Requires `{:mail_address, "~> 1.0"}`.
* **input**: `"hello@json-schema.org"`
* **output**: `"hello@json-schema.org"` (same value)
* Support is limited by the implementation of that library.
* The `idn-email` format is not supported out-of-the-box.

#### hostname

* **support**: Native
* **input**: `"some-host"`
* **output**: `"some-host"` (same value)

#### ipv4

* **support**: Native
* **input**: `"127.0.0.1"`
* **output**: `{127, 0, 0, 1}`

#### ipv6

* **support**: Native
* **input**: `"::1"`
* **output**: `{0, 0, 0, 0, 0, 0, 0, 1}`

#### iri

* **support**: Requires `{:abnf_parsec, "~> 1.0"}`.
* **input**: `"https://héhé.com/héhé"`
* **output**: `%URI{scheme: "https", authority: "héhé.com", userinfo: nil, host: "héhé.com", port: 443, path: "/héhé", query: nil, fragment: nil}`

#### iri-reference

* **support**: Requires `{:abnf_parsec, "~> 1.0"}`.
* **input**: `"//héhé"`
* **output**: `%URI{scheme: nil, authority: "héhé", userinfo: nil, host: "héhé", port: nil, path: nil, query: nil, fragment: nil}`

#### json-pointer

* **support**: Requires `{:abnf_parsec, "~> 1.0"}`.
* **input**: `"/foo/bar/baz"`
* **output**: `"/foo/bar/baz"` (same value)

#### regex

* **support**: Native
* **input**: `"[a-zA-Z0-9]"`
* **output**: `~r/[a-zA-Z0-9]/`
* The format is implemented with the native `Regex` module.
* The `Regex` module does not follow the `ECMA-262` specification.

#### relative-json-pointer

* **support**: Requires `{:abnf_parsec, "~> 1.0"}`.
* **input**: `"0/foo/bar"`
* **output**: `"0/foo/bar"` (same value)

#### time

* **support**: Native
* **input**: `"20:20:08.378586"`
* **output**: `~T[20:20:08.378586]`
* The format is implemented with the native `Time` module.
* The native `Time` implementation will completely discards the time offset information. Invalid offsets will be valid.
* Decimal precision is not capped to milliseconds. `23:10:00.500000001` will be valid.

#### unknown

* **support**: Native
* **input**: `"anything"`
* **output**: `"anything"` (same value)
* No validation or transformation is done.

#### uri

* **support**: Native, optionally uses `{:abnf_parsec, "~> 1.0"}`.
* **input**: `"http://example.com"`
* **output**: `%URI{scheme: "http", authority: "example.com", userinfo: nil, host: "example.com", port: 80, path: nil, query: nil, fragment: nil}`
* Without the optional dependency, the `URI` module is used and a minimum checks on hostname and scheme presence are made.

#### uri-reference

* **support**: Native, optionally uses `{:abnf_parsec, "~> 1.0"}`.
* **input**: `"/example-path"`
* **output**: `%URI{scheme: nil, userinfo: nil, host: nil, port: nil, path: "/example-path", query: nil, fragment: nil}`
* Without the optional dependency, the `URI` module will cast most non url-like strings as a `path`.

#### uri-template

* **support**: Requires `{:abnf_parsec, "~> 1.0"}`.
* **input**: `"http://example.com/search{?query,lang}"`
* **output**: `"http://example.com/search{?query,lang}"` (same value)

#### uuid

* **support**: Native
* **input**: `"bf22824c-c8a4-11ef-9642-0fdaf117eeb9"`
* **output**: `"bf22824c-c8a4-11ef-9642-0fdaf117eeb9"` (same value)


<!-- endblock:formats-table -->


### Custom formats

In order to provide custom formats, or to override default implementations for
formats, you may provide a list of modules as the value for the `:formats`
options of `JSV.build/2`. Such modules must implement the `JSV.FormatValidator`
behaviour.

For instance:

```elixir
defmodule CustomFormats do
  @behaviour JSV.FormatValidator

  @impl JSV.FormatValidator
  def supported_formats do
    ["greeting"]
  end

  @impl JSV.FormatValidator
  def validate_cast("greeting", data) do
    case data do
      "hello " <> name -> {:ok, %Greeting{name: name}}
      _ -> {:error, :invalid_greeting}
    end
  end
end
```

With this module you can now call the builder with it:

```elixir
JSV.build!(raw_schema, resolver: ..., formats: [CustomFormats])
```

Note that this will disable all other formats. If you need to still support the
default formats, a helper is available:

```elixir
JSV.build!(raw_schema,
  resolver: ...,
  formats: [CustomFormats | JSV.default_format_validator_modules()]
)
```

Format validation modules are checked during the build phase, in order. So you
can override any format defined by a module that comes later in the list,
including the default modules.

## Roadmap

- Support for custom vocabularies
- Declare a JSON codec module directly as built-in resolver option. This will be
  implemented if needed, we do not think there will be a strong demand for that.