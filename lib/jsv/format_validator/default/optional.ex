defmodule JSV.FormatValidator.Default.Optional do
  @moduledoc false

  @doc false
  @spec optional_support(binary, boolean) :: [binary]
  def optional_support(format, supported?) when is_boolean(supported?) do
    if supported? do
      List.wrap(format)
    else
      []
    end
  end

  @doc false
  @spec mod_exists?(module) :: boolean
  def mod_exists?(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} -> true
      {:error, _} -> false
    end
  end
end
