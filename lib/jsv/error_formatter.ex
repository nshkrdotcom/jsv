defmodule JSV.ErrorFormatter do
  alias JSV.Key
  alias JSV.Ref
  alias JSV.ValidationError
  alias JSV.Validator
  alias JSV.Validator.Error

  @moduledoc """
  Error formatting loosely following the guidelines described at
  https://json-schema.org/blog/posts/fixing-json-schema-output

  Errors are grouped by similar instance location (the bit of data that was
  invalidated) and schema location (the part of the schema that invalidated it).
  """

  def normalize_error(%ValidationError{} = e, opts \\ []) do
    %{valid: false, details: normalize_errors(e.errors, opts)}
  end

  defp normalize_errors(errors, opts) do
    errors
    |> Enum.group_by(fn
      %Error{data_path: dp, eval_path: ep} -> {dp, ep}
      %{valid: _, instanceLocation: _, evaluationPath: _, schemaLocation: _} = unit -> unit
    end)
    |> Enum.map(fn
      {{data_path, eval_path}, errors} -> build_unit(data_path, eval_path, errors, opts)
      {unit, [unit]} -> unit
    end)
    |> Enum.sort_by(& &1.schemaLocation)
  end

  defp build_unit(data_path, rev_eval_path, errors, opts) do
    {absolute_location, keyword_location} = format_keyword_paths(rev_eval_path)

    errors_fmt = Enum.map(errors, &build_error(&1, opts))

    %{
      valid: false,
      errors: errors_fmt,
      instanceLocation: format_data_path(data_path),
      evaluationPath: keyword_location,
      schemaLocation: absolute_location
    }
  end

  def format_data_path([]) do
    ""
  end

  def format_data_path(rev_data_path) do
    "/" <>
      (rev_data_path
       |> :lists.reverse()
       |> Enum.map_join("/", fn
         index when is_integer(index) -> Integer.to_string(index)
         key -> Ref.escape_json_pointer(key)
       end))
  end

  defp format_keyword_paths([]) do
    {"", ""}
  end

  defp format_keyword_paths(eval_path) do
    flat_path = flatten_path(eval_path)

    absolute_path =
      flat_path
      |> take_last_abs_path_segments([])
      |> format_path()

    schema_path = flat_path_to_schema_path(flat_path)

    {absolute_path, schema_path}
  end

  @doc false
  def format_schema_path(eval_path) do
    flat_path = flatten_path(eval_path)

    flat_path_to_schema_path(flat_path)
  end

  defp flat_path_to_schema_path(flat_path) do
    flat_path
    |> take_eval_path_segments([])
    |> format_path()
  end

  # eval path is built in reverse while iterating the schemas by consing to the
  # list. But for convenience, adding multiple items to the list is done by
  # keeping them ordered. For instance, we are consing ["properties","foo"] and
  # not ["foo","properties"].
  #
  # Here we need to flatten the list on only one level while reversing the
  # sublists. The overall list is _not_ reversed.
  defp flatten_path(list) do
    case list do
      [h | t] when is_list(h) -> :lists.reverse(h, flatten_path(t))
      [h | t] -> [h | flatten_path(t)]
      [] -> []
    end
  end

  defp take_last_abs_path_segments(list, acc) do
    case list do
      [h | t] when is_integer(h) when is_atom(h) when is_binary(h) -> take_last_abs_path_segments(t, [h | acc])
      # stop at the first scope changing element
      [{:ref, _, _} = ref | _] -> [{:abs, ref} | acc]
      [{:alias_of, ns} | _] -> [{:abs, ns} | acc]
      [] -> acc
    end
  end

  defp take_eval_path_segments(list, acc) do
    case list do
      [h | t] when is_integer(h) when is_atom(h) when is_binary(h) -> take_eval_path_segments(t, [h | acc])
      # # stop at the first scope changing element
      [{:ref, keyword, _} | t] -> take_eval_path_segments(t, [keyword | acc])
      [{:alias_of, _} | t] -> take_eval_path_segments(t, acc)
      [] -> acc
    end
  end

  defp format_path(items) do
    items
    |> Enum.map(fn
      {:abs, _} = item -> format_path_segment(item)
      item -> ["/", format_path_segment(item)]
    end)
    |> IO.iodata_to_binary()
  end

  defp format_path_segment(item) do
    case item do
      atom when is_atom(atom) -> Atom.to_string(atom)
      key when is_binary(key) -> Ref.escape_json_pointer(key)
      index when is_integer(index) -> Integer.to_string(index)
      {:abs, path_origin} -> format_origin(path_origin)
      other -> raise "invalid eval path segment: #{inspect(other)}"
    end
  end

  defp format_origin(binary) when is_binary(binary) do
    binary
  end

  defp format_origin({:ref, _, ref}) do
    Key.to_iodata(ref)
  end

  defp build_error(error, opts) do
    %Error{kind: kind, data: data, formatter: formatter, args: args} =
      error

    formatter = formatter || Error
    args_map = Map.new(args)

    case formatter.format_error(kind, args_map, data) do
      message when is_binary(message) ->
        %{message: message, kind: kind}

      {message, sub_errors} when is_binary(message) ->
        # TODO should not be needed and validated by callback specs.
        :ok = ensure_sub_errors(sub_errors, formatter, kind)
        %{message: message, kind: kind, details: normalize_errors(sub_errors, opts)}

      {new_kind, message, sub_errors} when is_binary(message) ->
        # TODO should not be needed and validated by callback specs.
        :ok = ensure_sub_errors(sub_errors, formatter, kind)
        %{message: message, kind: new_kind, details: normalize_errors(sub_errors, opts)}
    end
  end

  defp ensure_sub_errors(sub_errors, formatter, kind) do
    with true <- is_list(sub_errors),
         true <- Enum.all?(sub_errors, &sub_error_or_unit?/1) do
      :ok
    else
      _ ->
        # TODO remove this check when everything is cood, replace by an assertive match
        raise "invalid sub errors for kind #{inspect(kind)}, expected a list of " <>
                "errors or output units from #{inspect(formatter)} , got: #{inspect(sub_errors)}"
    end
  end

  defp sub_error_or_unit?(%Error{}) do
    true
  end

  defp sub_error_or_unit?(%{valid: v, instanceLocation: _, evaluationPath: _, schemaLocation: _}) when is_boolean(v) do
    true
  end

  defp sub_error_or_unit?(_) do
    false
  end

  @doc """
  Returns an output unit with `valid: true` for the given
  `#{inspect(Validator)}`. This can be substitued to an Error struct in the
  nested details of an error. Mostly used to show multiple validated schemas
  with `:oneOf`.
  """
  def valid_unit(vctx) do
    {absolute_location, keyword_location} = format_keyword_paths(vctx.eval_path)

    %{
      valid: true,
      instanceLocation: format_data_path(vctx.data_path),
      evaluationPath: keyword_location,
      schemaLocation: absolute_location
    }
  end
end
