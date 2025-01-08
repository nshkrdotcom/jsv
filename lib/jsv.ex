defmodule JSV do
  alias JSV.AtomTools
  alias JSV.BooleanSchema
  alias JSV.Builder
  alias JSV.ErrorFormatter
  alias JSV.Root
  alias JSV.ValidationError
  alias JSV.Validator
  alias JSV.Validator.ValidationContext

  readme =
    "README.md"
    |> File.read!()
    |> String.split("<!-- moduledoc-split -->")
    |> tl()

  @moduledoc """
  This is the main API for the JSV library.

  #{readme}
  """

  @default_default_meta "https://json-schema.org/draft/2020-12/schema"

  @build_opts_schema NimbleOptions.new!(
                       resolver: [
                         type: {:or, [:atom, :mod_arg]},
                         default: JSV.Resolver.Embedded,
                         doc: """
                         The `JSV.Resolver` behaviour implementation module to
                         retrieve schemas identified by an URL.

                         Accepts a `module` or a `{module, options}` tuple.
                         The options can be any term and will be given to the
                         `resolve/2` callback of the module.
                         """
                       ],
                       default_meta: [
                         type: :string,
                         doc:
                           ~S(The meta schema to use for resolved schemas that do not define a `"$schema"` property.),
                         default: @default_default_meta
                       ],
                       formats: [
                         type: {:or, [:boolean, nil, {:list, :atom}]},
                         doc: """
                         Controls the validation of strings with the `"format"` keyword.

                         * `nil` - Formats are validated according to the meta-schema vocabulary.
                         * `true` - Enforces validation with the default validator modules.
                         * `false` - Disables all format validation.
                         * `[Module1, Module2,...]` – set those modules as validators. Disables the default format validator modules.
                            The default validators can be included back in the list manually, see `default_format_validator_modules/0`.

                         > #### Formats are disabled by the default meta-schemas {: .warning}
                         >
                         > The default value for this option is `nil` to respect
                         > the capability of enably validation with vocabularies.
                         >
                         > But the default meta-schemas for the latest drafts (example: `#{@default_default_meta}`)
                         > do not enable format validation.
                         >
                         > You'll probably want this option to be set to `true`
                         > or to provide your own modules.
                         """,
                         default: nil
                       ]
                     )

  @doc """
  Builds the schema as a `#{inspect(Root)}` schema for validation.

  ### Options

  #{NimbleOptions.docs(@build_opts_schema)}
  """
  @spec build(Builder.raw_schema(), keyword) :: {:ok, Root.t()} | {:error, Exception.t()}
  def build(raw_schema, opts \\ [])

  def build(raw_schema, opts) when is_map(raw_schema) do
    raw_schema = AtomTools.fmap_atom_to_binary(raw_schema)

    case NimbleOptions.validate(opts, @build_opts_schema) do
      {:ok, opts} ->
        builder = Builder.new(opts)

        case Builder.build(builder, raw_schema) do
          {:ok, root} -> {:ok, root}
          {:error, reason} -> {:error, %JSV.BuildError{reason: reason}}
        end

      {:error, _} = err ->
        err
    end
  end

  def build(valid?, _opts) when is_boolean(valid?) do
    {:ok, %Root{raw: valid?, root_key: :root, validators: %{root: BooleanSchema.of(valid?)}}}
  end

  @doc """
  Same as `build/2` but raises on error.
  """
  @spec build!(Builder.raw_schema(), keyword) :: Root.t()
  def build!(raw_schema, opts \\ [])

  def build!(raw_schema, opts) do
    case build(raw_schema, opts) do
      {:ok, root} -> root
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Returns the default meta schema used when the `:default_meta` option is not
  set in `build/2`.

  Currently returns #{inspect(@default_default_meta)}.
  """
  @spec default_meta :: binary
  def default_meta do
    @default_default_meta
  end

  @validate_opts_schema NimbleOptions.new!(
                          cast_formats: [
                            type: :boolean,
                            default: false,
                            doc:
                              "When enabled format validators will return casted values, " <>
                                "for instance a `Date` struct instead of the date as string. " <>
                                "It has no effect when the schema was not built with formats enabled."
                          ]
                        )

  @doc """
  Validate the data with the given schema. The schema must be a `JSV.Root`
  struct generated with `build/2`.

  **Important**: this function returns casted data:

  * If the `:cast_formats` option is enabled, string values may be transformed
    in other data structures. Refer to the "Formats" section of the `JSV`
    documentation for more information.
  * The JSON Schema specification states that `123.0` is a valid integer. This
    function will return `123` instead. This may return invalid data for floats
    with very large integer parts. As always when dealing with JSON and floats,
    use strings.
  * Future versions of the library will allow to cast raw data into Elixir
    structs.

  ### Options

  #{NimbleOptions.docs(@validate_opts_schema)}
  """
  @spec validate(term, JSV.Root.t(), keyword) :: {:ok, term} | {:error, Exception.t()}
  def validate(data, root, opts \\ [])

  def validate(data, %JSV.Root{} = root, opts) do
    case NimbleOptions.validate(opts, @validate_opts_schema) do
      {:ok, opts} ->
        case validation_entrypoint(root, data, opts) do
          {:ok, casted_data, _} -> {:ok, casted_data}
          {:error, %ValidationContext{} = validator} -> {:error, Validator.to_error(validator)}
        end

      {:error, _} = err ->
        err
    end
  end

  @spec normalize_error(ValidationError.t() | Validator.context() | [Validator.Error.t()]) :: map()
  def normalize_error(%ValidationError{} = error) do
    ErrorFormatter.normalize_error(error)
  end

  def normalize_error(errors) when is_list(errors) do
    normalize_error(ValidationError.of(errors))
  end

  # TODO provide a way to return ordered json for errors, or just provide a
  # preprocess function.
  def normalize_error(%ValidationContext{} = validator) do
    normalize_error(Validator.to_error(validator))
  end

  @doc false
  # direct entrypoint for tests when we want to get the returned context.
  @spec validation_entrypoint(term, term, term) :: Validator.result()
  def validation_entrypoint(%JSV.Root{} = schema, data, opts) do
    %JSV.Root{validators: validators, root_key: root_key} = schema
    root_schema_validators = Map.fetch!(validators, root_key)
    context = JSV.Validator.context(validators, _scope = [root_key], opts)
    JSV.Validator.validate(data, root_schema_validators, context)
  end

  @doc """
  Returns the list of format validator modules that are used when a schema is
  built with format validation enabled and the `:formats` option to `build/2` is
  `true`.
  """
  @spec default_format_validator_modules :: [module]
  def default_format_validator_modules do
    [JSV.FormatValidator.Default]
  end
end
