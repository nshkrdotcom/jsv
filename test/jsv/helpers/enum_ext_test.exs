defmodule JSV.Helpers.EnumExtTest do
  use ExUnit.Case, async: true
  alias JSV.Helpers.EnumExt

  describe "reduce_ok/3" do
    test "reduces successfully" do
      input = [1, 2, 3, 4]
      result = EnumExt.reduce_ok(input, [], &{:ok, [&1 | &2]})
      assert result == {:ok, [4, 3, 2, 1]}
    end

    test "stops on first error" do
      input = [1, 2, 3, 4]

      result =
        EnumExt.reduce_ok(input, [], fn
          2, acc -> {:error, [2 | acc]}
          x, acc -> {:ok, [x | acc]}
        end)

      assert result == {:error, [2, 1]}
    end

    test "allows to return errors as values" do
      errors = [
        {:error, 1},
        {:error, 2},
        {:error, 4},
        {:error, 3},
        {:error, 0}
      ]

      assert {:ok, {:error, 4}} = EnumExt.reduce_ok(errors, {:error, -1}, fn item, best -> {:ok, max(item, best)} end)
    end
  end
end
