defmodule JSV.Schema do
  defstruct [
    # TODO document const not supported because it can legally contain `nil` and
    # would be removed when reducing the schema to binary form.
    #
    # :const,

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

  def override(nil, overrides) do
    new(overrides)
  end

  def override(base, overrides) do
    struct!(new(base), overrides)
  end
end
