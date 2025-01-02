defmodule JSV.Root do
  @moduledoc """
  Internal representation of a JSON schema built with `JSV.build/2`.

  The original schema, in its string-keys form, can be retrieved in the `:raw`
  key of the struct.
  """
  alias JSV.Validator

  defstruct validators: %{},
            root_key: nil,
            raw: nil

  @type t :: %__MODULE__{raw: map | boolean, validators: %{term => Validator.validator()}}
end
