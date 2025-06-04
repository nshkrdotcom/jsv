defmodule JSV.Schema.Defcompose do
  @moduledoc false

  defguard is_literal(v) when is_atom(v) or is_integer(v) or (is_tuple(v) and is_list(elem(v, 2)))

  defp extract_guard(args_or_guarded) do
    case args_or_guarded do
      {:when, _meta, [args, guard]} -> {guard, args}
      args -> {true, args}
    end
  end

  defp expand_args(args, env) do
    Enum.map(args, fn {prop, value} ->
      value = Macro.expand(value, env)

      if Macro.quoted_literal?(value) do
        {:const, prop, value}
      else
        expand_expression(prop, value)
      end
    end)
  end

  defp expand_expression(prop, value) do
    case value do
      {:<-, _, [expr, value]} ->
        {bind, typespec} = extract_typespec(value)
        {:var, prop, bind, typespec, expr}

      {{:., _, _}, _, _} = remote_call ->
        {:call, prop, remote_call}

      value ->
        {bind, typespec} = extract_typespec(value)
        {:var, prop, bind, typespec, bind}
    end
  end

  defp extract_typespec(value) do
    case value do
      {:"::", _, [bind, typespec]} -> {bind, typespec}
      bind -> {bind, {:term, [], nil}}
    end
  end

  defmacro defcompose(fun, args_or_guarded) do
    {guard, args} = extract_guard(args_or_guarded)

    args = expand_args(args, __CALLER__)

    schema_props =
      Enum.map(args, fn
        {:const, prop, const} -> {prop, const}
        {:var, prop, _bind, _typespec, expr} -> {prop, expr}
        {:call, prop, call} -> {prop, call}
      end)

    bindings =
      Enum.flat_map(args, fn
        {:const, _prop, _const} -> []
        {:var, _prop, bind, _typespec, _expr} -> [bind]
        {:call, _, _} -> []
      end)

    typespecs =
      Enum.flat_map(args, fn
        {:const, _prop, _const} -> []
        {:var, _prop, _bind, typespec, _expr} -> [typespec]
        {:call, _, _} -> []
      end)

    # Start of quote

    quote location: :keep do
      doc_custom =
        case Module.get_attribute(__MODULE__, :doc) do
          {_, text} when is_binary(text) -> ["\n\n", text]
          _ -> ""
        end

      doc_schema_props =
        unquote(
          Enum.map(args, fn
            {:const, prop, const} -> {prop, const}
            {:var, prop, bind, _typespec, _expr} -> {:var, {prop, Macro.to_string(bind)}}
            {:call, prop, call} -> {prop, call}
          end)
        )
        |> Enum.map(fn
          {:var, {prop, varname}} -> "`#{prop}: #{varname}`"
          {prop, value} -> "`#{prop}: #{inspect(value)}`"
        end)
        |> :lists.reverse()
        |> case do
          [last | [_ | _] = prev] ->
            prev
            |> Enum.intersperse(", ")
            |> :lists.reverse([" and ", last])

          [single] ->
            [single]
        end

      @doc """
      Defines or [merges](JSV.Schema.html#/2) into a JSON Schema with
      #{doc_schema_props}.#{doc_custom}.
      """
      @doc section: :schema_utilities
      @spec unquote(fun)(base, unquote_splicing(typespecs)) :: schema
      def unquote(fun)(base \\ nil, unquote_splicing(bindings)) when unquote(guard) do
        merge(base, unquote(schema_props))
      end
    end
  end
end
