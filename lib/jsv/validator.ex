defmodule JSV.Validator do
  alias JSV
  alias JSV.BooleanSchema
  alias JSV.Key
  alias JSV.Subschema
  alias JSV.ValidationError
  alias JSV.Validator.Error

  @moduledoc """
  This is the home of the recursive validation logic.

  The validator is called on the root schema, and may be called by vocabulary
  implementations to validate sub parts of the data built withing each
  vocabulary module.
  """

  defmodule ValidationContext do
    @moduledoc """
    Validation context carried along by the `JSV.Validator` and given to all
    vocabulary implementations.

    This struct is used to store errors found during validation, and to hold
    contextual information such as the current path in the data or in the
    schema.
    """

    # :eval_path stores both the current keyword nesting leading to an error, and
    # the namespace changes for error absolute location.
    @enforce_keys [:data_path, :eval_path, :validators, :scope, :errors, :evaluated, :opts]
    defstruct @enforce_keys
  end

  @type context :: %ValidationContext{}
  @type path_segment :: binary | non_neg_integer | atom
  @type eval_path_segment :: path_segment | [path_segment]
  @type validator :: JSV.Subschema.t() | BooleanSchema.t() | {:alias_of, binary}
  @type result :: {:ok, term, context} | {:error, context}

  @spec context(%{Key.t() => validator}, [Key.ns()], keyword()) :: context
  def context(validators, scope, opts) do
    %ValidationContext{
      data_path: [],
      eval_path: [],
      validators: validators,
      scope: scope,
      errors: [],
      evaluated: [%{}],
      opts: opts
    }
  end

  @doc """
  Validate the given data with the given validator. The validator is typically a
  sub-part of a `JSV.Root` struct built with `JSV.build/2` such as a
  `JSV.Subschema` struct.
  """
  @spec validate(term, validator(), context) :: result
  def validate(data, subschema, vctx)

  def validate(data, %BooleanSchema{} = bs, vctx) do
    case bs.valid? do
      true -> return(data, vctx)
      false -> {:error, add_error(vctx, boolean_schema_error(vctx, bs, data))}
    end
  end

  def validate(data, {:alias_of, key}, vctx) do
    with_scope(vctx, key, _eval_path = {:alias_of, key}, fn vctx ->
      validate(data, Map.fetch!(vctx.validators, key), vctx)
    end)
  end

  def validate(data, sub_schema, vctx) do
    do_validate(data, sub_schema, vctx)
  end

  # Executes all validators with the given data, collecting errors on the way,
  # then return either ok or error with all errors.
  defp do_validate(data, %Subschema{} = sub, vctx) do
    %{validators: validators} = sub

    reduce(validators, data, vctx, fn {module, mod_validators}, data, vctx ->
      module.validate(data, mod_validators, vctx)
    end)
  end

  @doc """
  Reduce over an enum with two accumulators, a user one, and the context.

  * The callback is called with `item, acc, vctx` for all items in the enum,
    regardless of previously returned values. Returning and error tuple does not
    stop the iteration.
  * When returning `{:ok, value, vctx}`, `value` will be the new user
    accumulator, and the new context is carried on.
  * When returning `{:error, vctx}`, the current accumulator is not changed, but
    the new returned context with errors is still carried on.
  * Returning an ok tuple after an error tuple on a previous item does not
    remove the errors from the context struct.

  The final return value is `{:ok, acc, vctx}` if all calls of the callback
  returned an OK tuple, `{:error, vctx}` otherwise.

  This is useful to call all possible validators for a given piece of data,
  collecting all possible errors without stopping, but still returning an error
  in the end if some error arose.
  """
  @spec reduce(Enumerable.t(), term, context, function) :: result
  def reduce(enum, init, vctx, fun) when is_function(fun, 3) do
    {new_acc, new_vctx} =
      Enum.reduce(enum, {init, vctx}, fn item, {acc, vctx} ->
        res = fun.(item, acc, vctx)

        case res do
          # When returning :ok, the errors may be empty or not, depending on
          # previous iterations.
          {:ok, new_acc, new_vctx} ->
            {new_acc, new_vctx}

          # When returning :error, an error MUST be set
          {:error, %ValidationContext{errors: [_ | _]} = new_vctx} ->
            {acc, new_vctx}

          other ->
            raise "Invalid return from #{inspect(fun)} called with #{inspect(item)}: #{inspect(other)}"
        end
      end)

    return(new_acc, new_vctx)
  end

  @doc """
  Validate the data with the given validators but separate the current
  evaluation context during the validation.

  Currently evaluated properties or items will not be seen as evaluated during
  the validation by the given `subschema`.
  """
  @spec validate_detach(term, eval_path_segment, validator, context) :: result
  def validate_detach(data, add_eval_path, subschema, vctx) do
    %{eval_path: eval_path} = vctx
    sub_vctx = %ValidationContext{vctx | evaluated: [%{}], eval_path: [add_eval_path | eval_path]}

    case validate(data, subschema, sub_vctx) do
      {:ok, data, new_sub} -> {:ok, data, new_sub}
      {:error, new_sub} -> {:error, new_sub}
    end
  end

  @doc """
  Validates a sub term of the data, identified by `key`, which can be a property
  name (a string), or an array index (an integer).

  See `validate_as/4` to validate the same data point with a nested keyword. For
  instance `if`, `then` or `else`.
  """
  @spec validate_in(term, path_segment, eval_path_segment, validator, context) :: result
  def validate_in(data, key, add_eval_path, subvalidators, vctx)
      when is_binary(key)
      when is_integer(key) do
    %ValidationContext{
      data_path: data_path,
      validators: all_validators,
      scope: scope,
      evaluated: evaluated,
      eval_path: eval_path
    } = vctx

    sub_vctx = %ValidationContext{
      vctx
      | data_path: [key | data_path],
        eval_path: [add_eval_path | eval_path],
        errors: [],
        validators: all_validators,
        scope: scope,
        evaluated: [%{} | evaluated]
    }

    case validate(data, subvalidators, sub_vctx) do
      {:ok, data, sub_vctx} ->
        # There should not be errors in sub at this point ?
        new_vctx = vctx |> add_evaluated(key) |> merge_errors(sub_vctx)
        {:ok, data, new_vctx}

      {:error, %ValidationContext{errors: [_ | _]} = sub_vctx} ->
        {:error, merge_errors(vctx, sub_vctx)}
    end
  end

  @doc """
  Validates data with a sub part of the schema, for instance `if`, `then` or
  `else`. Data path will not change in the context.

  See `validate_in/5` to validate sub terms of the data.
  """
  @spec validate_as(term, eval_path_segment(), validator(), context) :: result
  def validate_as(data, add_eval_path, subvalidators, vctx) do
    %ValidationContext{
      data_path: data_path,
      validators: all_validators,
      scope: scope,
      evaluated: evaluated,
      eval_path: eval_path
    } = vctx

    sub_vctx = %ValidationContext{
      vctx
      | data_path: data_path,
        eval_path: [add_eval_path | eval_path],
        errors: [],
        validators: all_validators,
        scope: scope,
        evaluated: [%{} | evaluated]
    }

    case validate(data, subvalidators, sub_vctx) do
      {:ok, data, sub_vctx} ->
        # There should not be errors in sub at this point ?
        new_vctx = vctx |> merge_evaluated(sub_vctx) |> merge_errors(sub_vctx)
        {:ok, data, new_vctx}

      {:error, %ValidationContext{errors: [_ | _]} = sub_vctx} ->
        {:error, merge_errors(vctx, sub_vctx)}
    end
  end

  # Kind is for the eval path
  @spec validate_ref(term, Key.t(), eval_path_segment(), context) :: result
  def validate_ref(data, ref, eval_path, vctx) do
    with_scope(vctx, ref, {:ref, eval_path, ref}, fn vctx ->
      do_validate_ref(data, ref, vctx)
    end)
  end

  defp do_validate_ref(data, ref, vctx) do
    subvalidators = checkout_ref(vctx, ref)

    %ValidationContext{
      data_path: data_path,
      validators: all_validators,
      scope: scope,
      evaluated: evaluated,
      eval_path: eval_path
    } = vctx

    # TODO separate validator must have its isolated evaluated data_paths list
    separate_vctx = %ValidationContext{
      vctx
      | data_path: data_path,
        # TODO append eval path
        eval_path: eval_path,
        errors: [],
        validators: all_validators,
        scope: scope,
        evaluated: evaluated
    }

    case validate(data, subvalidators, separate_vctx) do
      {:ok, data, separate_vctx} ->
        # There should not be errors in sub at this point ?
        new_vctx = vctx |> merge_evaluated(separate_vctx) |> merge_errors(separate_vctx)
        {:ok, data, new_vctx}

      {:error, %ValidationContext{errors: [_ | _]} = separate_vctx} ->
        {:error, merge_errors(vctx, separate_vctx)}
    end
  end

  defp with_scope(vctx, sub_key, add_eval_path, fun) do
    %{scope: scopes, eval_path: eval_path} = vctx

    # Premature optimization that can be removed: skip appending scope if it is
    # the same as the current one.
    sub_vctx =
      case {Key.namespace_of(sub_key), scopes} do
        {same, [same | _]} ->
          %ValidationContext{vctx | eval_path: [add_eval_path | eval_path]}

        {new_scope, scopes} ->
          %ValidationContext{vctx | scope: [new_scope | scopes], eval_path: [add_eval_path | eval_path]}
      end

    case fun.(sub_vctx) do
      {:ok, data, vctx} -> {:ok, data, %ValidationContext{vctx | scope: scopes, eval_path: eval_path}}
      {:error, vctx} -> {:error, %ValidationContext{vctx | scope: scopes, eval_path: eval_path}}
    end
  end

  defp merge_errors(vctx, sub) do
    %ValidationContext{errors: vctx_errors} = vctx
    %ValidationContext{errors: sub_errors} = sub
    %ValidationContext{vctx | errors: do_merge_errors(vctx_errors, sub_errors)}
  end

  defp do_merge_errors([], sub_errors) do
    sub_errors
  end

  defp do_merge_errors(vctx_errors, []) do
    vctx_errors
  end

  defp do_merge_errors(vctx_errors, sub_errors) do
    # TODO maybe append but for now we will flatten only when rendering/formatting errors
    [vctx_errors, sub_errors]
  end

  @spec merge_evaluated(context, context) :: context
  def merge_evaluated(vctx, sub) do
    %ValidationContext{evaluated: [top_vctx | rest_vctx]} = vctx
    %ValidationContext{evaluated: [top_sub | _rest_sub]} = sub
    %ValidationContext{vctx | evaluated: [Map.merge(top_vctx, top_sub) | rest_vctx]}
  end

  @spec return(term, context) :: result
  def return(data, %ValidationContext{errors: []} = vctx) do
    {:ok, data, vctx}
  end

  def return(_data, %ValidationContext{errors: [_ | _]} = vctx) do
    {:error, vctx}
  end

  defp checkout_ref(%{scope: scope} = vctx, {:dynamic_anchor, ns, anchor}) do
    case checkout_dynamic_ref(scope, vctx, anchor) do
      :error -> checkout_ref(vctx, {:anchor, ns, anchor})
      {:ok, v} -> v
    end
  end

  defp checkout_ref(%{validators: vds}, vkey) do
    Map.fetch!(vds, vkey)
  end

  defp checkout_dynamic_ref([h | scope], vctx, anchor) do
    # Recursion first as the outermost scope should have priority. If the
    # dynamic ref resolution fails with all outer scopes, then actually try to
    # resolve from this scope.
    with :error <- checkout_dynamic_ref(scope, vctx, anchor) do
      Map.fetch(vctx.validators, {:dynamic_anchor, h, anchor})
    end
  end

  defp checkout_dynamic_ref([], _, _) do
    :error
  end

  defp boolean_schema_error(vctx, %BooleanSchema{valid?: false}, data) do
    %Error{
      kind: :boolean_schema,
      data: data,
      data_path: vctx.data_path,
      eval_path: vctx.eval_path,
      formatter: nil,
      args: []
    }
  end

  defmacro with_error(vctx, kind, data, args) do
    quote bind_quoted: binding() do
      JSV.Validator.__with_error__(__MODULE__, vctx, kind, data, args)
    end
  end

  @doc false
  @spec __with_error__(module, context, atom, term, term) :: context
  def __with_error__(module, vctx, kind, data, args) do
    error = %Error{
      kind: kind,
      data: data,
      data_path: vctx.data_path,
      eval_path: vctx.eval_path,
      formatter: module,
      args: args
    }

    add_error(vctx, error)
  end

  defp add_error(vctx, error) do
    %ValidationContext{errors: errors} = vctx
    %ValidationContext{vctx | errors: [error | errors]}
  end

  defp add_evaluated(vctx, key) do
    %{evaluated: [current | ev]} = vctx
    current = Map.put(current, key, true)
    %ValidationContext{vctx | evaluated: [current | ev]}
  end

  @spec list_evaluaded(context) :: [path_segment()]
  def list_evaluaded(vctx) do
    %{evaluated: [current | _]} = vctx
    Map.keys(current)
  end

  @spec flat_errors(context) :: [Error.t()]
  def flat_errors(vctx) do
    :lists.flatten(vctx.errors)
  end

  @spec to_error(context) :: ValidationError.t()
  def to_error(vctx) do
    ValidationError.of(flat_errors(vctx))
  end
end
