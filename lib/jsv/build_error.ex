defmodule JSV.BuildError do
  @moduledoc """
  A simple wrapper for errors returned from `JSV.build/2`.
  """

  @enforce_keys [:reason]
  defexception @enforce_keys

  @doc """
  Wraps the given term as the `reason` in a `#{inspect(__MODULE__)}` struct.
  """
  @spec of(term) :: Exception.t()
  def of(reason) do
    %__MODULE__{reason: reason}
  end

  @impl true
  def message(e) do
    "could not build JSON schema, got error: #{inspect(e.reason)}"
  end
end
