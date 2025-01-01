defmodule JSV.AtomTools do
  @moduledoc false
  alias JSV.Schema

  @doc """
  Returns the given term with all atoms converted to binaries, except for
  `true`, `false` and `nil` when not used as a map key. Map keys are always
  converted.

  The term is checked for atom presence before conversion. When it is certain
  that the term contains atoms, the `deatomize/1` function can be used instead
  to skip that check.

  The function accepts struct and will simply remove the `:__struct__` field
  from any map, but there is a special case: given a `JSV.Schema` struct, the
  function will also strip all key-value pairs where the value is nil.

  ### Examples

      iex> fmap_atom_to_binary(%{name: :joe})
      %{"name" => "joe"}

      iex> fmap_atom_to_binary(%{true: false})
      %{"true" => false}

      iex> fmap_atom_to_binary(%{specials: [true, false, nil]})
      %{"specials" => [true, false, nil]}

      iex> map_size(fmap_atom_to_binary(%JSV.Schema{}))
      0

      iex> fmap_atom_to_binary(1..10)
      %{"first" => 1, "last" => 10, "step" => 1}
  """
  def fmap_atom_to_binary(term) do
    # Checking before is faster (benchmark in ./tools)
    if atom_props?(term) do
      deatomize(term)
    else
      term
    end
  end

  @doc """
  Converts atoms to binaries in the given term. See `fmap_atom_to_binary/1`.
  """
  def deatomize(term)

  def deatomize(term) when term == nil when term == true when term == false do
    term
  end

  def deatomize(term) when is_atom(term) do
    Atom.to_string(term)
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

  def deatom_schema_struct(schema) do
    schema
    |> Map.from_struct()
    |> Enum.flat_map(fn
      {_, nil} -> []
      {:__struct__, _} -> []
      {k, v} -> [{deatom_key(k), deatomize(v)}]
    end)
    |> Map.new()
  end

  @doc """
  Returns true if the given value (and sub values) contains atoms. Does not
  return true for `true`, `false` and `nil` except if keys in a map.
  """
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
end
