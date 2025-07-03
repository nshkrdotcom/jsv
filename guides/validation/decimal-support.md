# Decimal Support

JSV supports validation of Decimal values from the [Decimal](https://hex.pm/packages/decimal) library.

Data with decimal values can be obtained at the JSON parsing level, which is not
handled by JSV. For instance with `Jason.decode!(json, floats: :decimals)`.

Decimal values in schemas are not supported.



## Supported Validations

The following validations work when the data is a `Decimal` struct:

- `type`: supports both `:number` and `:integer` types
  - `:number` accepts any `Decimal` struct.
  - `:integer` accepts only integer `Decimal` structs and converts them to
    Elixir integers.
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

<!-- rdmx :section name:example_integer format:true -->
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
<!-- rdmx :section name:example_number format:true -->
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

JSV will not perform a deep comparison between data and a `const` or `enum`
value, or between items of an array when using `uniqueItems`, but rather just
use the `==` operator for speed.

We believe that handling those cases is out of JSV's scope, as enums and consts
are most often used with strings or atoms representing states, roles,
categories, tags, _etc._

Custom vocabularies can be added to implement deep matching with support for
decimal comparisons.