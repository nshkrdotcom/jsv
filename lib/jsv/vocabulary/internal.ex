defmodule JSV.Vocabulary.Internal do
  alias JSV.Helpers.StringExt
  alias JSV.Validator
  use JSV.Vocabulary, priority: 900

  @moduledoc false

  @impl true
  def init_validators([]) do
    %{}
  end

  take_keyword :"jsv-struct", module_str, vds, builder, _ do
    case find_module(module_str) do
      {:ok, module} -> {:ok, Map.put(vds, :"jsv-struct", module), builder}
    end
  end

  ignore_any_keyword()

  @spec find_module(binary) :: {:ok, module} | {:error, term}
  def find_module(module_str) do
    case StringExt.safe_string_to_existing_module(module_str) do
      {:ok, module} -> check_is_struct(module)
      {:error, _} = err -> err
    end
  end

  defp check_is_struct(module) do
    with {:module, ^module} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :__struct__, 0) do
      {:ok, module}
    else
      _ -> {:error, {:unknown_struct, module}}
    end
  end

  @impl true
  def finalize_validators(map) do
    case map_size(map) do
      0 -> :ignore
      _ -> map
    end
  end

  @impl true
  def validate(data, %{"jsv-struct": module}, vctx) do
    cond do
      Validator.error?(vctx) ->
        {:ok, data, vctx}

      vctx.opts[:cast_structs] ->
        keycast = module.__jsv__(:keycast)
        props = take_struct_keys(data, keycast)
        {:ok, struct!(module, props), vctx}

      :other ->
        {:ok, data, vctx}
    end
  end

  defp take_struct_keys(data, keycast) do
    Enum.reduce(keycast, [], fn {str_key, atom_key}, acc ->
      case data do
        %{^str_key => v} -> [{atom_key, v} | acc]
        _ -> acc
      end
    end)
  end
end
