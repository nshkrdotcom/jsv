defmodule JSV.Cast do
  import JSV

  @moduledoc false

  defcast string_to_integer(data) do
    with true <- is_binary(data),
         {int, ""} <- Integer.parse(data) do
      {:ok, int}
    else
      _ -> {:error, "invalid integer representation"}
    end
  end

  defcast string_to_float(data) do
    with true <- is_binary(data),
         {float, ""} <- Float.parse(data) do
      {:ok, float}
    else
      _ -> {:error, "invalid floating point number representation"}
    end
  end

  defcast string_to_existing_atom(data) do
    {:ok, String.to_existing_atom(data)}
  rescue
    ArgumentError -> {:error, "not an existing atom representation"}
  end

  defcast string_to_atom(data) do
    if is_binary(data) do
      {:ok, String.to_atom(data)}
    else
      {:error, "not an atom representation"}
    end
  end

  @doc false
  @spec format_error(term, term, term) :: binary
  def format_error(_, message, _) do
    message
  end
end
