defmodule JSV.AtomTools do
  @moduledoc false
  alias JSV.Schema

  @type raw_data :: %{optional(binary) => raw_data()} | [raw_data] | number | binary | boolean | nil
  @type atom_data :: raw_data | %{optional(binary | atom) => atom_data()} | [atom_data] | number | atom

  @doc """
  Returns the given term with all atoms converted to binaries except for special
  cases.

  The term is checked for atom presence before conversion. When it is certain
  that the term contains atoms, the `deatomize/1` function can be used instead
  to skip that check.

  * `JSV.Schema` structs pairs where the value is `nil` will be completely
    removed. `%JSV.Schema{type: :object}` becomes `%{"type" => "object"}`
    whereas the struct contains many more keys.
  * Other structs will have the `:__struct__` field removed, and others pairs
    will be converted as any other map with atom keys.
  * `true`, `false` and `nil` will be kept as-is in all places except map keys.
  * `true`, `false` and `nil` as map keys will be converted to string.
  * Other atoms will be checked to see if they correspond to a module name that
    exports a `schema/0` function.

  In any case, the resulting function will alway contain no atom other than
  `true`, `false` or `nil`.

  ### Examples

      iex> normalize_schema(%{name: :joe})
      %{"name" => "joe"}

      iex> normalize_schema(%{true: false})
      %{"true" => false}

      iex> normalize_schema(%{specials: [true, false, nil]})
      %{"specials" => [true, false, nil]}

      iex> map_size(normalize_schema(%JSV.Schema{}))
      0

      iex> normalize_schema(1..10)
      %{"first" => 1, "last" => 10, "step" => 1}

      iex> defmodule :some_module_with_schema do
      iex>   def schema, do: %{}
      iex> end
      iex> normalize_schema(:some_module_with_schema)
      %{"$ref" => "jsv:module:some_module_with_schema"}

      iex> defmodule :some_module_without_schema do
      iex>   def hello, do: "world"
      iex> end
      iex> normalize_schema(:some_module_without_schema)
      "some_module_without_schema"
  """
  @spec normalize_schema(atom_data) :: raw_data
  def normalize_schema(term) do
    # Checking before is faster (benchmark in ./tools)

    if atom_props?(term) do
      deatomize(term)
    else
      term
    end
  end

  @doc """
  Converts most atoms to binaries in the given term. See `normalize_schema/1`
  for special cases.
  """
  @spec deatomize(atom_data) :: raw_data
  def deatomize(term)

  def deatomize(term) when term == nil when term == true when term == false do
    term
  end

  def deatomize(term) when is_atom(term) do
    as_string = Atom.to_string(term)

    case schema_module?(term) do
      true -> %{"$ref" => "jsv:module:#{as_string}"}
      false -> as_string
    end
  end

  def deatomize(term) when is_binary(term) when is_number(term) do
    term
  end

  def deatomize(%Schema{} = term) do
    deatom_schema_struct(term)
  end

  def deatomize(term) when is_struct(term) do
    deatomize(Map.from_struct(term))
  end

  def deatomize(term) when is_map(term) do
    Map.new(term, fn {k, v} -> {deatom_key(k), deatomize(v)} end)
  end

  def deatomize([h | t]) do
    [deatomize(h) | deatomize(t)]
  end

  def deatomize([]) do
    []
  end

  defp deatom_key(term) when term == nil when term == true when term == false do
    Atom.to_string(term)
  end

  defp deatom_key(term) do
    deatomize(term)
  end

  defp deatom_schema_struct(schema) do
    schema
    |> Map.from_struct()
    |> Enum.flat_map(fn
      {_, nil} -> []
      {:__struct__, _} -> []
      {k, v} -> [{deatom_key(k), deatomize(v)}]
    end)
    |> Map.new()
  end

  defp schema_module?(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} -> function_exported?(module, :schema, 0)
      _ -> false
    end
  end

  @doc """
  Returns true if the given value (and sub values) contains atoms. Does not
  return true for `true`, `false` and `nil` except if keys in a map.
  """
  @spec atom_props?(atom_data()) :: boolean()
  def atom_props?(term)

  def atom_props?(term) when is_map(term) do
    atom_props_iter?(:maps.iterator(term))
  end

  def atom_props?(term) when is_number(term) when is_binary(term) do
    false
  end

  # Special atoms as values does not count as an atom prop
  def atom_props?(term) when term == true when term == false when term == nil do
    false
  end

  def atom_props?(term) when is_atom(term) do
    true
  end

  def atom_props?([h | t]) do
    atom_props?(h) || atom_props?(t)
  end

  def atom_props?([]) do
    false
  end

  defp atom_props_iter?(iter) do
    case :maps.next(iter) do
      {k, v, iter} -> is_atom(k) || atom_props?(v) || atom_props_iter?(iter)
      :none -> false
    end
  end

  @spec safe_string_to_existing_atom(binary) :: {:ok, atom} | {:error, {:unknown_atom, binary}}
  def safe_string_to_existing_atom(string) do
    {:ok, String.to_existing_atom(string)}
  rescue
    _ in ArgumentError -> {:error, {:unknown_atom, string}}
  end

  @doc """
  Returns a JSV internal URI for the given module.

  ### Example

      iex> module_to_uri(Inspect.Opts)
      "jsv:module:Elixir.Inspect.Opts"
  """
  @spec module_to_uri(module) :: binary
  def module_to_uri(module) when is_atom(module) do
    "jsv:module:#{Atom.to_string(module)}"
  end
end
