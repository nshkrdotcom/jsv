defmodule JSV.Vocabulary.V202012.Content do
  use JSV.Vocabulary, priority: 300

  @moduledoc """
  Invactive implementation for the
  `https://json-schema.org/draft/2020-12/vocab/content` vocabulary. No
  validation is performed.
  """

  @impl true
  def init_validators(_) do
    []
  end

  @impl true
  take_keyword :contentMediaType, _, acc, builder, _ do
    {:ok, acc, builder}
  end

  take_keyword :contentEncoding, _, acc, builder, _ do
    {:ok, acc, builder}
  end

  take_keyword :contentSchema, _, acc, builder, _ do
    {:ok, acc, builder}
  end

  ignore_any_keyword()

  @impl true
  def finalize_validators([]) do
    :ignore
  end

  @impl true
  @spec validate(term, term, term) :: no_return()
  def validate(_data, _validators, _context) do
    raise "should not be called"
  end
end
