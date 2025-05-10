defprotocol JSV.Normalizer.Normalize do
  @moduledoc """
  Protocol used by `JSV.Normalizer` to transform structs into JSON-compatible
  data structures when normalizing a schema.
  """
  @spec normalize(term) :: term
  def normalize(t)
end
