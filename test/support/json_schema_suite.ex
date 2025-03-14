# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule JSV.Test.JsonSchemaSuite do
  alias JSV.Schema
  alias JSV.ValidationError
  alias JSV.Validator
  alias JSV.Validator.ValidationContext
  import ExUnit.Assertions
  require Logger
  use ExUnit.CaseTemplate

  @moduledoc false

  def run_test(json_schema, schema, data, expected_valid, opts \\ []) do
    {valid?, %ValidationContext{} = validator} =
      case JSV.validation_entrypoint(schema, data, []) do
        {:ok, casted, vctx} ->
          # This can fail if we have casting during the validation. It should
          # not happen for the generated suite.
          assert data == casted
          {true, vctx}

        {:error, validator} ->
          _ = test_error_format(validator, opts)
          {false, validator}
      end

    # assert the expected result

    case {expected_valid, valid?} do
      {true, true} ->
        {valid?, validator}

      {false, false} ->
        {valid?, validator}

      _ ->
        flunk("""
        #{if expected_valid do
          "Expected valid, got errors"
        else
          "Expected errors, got valid"
        end}

        JSON SCHEMA
        #{inspect(Schema.normalize(json_schema), pretty: true)}

        DATA
        #{inspect(data, pretty: true)}

        SCHEMA
        #{inspect(schema, pretty: true)}

        ERRORS
        #{inspect(validator.errors, pretty: true)}
        """)
    end
  end

  defp test_error_format(validator, opts) do
    error = Validator.to_error(validator)
    _ = assert %ValidationError{} = error
    formatted = JSV.normalize_error(error)
    assert ValidationError.message(error) =~ "json schema"
    assert is_list(formatted.details)

    Enum.each(formatted.details, fn unit ->
      assert false == unit.valid
      assert list_or_undef?(unit, :errors)
      assert list_or_undef?(unit, :details)
      assert is_binary(unit.evaluationPath)
      assert is_binary(unit.schemaLocation)
      assert is_binary(unit.instanceLocation)
    end)

    # Ensure JSON encodable
    json_errors = JSV.Codec.format!(formatted)

    if opts[:print_errors] do
      IO.puts(["\n", json_errors])
    end
  end

  defp list_or_undef?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, v} -> is_list(v)
    end
  end

  def build_schema(json_schema, build_opts) do
    case JSV.build(json_schema, [resolver: {JSV.Test.TestResolver, [fake_opts: true]}] ++ build_opts) do
      {:ok, schema} -> schema
      {:error, reason} -> flunk(denorm_failure(json_schema, reason, []))
    end
  rescue
    e in FunctionClauseError ->
      IO.puts(denorm_failure(json_schema, e, __STACKTRACE__))
      reraise e, __STACKTRACE__
  end

  defp denorm_failure(json_schema, reason, stacktrace) do
    """
    Failed to denormalize schema.

    SCHEMA
    #{inspect(json_schema, pretty: true)}

    ERROR
    #{Exception.format(:error, reason, stacktrace)}
    """
  end

  def version_check(elixir_version_req) do
    Version.match?(System.version(), elixir_version_req)
  end
end
