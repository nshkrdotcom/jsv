# Defining Schemas

This guide explains the different possible values to use as a schema with JSV.


## Schema sources

Schemas given as input to JSV can come from two sources:

* Schemas given directly to the `JSV.build/2` function. These are expected to be
  maps or booleans. JSV will not parse JSON strings.
* Schemas returned by resolvers. These should also be maps (but not booleans).
  The built-in resolvers will handle JSON deserialization automatically.

JSV is designed to work with raw schemas. Any map or boolean is a valid schema.
For instance, it is possible to directly use a schema from a file:

<!-- rdmx :section name:schema_from_file format:true -->
```elixir
root =
  "my-schema.json"
  |> File.read!()
  |> JSON.decode!()
  |> JSV.build()
```
<!-- rdmx /:section -->


## Schema formats

Schemas can be either booleans or maps. The `true` value is equivalent to an
empty JSON Schema `{}`, while `false` is a schema that will invalidate any
value. It is most often used as a sub-schema for `additionalProperties`.

Maps can define keys and values as binaries or atoms. The following schemas are
equivalent:

<!-- rdmx :section name:equivalent_schemas format:true -->
```elixir
%{type: :boolean}
%{type: "boolean"}
%{"type" => "boolean"}
# You will rarely find this one in the wild!
%{"type" => :boolean}
```
<!-- rdmx /:section -->

This is because JSV will normalize the schemas before building a "root", the
base data structure for data validation.

Mixing keys is not recommended. In the following example, JSV will build a
schema that will successfully validate integers with a minimum of zero. However,
the choice for the maximum value is not made by JSV.

<!-- rdmx :section name:mixed_keys format:true -->
```elixir
%{:type => :integer, "minimum" => 0, "maximum" => 10, :maximum => 20}
```
<!-- rdmx /:section -->


## Struct schemas

Schemas can be used to define structs with the `JSV.defschema/1` macro.

For instance, with this module definition schema:

<!-- rdmx :section name:struct_schema format:true -->
```elixir
defmodule MyApp.UserSchema do
  use JSV.Schema

  defschema %{
    type: :object,
    properties: %{
      name: %{type: :string, default: ""},
      age: %{type: :integer, default: 0}
    }
  }
end
```
<!-- rdmx /:section -->

A struct will be defined with the appropriate default values:

```elixir
iex> %MyApp.UserSchema{}
%MyApp.UserSchema{name: "", age: 0}
```

The module can be used as a schema to build a validator root and cast data to
the corresponding struct:

```elixir
iex> {:ok, root} = JSV.build(MyApp.UserSchema)
iex> data = %{"name" => "Alice"}
iex> JSV.validate(data, root)
{:ok, %MyApp.UserSchema{name: "Alice", age: 0}}
```

Casting to a struct can be disabled by passing `cast: false` into the
options of `JSV.validate/3`.

```elixir
iex> {:ok, root} = JSV.build(MyApp.UserSchema)
iex> data = %{"name" => "Alice", "extra" => "hello!"}
iex> JSV.validate(data, root, cast: false)
{:ok, %{"name" => "Alice", "extra" => "hello!"}}
```

The module can also be used in other schemas:

<!-- rdmx :section name:nested_schema format:true -->
```elixir
%{
  type: :object,
  properties: %{
    name: %{type: :string},
    owner: MyApp.UserSchema
  }
}
```
<!-- rdmx /:section -->

An alternative syntax can be used, by passing only the properties schemas as a
list.

<!-- rdmx :section name:alternative_syntax format:true -->
```elixir
defmodule MyApp.UserSchema do
  use JSV.Schema

  defschema name: %{type: :string, default: ""},
            age: %{type: :integer, default: 0}
end
```
<!-- rdmx /:section -->

In that case, properties that do not have a default value are automatically
required, and the `type` of the schema is automatically set to `object`. The
`title` of the schema is set as the last segment of the module name.

Struct defining schemas are a special case of the generic cast mechanism built
in JSV. Make sure to check that guide out as well.


## Defining multiple schemas with defschema/3

The `JSV.defschema/3` macro allows you to define a new module for a schema. It
can be used inside an enclosing "group" module, which is useful for organizing
related schemas together:

<!-- rdmx :section name:multiple_schemas format:true -->
```elixir
defmodule MyApp.Schemas do
  use JSV.Schema

  defschema User,
    name: string(),
    email: string(),
    age: integer(default: 18)

  defschema Address,
            "Physical address information",
            street: string(),
            city: string(),
            country: string(default: "US")

  defschema Company,
            "Company information with nested schemas",
            name: string(),
            address: Address,
            employees: array_of(User)
end
```
<!-- rdmx /:section -->

This creates three separate modules: `MyApp.Schemas.User`,
`MyApp.Schemas.Address`, and `MyApp.Schemas.Company`, each with their own struct
and JSON schema.

You can use these schemas independently:

<!-- rdmx :section name:independent_usage format:true -->
```elixir
user = %MyApp.Schemas.User{name: "Alice", email: "alice@example.com"}
address = %MyApp.Schemas.Address{street: "123 Main St", city: "Boston"}

{:ok, user_root} = JSV.build(MyApp.Schemas.User)
{:ok, company_root} = JSV.build(MyApp.Schemas.Company)
```
<!-- rdmx /:section -->

### Using full schema maps

You can also use `defschema/3` with complete schema maps instead of property lists:

<!-- rdmx :section name:full_schema_maps format:true -->
```elixir
defmodule MyApp.Schemas do
  use JSV.Schema

  defschema ApiResponse,
            "Standard API response format",
            %{
              type: :object,
              properties: %{
                success: %{type: :boolean},
                data: %{type: :object},
                errors: %{type: :array, items: %{type: :string}}
              },
              required: [:success],
              additionalProperties: false
            }
end
```
<!-- rdmx /:section -->

When using full schema maps, the title and description from the macro parameters
are **not** automatically applied to the schema, the map is used as-is. Only the
description parameter is used for the module's documentation.

### Self-referencing schemas

Schemas can reference themselves using `__MODULE__`:

<!-- rdmx :section name:self_reference format:true -->
```elixir
defmodule MyApp.Schemas do
  use JSV.Schema

  defschema Category,
            "Hierarchical category structure",
            name: string(),
            parent: optional(__MODULE__)
end
```
<!-- rdmx /:section -->

This creates a `MyApp.Schemas.Category` module that can have a parent of the
same type, allowing for hierarchical data structures.

