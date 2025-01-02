alias JSV.Resolver.BuiltIn

specs = %{
  "date" => %{
    input: "2020-04-22",
    support: "Native.",
    notes: [
      "The format is implemented with the native `Date` module.",
      "The native `Date` module supports the `YYYY-MM-DD` format only. `2024`, `2024-W50`, `2024-12` will not be valid."
    ]
  },
  "date-time" => %{
    input: "2025-01-02T00:11:23.416689Z",
    support: "Native.",
    notes: [
      "The format is implemented with the native `DateTime` module.",
      "The native `DateTime` module supports the `YYYY-MM-DD` format only for dates. `2024T...`, `2024-W50T...`, `2024-12T...` will not be valid.",
      "Decimal precision is not capped to milliseconds. `2024-12-14T23:10:00.500000001Z` will be valid."
    ]
  },
  "duration" => %{
    input: "P1DT4,5S",
    support: "Requires Elixir 1.17",
    notes: [
      "Elixir documentation states that _Only seconds may be specified with a decimal fraction, using either a comma or a full stop: P1DT4,5S_.",
      "Elixir durations accept negative values.",
      "Elixir durations accept out-of-range values, for instance more than 59 minutes.",
      ~s[Excessive precision (as in `"PT10.0000000000001S"`) will be valid.]
    ]
  },
  "email" => %{
    input: "hello@json-schema.org",
    support: {:mail_address, "~> 1.0"},
    notes: [
      "Support is limited by the implementation of that library.",
      "The `idn-email` format is not supported out-of-the-box."
    ]
  },
  "hostname" => %{
    input: "some-host",
    support: "Native",
    notes: ["Accepts numerical TLDs and single letter TLDs."]
  },
  "ipv4" => %{
    input: "127.0.0.1",
    support: "Native",
    notes: []
  },
  "ipv6" => %{
    input: "::1",
    support: "Native",
    notes: []
  },
  "iri" => %{
    input: "https://héhé.com/héhé",
    support: {:abnf_parsec, "~> 1.0"},
    notes: []
  },
  "iri-reference" => %{
    input: "//héhé",
    support: {:abnf_parsec, "~> 1.0"},
    notes: []
  },
  "json-pointer" => %{
    input: "/foo/bar/baz",
    support: {:abnf_parsec, "~> 1.0"},
    notes: []
  },
  "relative-json-pointer" => %{
    input: "0/foo/bar",
    support: {:abnf_parsec, "~> 1.0"},
    notes: []
  },
  "regex" => %{
    input: "[a-zA-Z0-9]",
    support: "Native",
    notes: [
      "The format is implemented with the native `Regex` module.",
      "The `Regex` module does not follow the `ECMA-262` specification."
    ]
  },
  "time" => %{
    input: "20:20:08.378586",
    support: "Native",
    notes: [
      "The format is implemented with the native `Time` module.",
      "The native `Time` implementation will completely discard the time offset information. Invalid offsets will be valid.",
      "Decimal precision is not capped to milliseconds. `23:10:00.500000001` will be valid."
    ]
  },
  "unknown" => %{
    input: "anything",
    support: "Native",
    notes: ["No validation or transformation is done."]
  },
  "uri" => %{
    input: "http://example.com",
    support: ~s(Native, optionally uses `{:abnf_parsec, "~> 1.0"}`.),
    notes: [
      "Without the optional dependency, the `URI` module is used and a minimum checks on hostname and scheme presence are made."
    ]
  },
  "uri-reference" => %{
    input: "/example-path",
    support: ~s(Native, optionally uses `{:abnf_parsec, "~> 1.0"}`.),
    notes: [
      "Without the optional dependency, the `URI` module will cast most non url-like strings as a `path`."
    ]
  },
  "uri-template" => %{
    input: "http://example.com/search{?query,lang}",
    support: {:abnf_parsec, "~> 1.0"},
    notes: []
  },
  "uuid" => %{
    input: "bf22824c-c8a4-11ef-9642-0fdaf117eeb9",
    support: "Native",
    notes: []
  }
}

generated =
  JSV.FormatValidator.Default.supported_formats()
  |> Enum.sort()
  |> Enum.map(fn format ->
    schema = JSV.build!(%{format: format}, resolver: BuiltIn.as_default(), formats: true)

    {input, support, notes} =
      case Map.fetch(specs, format) do
        {:ok, %{input: input, support: support, notes: notes}} ->
          {input, support, notes}

        _ ->
          raise ~s'''
          Add specs:

          ,"#{format}" => %{
            input: ____,
            support: ____,
            notes: []
          }
          '''
      end

    {:ok, casted} = JSV.validate(input, schema, cast_formats: true)

    support =
      case support do
        b when is_binary(b) -> b
        {lib, version} -> "Requires `#{inspect({lib, version})}`."
      end

    output =
      case casted do
        ^input -> "`#{inspect(casted)}` (same value)"
        _ -> "`#{inspect(casted)}`"
      end

    """
    #### #{format}

    * **support**: #{support}
    * **input**: `#{inspect(input)}`
    * **output**: #{output}
    #{Enum.map(notes, &["* ", &1, "\n"])}
    """
    |> tap(&IO.puts/1)
  end)

readme_path = "README.md"

readme = File.read!(readme_path)
tag_before = "\n<!-- block:formats-table -->\n"
tag_after = "\n<!-- endblock:formats-table -->\n"

[before, readme] = String.split(readme, tag_before)
[_, afterw] = String.split(readme, tag_after)

readme = [before, tag_before, generated, tag_after, afterw]

:ok = File.write!(readme_path, readme)
