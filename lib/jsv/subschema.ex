defmodule JSV.Subschema do
  alias JSV.Vocabulary
  defstruct [:validators]

  @moduledoc """
  Build result for a raw map schema.
  """

  @type validators :: [{module, Vocabulary.collection()}]
  @type t :: %__MODULE__{validators: validators}
end
