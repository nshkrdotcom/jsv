defmodule JSV.Validator.Error do
  @moduledoc """
  Representation of an error encountered during validation.
  """

  @enforce_keys [:kind, :data, :args, :formatter, :data_path, :eval_path]
  defstruct @enforce_keys

  @opaque t :: %__MODULE__{}

  @doc false
  @spec format_error(:boolean_schema, term, term) :: binary
  def format_error(:boolean_schema, %{}, _data) do
    "value was rejected from boolean schema: false"
  end
end
