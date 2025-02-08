defmodule JSV.Resolver.InternalTest do
  alias JSV.AtomTools
  alias JSV.Resolver.Internal
  use ExUnit.Case, async: true

  test "will not resolve an unexisting module" do
    assert {:error, {:invalid_schema_module, "not an existing atom: unexisting_module"}} =
             Internal.resolve("jsv:module:unexisting_module", [])

    uri = AtomTools.module_to_uri(UnknownModule)

    assert {:error,
            {:invalid_schema_module,
             "function UnknownModule.schema/0 is undefined (module UnknownModule is not available)" <> _}} =
             Internal.resolve(uri, [])
  end

  test "will not resolve a module not exporting schema" do
    defmodule EmptyModule do
    end

    uri = AtomTools.module_to_uri(EmptyModule)

    assert {:error,
            {:invalid_schema_module, "function JSV.Resolver.InternalTest.EmptyModule.schema/0 is undefined or private"}} ==
             Internal.resolve(uri, [])
  end

  test "will resolve a module with the proper callback" do
    defmodule CorrectModule do
      @spec schema :: term
      def schema do
        :not_actually_a_schema_but_still_deatomized
      end
    end

    uri = AtomTools.module_to_uri(CorrectModule)
    assert {:ok, "not_actually_a_schema_but_still_deatomized"} == Internal.resolve(uri, [])
  end
end
