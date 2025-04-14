require JSV.FormatValidator.Default.Optional

if JSV.FormatValidator.Default.Optional.mod_exists?(AbnfParsec) do
  defmodule JSV.FormatValidator.Default.Optional.EmailAddress do
    @moduledoc false
    @external_resource "priv/grammars/email-address.abnf"
    use AbnfParsec,
      abnf_file: "priv/grammars/email-address.abnf",
      unbox: [],
      ignore: []

    @doc false
    @spec parse_email_address(String.t()) :: {:ok, String.t()} | {:error, term}
    def parse_email_address(data) do
      case email_address(data) do
        {:ok, _, "", _, _, _} -> {:ok, data}
        _ -> {:error, :invalid_email}
      end
    end
  end
end
