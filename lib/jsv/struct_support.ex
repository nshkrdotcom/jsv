defmodule JSV.StructSupport do
  alias JSV.Schema

  @moduledoc """
  Utilities to work with structs defined by schemas.
  """

  @doc """
  Validates the given raw schema can be used to define a module struct or raises
  an exception.

  It will check the following:

  * Schema defines a type `object`.
  * Schema has `properties`.
  * `properties` is a map with atom keys.
  * `required`, if present, contains only atoms
  """
  @spec validate!(JSV.raw_schema()) :: :ok
  def validate!(schema) do
    validate_object_type!(schema)
    validate_properties_presence!(schema)
    validate_properties_keys!(schema)
    required = validate_required_type!(schema)
    validate_required_keys!(required)
    :ok
  end

  defp validate_object_type!(schema) do
    t =
      case schema do
        %{"type" => t} -> t
        %Schema{type: nil} -> raise ArgumentError, errmsg("must define type")
        %{type: t} -> t
        _ -> raise ArgumentError, errmsg("must define type")
      end

    case t do
      :object -> :ok
      "object" -> :ok
      _ -> raise ArgumentError, errmsg("type must be object")
    end
  end

  defp validate_properties_presence!(schema) do
    case schema do
      %{"properties" => properties} when is_map(properties) -> :ok
      %{properties: properties} when is_map(properties) -> :ok
      _ -> raise ArgumentError, errmsg("properties must be a map")
    end
  end

  defp validate_properties_keys!(schema) do
    properties =
      case schema do
        %{"properties" => properties} -> properties
        %{properties: properties} -> properties
      end

    all_atom_keys? = Enum.all?(properties, fn {k, _} -> is_atom(k) end)

    if all_atom_keys? do
      :ok
    else
      raise ArgumentError, errmsg("properties must be defined with atom keys")
    end
  end

  defp validate_required_type!(schema) do
    required =
      case schema do
        %Schema{required: nil} -> []
        %{required: required} -> required
        %{"required" => required} -> required
        _ -> []
      end

    if not is_list(required) do
      raise ArgumentError, errmsg("required must be a list")
    end

    required
  end

  defp validate_required_keys!(list) do
    all_atoms? = Enum.all?(list, &is_atom/1)

    if all_atoms? do
      :ok
    else
      raise ArgumentError, errmsg("required must contain atom keys")
    end
  end

  @doc """
  Returns a list of `{binary_key, atom_key}` tuples for the given schema. The
  list is sorted by keys.

  The schema must be valid against `validate!1/`.
  """
  @spec keycast_pairs(JSV.raw_schema()) :: [{binary, atom}]
  def keycast_pairs(schema) do
    schema
    |> props!()
    |> Enum.map(fn {k, _} when is_atom(k) -> {Atom.to_string(k), k} end)
    |> Enum.sort_by(fn {k, _} -> k end)
  end

  @doc """
  Returns a keyword list of default values for the given schema. The list is
  sorted by keys.

  The schema must be valid against `validate!1/`.
  """
  @spec data_pairs(JSV.raw_schema()) :: keyword()
  def data_pairs(schema) do
    schema
    |> props!()
    |> Enum.map(fn {k, subschema} when is_atom(k) -> {k, default_or_nil(subschema)} end)
    |> Enum.sort_by(fn {k, _} -> k end)
  end

  @doc """
  Returns the `required` property of the schema or an empty list.

  The schema must be valid against `validate!1/`.
  """
  @spec list_required(JSV.raw_schema()) :: [atom()]
  def list_required(schema) do
    list =
      case schema do
        %{"required" => list} -> list
        %Schema{required: nil} -> []
        %{required: list} -> list
        _ -> []
      end

    true = is_list(list)
    list
  end

  defp default_or_nil(schema) do
    case schema do
      %{default: default} -> default
      %{"default" => default} -> default
      _ -> nil
    end
  end

  defp props!(schema) do
    case schema do
      %{properties: properties} -> properties
      %{"properties" => properties} -> properties
    end
  end

  defp errmsg(msg) do
    "defschema schema " <> msg
  end
end
