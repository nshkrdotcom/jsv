defmodule JSV.Resolver.InternalTest do
  alias JSV.Resolver.Internal
  use ExUnit.Case, async: true

  test "will not resolve an unexisting module" do
    assert {:error, {:unknown_module, "unexisting_module"}} =
             Internal.resolve("jsv:module:unexisting_module", [])

    uri = Internal.module_to_uri(UnknownModule)

    assert {:error, {:unknown_module, "Elixir.UnknownModule"}} = Internal.resolve(uri, [])
  end

  test "will not resolve a module not exporting schema" do
    defmodule EmptyModule do
    end

    uri = Internal.module_to_uri(EmptyModule)

    assert {:error, {:invalid_schema_module, e}} = Internal.resolve(uri, [])
    assert %UndefinedFunctionError{arity: 0, function: :schema, module: EmptyModule} = e
  end

  test "will resolve a module with the proper callback" do
    defmodule CorrectModule do
      @spec schema :: term
      def schema do
        %{type: :integer}
      end
    end

    uri = Internal.module_to_uri(CorrectModule)
    assert {:ok, %{type: :integer}} == Internal.resolve(uri, [])
  end
end
