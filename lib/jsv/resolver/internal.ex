defmodule JSV.Resolver.Internal do
  @behaviour JSV.Resolver

  @moduledoc """
  A `JSV.Resolver` implementation that resolves URIs pointing to the application
  code base or JSV code base.

  A custom resolver implementation should delegate `jsv:` prefixed URIs to this
  module to enable support of the internal resolutions features.

  ### Module based schemas

  This resolver will resolve `jsv:module:MODULE` URIs where `MODULE` is a string
  representation of an Elixir module. Modules pointed at with such references
  MUST export a `schema/0` function that returns a normalized (with binary keys
  and values) JSON schema.
  """
  alias JSV.AtomTools

  @impl true
  def resolve(url, opts)

  def resolve("jsv:module:" <> module_string, _) do
    case cast_to_existing_atom(module_string) do
      {:ok, module} -> {:ok, AtomTools.deatomize(module.schema())}
      {:error, reason} -> {:error, {:invalid_schema_module, reason}}
    end
  rescue
    e -> {:error, {:invalid_schema_module, Exception.message(e)}}
  end

  def resolve(other, _) do
    {:error, {:unsupported, other}}
  end

  defp cast_to_existing_atom(module_string) do
    {:ok, String.to_existing_atom(module_string)}
  rescue
    _ -> {:error, "not an existing atom: #{module_string}"}
  end
end
