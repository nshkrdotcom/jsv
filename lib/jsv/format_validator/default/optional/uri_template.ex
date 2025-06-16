require JSV.FormatValidator.Default.Optional

if Code.ensure_loaded?(AbnfParsec) do
  defmodule JSV.FormatValidator.Default.Optional.URITemplate do
    @moduledoc false
    @external_resource "priv/grammars/uri-template.abnf"

    use AbnfParsec,
      abnf_file: "priv/grammars/uri-template.abnf",
      unbox: [],
      ignore: []

    @doc false
    @spec parse_uri_template(binary) :: {:ok, binary} | {:error, term}
    def parse_uri_template(data) do
      case uri_template(data) do
        {:ok, _, "", _, _, _} -> {:ok, data}
        _ -> {:error, :invalid_URI_template}
      end
    end
  end
end
