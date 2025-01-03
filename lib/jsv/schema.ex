# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule JSV.Schema do
  @moduledoc """
  This module defines a struct where all the supported keywords of the JSON
  schema specification are defined as keys. Text editors that can predict the
  struct keys will make autocompletion available when writing schemas.

  ### Using in build

  The `#{inspect(__MODULE__)}` struct can be given to `JSV.build/2`:

      schema = %JSV.Schema{type: :integer}
      JSV.build(schema, options())

  Because Elixir structs always contain all their defined keys, writing a schema
  as `%JSV.Schema{type: :integer}` is actually defining the following:

      %JSV.Schema{
        type: :integer,
        "$id": nil
        additionalItems: nil,
        additionalProperties: nil,
        allOf: nil,
        anyOf: nil,
        contains: nil,
        # etc...
      }

  For that reason, when giving a `#{inspect(__MODULE__)}` struct to
  `JSV.build/2`, any `nil` value is ignored. This is not the case with other
  strucs or maps.

  Note that `JSV.build/2` does not require `#{inspect(__MODULE__)}` structs, any
  map with binary or atom keys is accepted.

  This is also why the `#{inspect(__MODULE__)}` struct does not define the
  `const` keyword, because `nil` is a valid value for that keyword but there is
  no way to know if the value was omitted or explicitly defined as `nil`. To
  circumvent that you may use the `enum` keyword or just use a regular map
  instead of this module's struct:

      %#{inspect(__MODULE__)}{enum: [nil]}
      # OR
      %{const: nil}

  ### Functional helpers

  This module also exports a small range of utility functions to ease writing
  schemas in a functional way.

  This is mostly useful when generating schemas dynamically, or for shorthands.

  For instance, instead of writing the following:

      %Schema{
        type: :object,
        properties: %{
          name: %Schema{type: :string, description: "the name of the user"},
          age: %Schema{type: :integer, description: "the age of the user"}
        },
        required: [:name, :age]
      }

  One can write:

      %Schema{}
      |> Schema.props(
        name: Schema.string(description: "the name of the user"),
        age: Schema.integer(description: "the age of the user")
      )
      |> Schema.required([:name, :age])
  """

  defstruct [
    :"$anchor",
    :"$comment",
    :"$defs",
    :"$dynamicAnchor",
    :"$dynamicRef",
    :"$id",
    :"$ref",
    :"$schema",
    :additionalItems,
    :additionalProperties,
    :allOf,
    :anyOf,
    :contains,
    :contentEncoding,
    :contentMediaType,
    :contentSchema,
    :default,
    :dependencies,
    :dependentRequired,
    :dependentSchemas,
    :deprecated,
    :description,
    :else,
    :enum,
    :examples,
    :exclusiveMaximum,
    :exclusiveMinimum,
    :format,
    :if,
    :items,
    :maxContains,
    :maximum,
    :maxItems,
    :maxLength,
    :maxProperties,
    :minContains,
    :minimum,
    :minItems,
    :minLength,
    :minProperties,
    :multipleOf,
    :not,
    :oneOf,
    :pattern,
    :patternProperties,
    :prefixItems,
    :properties,
    :propertyNames,
    :readOnly,
    :required,
    :then,
    :title,
    :type,
    :unevaluatedItems,
    :unevaluatedProperties,
    :uniqueItems,
    :writeOnly
  ]

  @type t :: %__MODULE__{}
  @type prototype :: t | map | keyword
  @type base :: prototype | nil

  @doc """
  Returns a new `#{inspect(__MODULE__)}` struct with the given key/values.
  """
  @spec new(prototype) :: t
  def new(%__MODULE__{} = schema) do
    schema
  end

  def new(key_values) do
    struct!(__MODULE__, key_values)
  end

  @doc """
  Updates the given `#{inspect(__MODULE__)}` struct with the given key/values.

  Accepts `nil` as the base schema, which is equivalent to `new(overrides)`.
  """
  @spec override(prototype | nil, prototype) :: t
  def override(nil, overrides) do
    new(overrides)
  end

  def override(base, overrides) do
    struct!(new(base), overrides)
  end

  @doc "Returns a schema with `type: :boolean`."
  def boolean(base \\ nil) do
    override(base, type: :boolean)
  end

  @doc "Returns a schema with `type: :string`."
  def string(base \\ nil) do
    override(base, type: :string)
  end

  @doc "Returns a schema with `type: :integer`."
  def integer(base \\ nil) do
    override(base, type: :integer)
  end

  @doc "Returns a schema with `type: :number`."
  def number(base \\ nil) do
    override(base, type: :number)
  end

  @doc """
  Returns a schema with `type: :object`.

  See `props/2` to define the properties as well.
  """
  def object(base \\ nil) do
    override(base, type: :object)
  end

  @doc "Returns a schema with `type: :array` and `items: item_schema`."
  def items(base \\ nil, item_schema) do
    override(base, type: :array, items: item_schema)
  end

  @doc ~S(Returns a schema with `"$ref": ref`.)
  def ref(base \\ nil, ref) do
    override(base, "$ref": ref)
  end

  @doc """
  Returns a schema with the `type: :object` and the given `properties`.
  """
  def props(base \\ nil, properties) do
    override(base, type: :object, properties: Map.new(properties))
  end

  @doc """
  Adds the given key or keys in the base schema `:required` property. Previous
  values are preserved.
  """
  @spec required(base, [atom | binary] | atom | binary) :: t
  def required(base \\ nil, key_or_keys)

  def required(nil, key_or_keys) do
    new(required: List.wrap(key_or_keys))
  end

  def required(base, keys) when is_list(keys) do
    case new(base) do
      %__MODULE__{required: nil} -> %__MODULE__{base | required: keys}
      %__MODULE__{required: list} -> %__MODULE__{base | required: keys ++ list}
    end
  end

  def required(base, key) when is_binary(key) when is_atom(key) do
    case new(base) do
      %__MODULE__{required: nil} -> %__MODULE__{base | required: [key]}
      %__MODULE__{required: list} -> %__MODULE__{base | required: [key | list]}
    end
  end
end
