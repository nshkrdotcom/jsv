defmodule JSV.TestHelpers do
  @moduledoc false
  defmacro env_mod(kind \\ []) do
    line = __CALLER__.line
    {fun, _} = __CALLER__.function

    test_name =
      fun
      |> Atom.to_string()
      |> String.replace(" ", "_")
      |> Macro.camelize()

    rand = "L#{line}"

    quote bind_quoted: binding() do
      Module.concat(:lists.flatten([kind, test_name, rand]))
    end
  end

  defmacro mock_for(behaviour) do
    quote do
      behaviour_name = unquote(behaviour) |> Module.split() |> List.last()

      mod = env_mod(["Mocks", behaviour_name])

      defmock(mod, for: unquote(behaviour))
    end
  end
end
