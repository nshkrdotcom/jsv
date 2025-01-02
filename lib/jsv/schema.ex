# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule JSV.Schema do
  @moduledoc """
  A helper struct to write schemas with autocompletion with text editors that
  can predict the struct keys.

  Such schemas can be given to `JSV.build/2`:

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

  @spec new(prototype) :: t
  def new(%__MODULE__{} = schema) do
    schema
  end

  def new(key_values) do
    struct!(__MODULE__, key_values)
  end

  def boolean(base \\ nil) do
    override(base, type: :boolean)
  end

  def string(base \\ nil) do
    override(base, type: :string)
  end

  def integer(base \\ nil) do
    override(base, type: :integer)
  end

  def number(base \\ nil) do
    override(base, type: :number)
  end

  def object(base \\ nil) do
    override(base, type: :object)
  end

  def items(base \\ nil, item_schema) do
    override(base, type: :array, items: item_schema)
  end

  def ref(base \\ nil, ref) do
    override(base, "$ref": ref)
  end

  @spec override(prototype | nil, prototype) :: t
  def override(nil, overrides) do
    new(overrides)
  end

  def override(base, overrides) do
    struct!(new(base), overrides)
  end
end
