# Decimal Support

JSV supports validation of Decimal values from the [Decimal](https://hex.pm/packages/decimal) library.

Data with decimal values can be obtained at the JSON parsing level, which is not
handled by JSV. For instance with `Jason.decode!(json, floats: :decimals)`.

Decimal values in schemas are not supported.



## Supported Validations

The following validations work when the data is a `Decimal` struct:

- `type`: supports both `:number` and `:integer` types
  - `:number` accepts any `Decimal` struct.
  - `:integer` accepts only integer `Decimal` struct and converts them to Elixir
    integers.
- `maximum`: validates that a Decimal value is less than or equal to the maximum.
- `exclusiveMaximum`: validates that a Decimal value is strictly less than the
  maximum.
- `minimum`: validates that a Decimal value is greater than or equal to the
  minimum.
- `exclusiveMinimum`: validates that a Decimal value is strictly greater than
  the minimum.
- `multipleOf`: validates that a Decimal value is a multiple of the given
  number.


## Examples

When validating integers, decimal values are replaced with integers.

<!-- rdmx :section name:example_integer -->
```elixir
schema = %{
  type: :array,
  items: %{type: :integer}
}

root = JSV.build!(schema)

# 4.00001 is not an integer
{:error, _} = JSV.validate([3, Decimal.new("4.00001")], root)
JSV.validate([1, Decimal.new("2.0")], root)
```
<!-- rdmx /:section -->
<!-- rdmx :eval section:example_integer -->
```elixir
{:ok, [1, 2]}
```
<!-- rdmx /:eval -->

When validating numbers, decimal values with zero decimal part are preserved.
<!-- rdmx :section name:example_number -->
```elixir
schema = %{
  type: :array,
  items: %{type: :number}
}

root = JSV.build!(schema)

data =
  Jason.decode!(
    """
    [1, 2.0, 3, 4.00001]
    """,
    floats: :decimals
  )

JSV.validate(data, root)
```
<!-- rdmx /:section -->
<!-- rdmx :eval section:example_number -->
```elixir
{:ok, [1, Decimal.new("2.0"), 3, Decimal.new("4.00001")]}
```
<!-- rdmx /:eval -->


## Limitations

The following validations do not support nested Decimal values:

- `uniqueItems`: arrays containing Decimal values.
- `const`: when the constant value contains Decimal values.
- `enum`: when the enum values contain Decimal values.

This is because while we could make a simple check for values that are just a
decimal struct, those keywords can validate arbitrarily nested data.

For instance, in the following list we have identical decimal elements:

```elixir
[
  %{"vs" => [1, 2, Decimal.new("3.0")], "name" => "Alice"},
  %{"vs" => [1, 2, Decimal.new("3.0")], "name" => "Alice"}
]
```

To make sure that `uniqueItems` will validate that, we would need to traverse
both structures in parallel to compare every map key while including a special
case for Decimal.

This would impact performance for large lists because each item must be compared
to each other. For now, JSV is using the optimized structural comparison
provided by matching on previous list values when traversing the list.

The same rationale applies to `enum` and `const`. While we could easily ensure that a decimal belongs to an enum of floats, it's will be way slower if the `enum` or `const` are matching on nested data.

For instance with the following schema and data

```elixir
# Schema
%{
  "enum" => [
    %{"scale" => %{"from" => [0.0, 1.0],   "to" => [0.0, 100.0]}},
    %{"scale" => %{"from" => [0.0, 100.0], "to" => [0.0, 1.0]}}
  ]
}

# Data
%{
  "scale" => %{
    "from" => [Decimal.new("0.0"), Decimal.new("1.0")],
    "to"   => [Decimal.new("0.0"), Decimal.new("100.0")]
  }
}
```

While the data could be considered valid, it requires a more complex algorithm,
while relying on simply matching the data with enum values is very efficient.

We believe that this is out of JSV's scope, as enums and consts are most often
used with strings or atoms representing states, roles, categories, tags, _etc._

Custom vocabularies can be added to implement deep matching with support for
decimal comparisons.