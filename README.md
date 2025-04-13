# JSV

<!-- rdmx :badges
    hexpm         : "jsv?color=4e2a8e"
    github_action : "lud/jsv/elixir.yaml?label=CI&branch=main"
    license       : jsv
    -->
[![hex.pm Version](https://img.shields.io/hexpm/v/jsv?color=4e2a8e)](https://hex.pm/packages/jsv)
[![Build Status](https://img.shields.io/github/actions/workflow/status/lud/jsv/elixir.yaml?label=CI&branch=main)](https://github.com/lud/jsv/actions/workflows/elixir.yaml?query=branch%3Amain)
[![License](https://img.shields.io/hexpm/l/jsv.svg)](https://hex.pm/packages/jsv)
<!-- rdmx /:badges -->

JSV is a JSON Schema Validation library for Elixir with full support for the latest JSON Schema specification.

## Documentation

[API documentation is available on hexdocs.pm](https://hexdocs.pm/jsv/).

## Installation

<!-- rdmx :app_dep vsn:$app_vsn -->
```elixir
def deps do
  [
    {:jsv, "~> 0.6"},
  ]
end
```
<!-- rdmx /:app_dep -->

Additional dependencies can be added to support more features:

```elixir
def deps do
  [
    # Optional libraries for enhanced format validation

    # Email validation
    {:mail_address, "~> 1.0"},

    # URI, IRI, and JSON-pointer validation
    {:abnf_parsec, "~> 1.0"},

    # Optional libraries for decoding schemas resolved via HTTP
    # (required for Elixir versions prior to 1.18)

    {:jason, "~> 1.0"},
    # OR
    {:poison, "~> 6.0 or ~> 5.0"},
  ]
end
```

## Basic Usage

Here is an example of how to use the library:

```elixir
schema = %{
  type: :object,
  properties: %{
    name: %{type: :string}
  },
  required: [:name]
}

root = JSV.build!(schema)

case JSV.validate(%{"name" => "Alice"}, root) do
  {:ok, data} ->
    {:ok, data}

  # Errors can be converted into JSON-compatible structures for API responses
  # or logging.
  {:error, validation_error} ->
    {:error, JSON.encode!(JSV.normalize_error(validation_error))}
end
```

JSV offers many additional features! Check the documentation for more details.

## Development

### Contributing

Pull requests are welcome, provided they include appropriate tests and documentation.

### Roadmap

- Clean builder API so builder is always the first argument.
- Support for custom vocabularies.
- Generic module based schema instead of `defschema_for` to cast with a custom
  function or an Ecto changeset.
