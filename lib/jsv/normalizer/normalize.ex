defprotocol JSV.Normalizer.Normalize do
  @moduledoc """
  Protocol used by `JSV.Normalizer` to normalize structs.
  """
  @spec normalize(term) :: term
  def normalize(t)
end
