defmodule JSV.FormatValidator.Default.Optional do
  @moduledoc false
  @spec optional_support(binary, boolean) :: [binary]
  def optional_support(format, supported?) when is_boolean(supported?) do
    if supported? do
      List.wrap(format)
    else
      []
    end
  end

  @spec mod_exists?(module) :: boolean
  def mod_exists?(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} -> true
      {:error, _} -> false
    end
  end
end

defmodule JSV.FormatValidator.Default do
  import JSV.FormatValidator.Default.Optional, only: [mod_exists?: 1, optional_support: 2]
  alias JSV.FormatValidator.Default.Optional

  @moduledoc """
  Default implementation of format validation.

  Refer to the "Formats" section in the `JSV` documentation to know which
  formats are supported. This can depend on the current Elixir version and
  available optional libraries.
  """

  @behaviour JSV.FormatValidator

  @supports_duration mod_exists?(Duration)
  @supports_email mod_exists?(MailAddress.Parser)
  @supports_iri mod_exists?(AbnfParsec)
  @supports_uri_template mod_exists?(AbnfParsec)
  @supports_json_pointer mod_exists?(AbnfParsec)

  @re_hostname ~r/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/

  @formats [
             "ipv4",
             "ipv6",
             "unknown",
             "regex",
             "date",
             "date-time",
             "time",
             "hostname",
             "uri",
             "uri-reference",
             "uuid",
             optional_support("duration", @supports_duration),
             optional_support("email", @supports_email),
             optional_support("iri", @supports_iri),
             optional_support("iri-reference", @supports_iri),
             optional_support("uri-template", @supports_uri_template),
             optional_support(["json-pointer", "relative-json-pointer"], @supports_json_pointer)
           ]
           |> :lists.flatten()
           |> Enum.sort()

  @impl true
  def supported_formats do
    @formats
  end

  @impl true
  def validate_cast("date-time", data) do
    case DateTime.from_iso8601(data) do
      {:ok, dt, _} ->
        if String.contains?(data, " ") do
          {:error, :invalid_format}
        else
          {:ok, dt}
        end

      {:error, _} = err ->
        err
    end
  end

  def validate_cast("date", data) do
    Date.from_iso8601(data)
  end

  if @supports_duration do
    def validate_cast("duration", data) do
      # JSON schema adheres closely to the spec, the duration cannot mix Week and
      # other P-level elements. But we are allowing it because Elixir allows it,
      # we do not want to put arbitrary limit to capabilities.
      Duration.from_iso8601(data)
    end
  end

  def validate_cast("time", data) do
    Time.from_iso8601(String.replace(data, "z", "Z"))
  end

  def validate_cast("ipv4", data) do
    :inet.parse_strict_address(String.to_charlist(data))
  end

  def validate_cast("ipv6", data) do
    # JSON schema spec does not support zone info suffix in ipv6
    with {:ok, {_, _, _, _, _, _, _, _} = ipv6} <- :inet.parse_strict_address(String.to_charlist(data)),
         false <- String.contains?(data, "%") do
      {:ok, ipv6}
    else
      _ -> {:error, :invalid_ipv6}
    end
  end

  def validate_cast("uuid", data) do
    Optional.UUID.parse_uuid(data)
  end

  def validate_cast("regex", data) do
    Regex.compile(data)
  end

  def validate_cast("unknown", data) do
    {:ok, data}
  end

  if @supports_email do
    def validate_cast("email", data) do
      if MailAddress.Parser.valid?(data) do
        {:ok, data}
      else
        {:error, :invalid_email}
      end
    end
  end

  def validate_cast("hostname", data) do
    if Regex.match?(@re_hostname, data) do
      {:ok, data}
    else
      {:error, :invalid_hostname}
    end
  end

  if @supports_iri do
    def validate_cast("iri", data) do
      Optional.IRI.parse_iri(data)
    end

    def validate_cast("iri-reference", data) do
      Optional.IRI.parse_iri_reference(data)
    end
  end

  def validate_cast("uri", data) do
    Optional.URI.parse_uri(data)
  end

  def validate_cast("uri-reference", data) do
    Optional.URI.parse_uri_reference(data)
  end

  if @supports_uri_template do
    def validate_cast("uri-template", data) do
      Optional.URITemplate.parse_uri_template(data)
    end
  end

  if @supports_json_pointer do
    def validate_cast("json-pointer", data) do
      Optional.JSONPointer.parse_json_pointer(data)
    end

    def validate_cast("relative-json-pointer", data) do
      Optional.JSONPointer.parse_relative_json_pointer(data)
    end
  end
end
