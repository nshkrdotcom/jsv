# credo:disable-for-this-file Credo.Check.Readability.Specs

if Code.ensure_loaded?(Poison) do
  defmodule JSV.Codec.PoisonCodec do
    @moduledoc false

    def decode!(json) do
      Poison.decode!(json)
    end

    def decode(json) do
      Poison.decode(json)
    end

    def encode_to_iodata!(data) do
      Poison.encode_to_iodata!(data, strict_keys: true)
    end

    def format_to_iodata!(data) do
      Poison.encode_to_iodata!(data, strict_keys: true, pretty: true)
    end

    @spec to_ordered_data(term, term) :: no_return()
    def to_ordered_data(_data, _key_sorter) do
      raise "ordered JSON encoding requires Jason"
    end
  end
end
