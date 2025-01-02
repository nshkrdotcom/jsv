defmodule JSV.Helpers do
  @type result :: {:ok, term} | {:error, term}
  @type result(t) :: {:ok, t} | {:error, term}
  import Kernel, except: [trunc: 1]

  @moduledoc false

  @spec reduce_ok(Enumerable.t(), term, (term, term -> result)) :: result
  def reduce_ok(enum, initial, f) when is_function(f, 2) do
    reduced =
      Enum.reduce_while(enum, initial, fn item, acc ->
        case f.(item, acc) do
          {:ok, new_acc} -> {:cont, new_acc}
          {:error, _} = err -> {:halt, err}
          other -> raise ArgumentError, "bad return from reduce_ok callback: #{inspect(other)}"
        end
      end)

    case reduced do
      {:error, _} = err -> err
      acc -> {:ok, acc}
    end
  end

  # TODO this will not work with large numbers
  @spec fractional_is_zero?(float) :: boolean
  def fractional_is_zero?(n) when is_float(n) do
    n - Kernel.trunc(n) === 0.0
  end

  # TODO check behaviour with large numbers
  @doc false
  @spec trunc(number) :: integer
  def trunc(n) when is_float(n) do
    Kernel.trunc(n)
  end
end
