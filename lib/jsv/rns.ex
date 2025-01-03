defmodule JSV.RNS do
  @moduledoc """

  A "namespace" for a schema ID or reference. In the JSV library, a namespace
  for a schema represents the document the schema belongs to. When it is an URL,
  it is the scheme, host and path, ignoring the query string and the fragment.

  That is basically a URI but with extra support for URNs (`urn:isbn:1234` is
  represented as `urn://isbn/1234`).
  """

  # TODO maybe do not use the URI module at all and implement a custom parser.

  defstruct [:uri, urn?: false]

  @type t :: %__MODULE__{uri: :root | URI.t(), urn?: boolean}

  @doc """
  Parses the given URL or URN and returns an internal representation of its
  namespace.

  Also accepts `:root` for root schemas without `$id`.
  """
  @spec parse(binary | :root) :: t
  def parse(uri_or_urn)

  def parse("urn:" <> _ = urn) do
    %{host: nil, path: path} = uri = URI.parse(urn)
    [host, path] = String.split(path, ":", parts: 2)
    uri = %URI{uri | host: host, path: "/" <> path}
    %__MODULE__{uri: uri, urn?: true}
  end

  def parse(string) when is_binary(string) do
    %__MODULE__{uri: URI.parse(string)}
  end

  def parse(:root) do
    %__MODULE__{uri: :root}
  end

  @doc """
  Returns a new string namespace by appending a relative child path to a parent
  namespace. If the child is absolute or `:root`, returns the child.
  """
  @spec derive(binary | :root, binary | :root) :: {:ok, binary | :roo} | {:error, term}
  def derive(parent, child) do
    parent_rns = parse(parent)
    child_rns = parse(child)

    with {:ok, merged} <- merge(parent_rns, child_rns) do
      {:ok, to_ns(merged)}
    end
  end

  defp merge(%{uri: :root} = parent, %{uri: %{host: nil, path: nil}}) do
    {:ok, parent}
  end

  defp merge(%{uri: :root}, %{uri: %{host: host}} = child) when is_binary(host) do
    {:ok, child}
  end

  defp merge(%{uri: :root}, %{uri: child}) do
    {:error, {:invalid_child_ns, URI.to_string(child)}}
  end

  defp merge(%{uri: parent_uri, urn?: urn?}, %{uri: child_uri}) do
    {:ok, %__MODULE__{uri: URI.merge(parent_uri, child_uri), urn?: urn?}}
  end

  @doc """
  Returns the string value of the namespace, or `:root`.
  """
  @spec to_ns(t) :: binary | :root
  def to_ns(%{uri: :root}) do
    :root
  end

  def to_ns(%{uri: uri, urn?: true}) do
    %{host: host, path: "/" <> path} = uri
    uri = %URI{uri | host: nil, path: host <> ":" <> path}
    to_string_no_fragment(uri)
  end

  def to_ns(%{uri: uri}) do
    to_string_no_fragment(uri)
  end

  defp to_string_no_fragment(%URI{} = uri) do
    String.Chars.URI.to_string(Map.put(uri, :fragment, nil))
  end
end
