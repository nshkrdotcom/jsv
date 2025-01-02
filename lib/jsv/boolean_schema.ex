defmodule JSV.BooleanSchema do
  @moduledoc """
  Represents a boolean schema. Boolean schemas accept or reject any data
  according to their boolean value.

  This is very often used with the `additionalProperties` keyword.
  """

  defstruct [:valid?]

  @type t :: %__MODULE__{valid?: boolean}

  @doc """
  Returns a `#{inspect(__MODULE__)}` struct wrapping the given boolean.
  """
  @spec of(boolean) :: t
  def of(true) do
    %__MODULE__{valid?: true}
  end

  def of(false) do
    %__MODULE__{valid?: false}
  end
end
