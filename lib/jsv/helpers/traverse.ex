defmodule JSV.Helpers.Traverse do
  @moduledoc """
  Helper module to read and write to generic Elixir data structures.
  """

  @type traverse_struct_cont :: (map, term -> {map, term})
  @type traverse_callback_elem :: {:key | term} | {:val, term} | {:struct, struct, traverse_struct_cont}

  @doc """
  Updates a data structure in depth-first, post-order traversal.

  Operates like `postwak/3` but without an accumulator. Handling continuations
  for structs require to handle the accumulator, whose value MUST be `nil`.
  """
  @spec postwalk(data, (traverse_callback_elem() -> data)) :: data
        when data: term
  def postwalk(data, fun) when is_function(fun, 1) do
    {value, _} = postwalk(data, nil, fn value, nil -> {fun.(value), nil} end)
    value
  end

  @doc """
  Updates a JSON-compatible data structure in depth-first, post-order traversal
  while carrying an accumulator.

  The callback must return a `{new_value, new_acc}` tuple.

  Nested data structures are given to the callback before their wrappers, and
  when the wrappers are called, their children are already updated.

  JSON-compatible only means that there are restrictions on map keys and struct
  values:

  * The callback function will be called for any key but will not traverse the
    keys. For instance, with data such as `%{{x, y} => "some city"}`, the tuple
    used as key will given called as-is but the callback will not be called for
    individual tuple elements.
  * Structs will be passed as `{:struct, value, continuation}`. The truct keys
    and values will **NOT** have been traversed yet. To operate on the struct
    keys you MUST call it manually. To respect the post-order of traversal, it
    SHOULD be called before further transformation of the struct:

        Traverse.postwalk(%MyStruct, [], fn
          {:struct, my_struct, cont}, acc ->
            {map, acc} = cont.(Map.from_struct(my_struct), acc)
            {struct!(MyStruct, do_something_with_map(map)), acc}
          {:val, ...} -> ...
        end)

    The continuation only accepts raw maps.

  * General data is accepted: tuples, pid, refs, etc. *
  """
  @spec postwalk(data, acc, (traverse_callback_elem, acc -> {data, acc})) :: {data, acc}
        when data: term, acc: term
  def postwalk(data, accin, fun) when is_function(fun, 2) do
    postwalk_val(data, accin, fun)
  end

  defp postwalk_val(struct, acc, fun) when is_struct(struct) do
    cont = fn
      map, acc when is_map(map) and not is_struct(map) ->
        postwalk_map_pairs(map, acc, fun)

      other, _ ->
        raise ArgumentError, "continuation function only accepts raw maps, got: #{inspect(other)}"
    end

    {_value, _acc} = fun.({:struct, struct, cont}, acc)
  end

  defp postwalk_val(map, acc, fun) when is_map(map) do
    {map, acc} = postwalk_map_pairs(map, acc, fun)
    {_map, _acc} = fun.({:val, map}, acc)
  end

  defp postwalk_val(list, acc, fun) when is_list(list) do
    {list, acc} = Enum.map_reduce(list, acc, fn item, acc -> {_v, _acc} = postwalk_val(item, acc, fun) end)
    {_list, _acc} = fun.({:val, list}, acc)
  end

  defp postwalk_val(tuple, acc, fun) when is_tuple(tuple) do
    {elems, acc} =
      tuple
      |> Tuple.to_list()
      |> Enum.map_reduce(acc, fn item, acc -> {_v, _acc} = postwalk_val(item, acc, fun) end)

    tuple = List.to_tuple(elems)
    {_tuple, _acc} = fun.({:val, tuple}, acc)
  end

  defp postwalk_val(val, acc, fun) do
    {_val, _acc} = fun.({:val, val}, acc)
  end

  # Keys are not traversed
  defp postwalk_key(k, acc, fun) do
    {_k, _acc} = fun.({:key, k}, acc)
  end

  defp postwalk_map_pairs(map, acc, fun) do
    {pairs, acc} =
      Enum.map_reduce(map, acc, fn {k, v}, acc ->
        {v, acc} = postwalk_val(v, acc, fun)
        {k, acc} = postwalk_key(k, acc, fun)
        {{k, v}, acc}
      end)

    {Map.new(pairs), acc}
  end
end
