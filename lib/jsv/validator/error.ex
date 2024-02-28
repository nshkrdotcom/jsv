defmodule JSV.Validator.Error do
  @enforce_keys [:kind, :data, :args, :formatter, :data_path, :eval_path]
  defstruct @enforce_keys

  @opaque t :: %__MODULE__{}

  def format_error(:boolean_schema, %{}, _data) do
    "value was rejected from boolean schema: false"
  end
end
