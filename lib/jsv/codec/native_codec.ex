# credo:disable-for-this-file Credo.Check.Readability.Specs

if Code.ensure_loaded?(JSON) do
  defmodule JSV.Codec.NativeCodec do
    @moduledoc false

    def decode!(json) do
      JSON.decode!(json)
    end

    def decode(json) do
      JSON.decode(json)
    end

    def encode_to_iodata!(data) do
      JSON.encode_to_iodata!(data)
    end

    if Code.ensure_loaded?(:json) do
      def format_to_iodata!(data) do
        :json.format(data)
      end
    else
      # Formatting will not be supported
      def format_to_iodata!(data) do
        encode_to_iodata!(data)
      end
    end

    @spec to_ordered_data(term, term) :: no_return()
    def to_ordered_data(_data, _key_sorter) do
      raise "ordered JSON encoding requires Jason"
    end
  end
end
