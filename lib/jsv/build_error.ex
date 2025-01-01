defmodule JSV.BuildError do
  @enforce_keys [:reason]
  defexception @enforce_keys

  def of(reason) do
    %__MODULE__{reason: reason}
  end

  def message(e) do
    "could not build JSON schema, got error: #{inspect(e.reason)}"
  end
end
