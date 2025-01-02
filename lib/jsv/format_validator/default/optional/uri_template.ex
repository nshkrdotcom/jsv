require JSV.FormatValidator.Default.Optional

if JSV.FormatValidator.Default.Optional.mod_exists?(AbnfParsec) do
  defmodule JSV.FormatValidator.Default.Optional.URITemplate do
    @external_resource "priv/uri-template.abnf"

    use AbnfParsec,
      abnf_file: "priv/uri-template.abnf",
      unbox: [],
      ignore: []

    def parse_uri_template(data) do
      case uri_template(data) do
        {:ok, _, "", _, _, _} -> {:ok, data}
        _ -> {:error, :invalid_URI_template}
      end
    end
  end
end
