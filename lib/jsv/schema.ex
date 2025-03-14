defmodule JSV.Schema do
  alias JSV.Helpers.Traverse
  alias JSV.Resolver.Internal

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

  @all_keys [
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
    :writeOnly,

    # Internal keys
    :"jsv-struct"
  ]

  @derive {Inspect, optional: @all_keys}
  defstruct @all_keys

  @type t :: %__MODULE__{}
  @type schema_data :: %{optional(binary) => schema_data} | [schema_data] | number | binary | boolean | nil
  @type prototype :: t | map | [{atom | binary, term}]
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
  @spec override(base, prototype) :: t
  def override(nil, overrides) do
    new(overrides)
  end

  def override(base, overrides) do
    struct!(new(base), overrides)
  end

  @doc "Returns a schema with `type: :boolean`."
  @spec boolean(base) :: t
  def boolean(base \\ nil) do
    override(base, type: :boolean)
  end

  @doc "Returns a schema with `type: :string`."
  @spec string(base) :: t
  def string(base \\ nil) do
    override(base, type: :string)
  end

  @doc "Returns a schema with `type: :integer`."
  @spec integer(base) :: t
  def integer(base \\ nil) do
    override(base, type: :integer)
  end

  @doc "Returns a schema with `type: :number`."
  @spec number(base) :: t
  def number(base \\ nil) do
    override(base, type: :number)
  end

  @doc """
  Returns a schema with `type: :object`.

  See `props/2` to define the properties as well.
  """
  @spec object(base) :: t
  def object(base \\ nil) do
    override(base, type: :object)
  end

  @doc "Returns a schema with `type: :array` and `items: item_schema`."
  @spec items(base, map | boolean) :: t
  def items(base \\ nil, item_schema) do
    override(base, type: :array, items: item_schema)
  end

  @doc ~S(Returns a schema with `"$ref": ref`.)
  @spec ref(base, String.t()) :: t
  def ref(base \\ nil, ref) do
    override(base, "$ref": ref)
  end

  @doc """
  Returns a schema with the `type: :object` and the given `properties`.
  """
  @spec props(base, map | [{atom | binary, term}]) :: t
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

  @doc """
  Returns the given term with all atoms converted to binaries except for special
  cases.

  Note that this function accepts any data and not actually a `%JSV.Schema{}` or
  a raw schema.

  * `JSV.Schema` structs pairs where the value is `nil` will be completely
    removed. `%JSV.Schema{type: :object}` becomes `%{"type" => "object"}`
    whereas the struct contains many more keys.
  * Structs will be simply converted to map with `Map.from_struct/1`, not JSON
    encoder protocol will be used.
  * `true`, `false` and `nil` will be kept as-is in all places except map keys.
  * `true`, `false` and `nil` as map keys will be converted to string.
  * Other atoms will be checked to see if they correspond to a module name that
    exports a `schema/0` function.

  In any case, the resulting function will alway contain no atom other than
  `true`, `false` or `nil`.

  ### Examples

      iex> JSV.Schema.normalize(%JSV.Schema{title: :"My Schema"})
      %{"title" => "My Schema"}

      iex> JSV.Schema.normalize(%{name: :joe})
      %{"name" => "joe"}

      iex> JSV.Schema.normalize(%{"name" => :joe})
      %{"name" => "joe"}

      iex> JSV.Schema.normalize(%{"name" => "joe"})
      %{"name" => "joe"}

      iex> JSV.Schema.normalize(%{true: false})
      %{"true" => false}

      iex> JSV.Schema.normalize(%{specials: [true, false, nil]})
      %{"specials" => [true, false, nil]}

      iex> map_size(JSV.Schema.normalize(%JSV.Schema{}))
      0

      iex> JSV.Schema.normalize(1..10)
      %{"first" => 1, "last" => 10, "step" => 1}

      iex> defmodule :some_module_with_schema do
      iex>   def schema, do: %{}
      iex> end
      iex> JSV.Schema.normalize(:some_module_with_schema)
      %{"$ref" => "jsv:module:some_module_with_schema"}

      iex> defmodule :some_module_without_schema do
      iex>   def hello, do: "world"
      iex> end
      iex> JSV.Schema.normalize(:some_module_without_schema)
      "some_module_without_schema"
  """
  @spec normalize(term) :: %{optional(binary) => schema_data} | [schema_data] | number | binary | boolean | nil
  def normalize(term) do
    Traverse.postwalk(term, fn
      {:val, v} when is_binary(v) when is_list(v) when is_map(v) when is_number(v) ->
        v

      {:val, v} when v in [true, false, nil] ->
        v

      {:val, v} when is_atom(v) ->
        as_string = Atom.to_string(v)

        if schema_module?(v, as_string) do
          %{"$ref" => Internal.module_to_uri(v)}
        else
          as_string
        end

      {:val, other} ->
        raise ArgumentError, "invalid value in schema: #{inspect(other)}"

      {:key, k} when is_binary(k) ->
        k

      {:key, k} when is_atom(k) ->
        Atom.to_string(k)

      {:key, other} ->
        raise ArgumentError, "invalid key in schema: #{inspect(other)}"

      {:pair, pair} ->
        pair

      {:struct, %__MODULE__{} = schema, cont} ->
        raw_map_no_nils =
          schema
          |> Map.from_struct()
          |> Map.filter(fn {_, v} -> v != nil end)

        {normal_map, nil} = cont.(raw_map_no_nils, nil)
        normal_map

      {:struct, other, cont} ->
        {map, nil} = cont.(Map.from_struct(other), nil)
        map
    end)
  end

  # IO.warn("if the module to string is 'Elixir.... do not check if loaded, assume its always a ref")

  # def deatomize(term) when is_atom(term) do
  #   as_string = Atom.to_string(term)

  #   case schema_module?(term) do
  #     true -> %{"$ref" => "jsv:module:#{as_string}"}
  #     false -> as_string
  #   end
  # end

  # Returns whether the given atom is a module exporting a schema EXCEPT that if
  # the module-as-string name starts with "Elixir." we assume that it should be
  # a schema module.
  defp schema_module?(_, "Elixir." <> _) do
    true
  end

  defp schema_module?(module, _as_string) do
    case Code.ensure_loaded(module) do
      {:module, ^module} -> function_exported?(module, :schema, 0)
      _ -> false
    end
  end
end
