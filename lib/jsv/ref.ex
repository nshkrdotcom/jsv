defmodule JSV.Ref do
  alias __MODULE__
  alias JSV.RNS

  @moduledoc """
  Representation of a JSON Schema reference (`$ref` or `$dynamicRef`).
  """

  defstruct ns: nil, kind: nil, arg: nil, dynamic?: false

  @type t :: %__MODULE__{}
  @type ns :: binary | :root

  @doc """
  Creates a new reference from an URL, relative to the given namespace.

  If the URL is absolute and its namespace is different from the given
  namespace, returns an absolute URL.
  """
  @spec parse(binary, ns) :: {:ok, t} | {:error, term}
  def parse(url, current_ns) do
    do_parse(url, current_ns, false)
  end

  @doc """
  Bang function for `parse/2`.
  """
  @spec parse!(binary, ns) :: t
  def parse!(url, current_ns) do
    case parse(url, current_ns) do
      {:ok, ref} -> ref
      {:error, reason} -> raise ArgumentError, "could not parse $ref: #{inspect(url)}, got: #{inspect(reason)}"
    end
  end

  @doc """
  Like `parse/2` but flags the reference as dynamic.
  """
  @spec parse_dynamic(binary, ns) :: {:ok, t} | {:error, term}
  def parse_dynamic(url, current_ns) do
    do_parse(url, current_ns, true)
  end

  defp do_parse(url, current_ns, dynamic?) do
    uri = URI.parse(url)
    {kind, arg} = parse_fragment(uri.fragment)

    dynamic? = dynamic? and kind == :anchor

    with {:ok, ns} <- RNS.derive(current_ns, url) do
      {:ok, %Ref{ns: ns, kind: kind, arg: arg, dynamic?: dynamic?}}
    end
  end

  defp parse_fragment(nil) do
    {:top, []}
  end

  defp parse_fragment("") do
    {:top, []}
  end

  defp parse_fragment("/") do
    {:top, []}
  end

  defp parse_fragment("/" <> path) do
    {:pointer, parse_pointer(path)}
  end

  defp parse_fragment(anchor) do
    {:anchor, anchor}
  end

  defp parse_pointer(raw_docpath) do
    raw_docpath |> String.split("/") |> Enum.map(&parse_pointer_segment/1)
  end

  defp parse_pointer_segment(string) do
    case Integer.parse(string) do
      {int, ""} -> int
      _ -> unescape_json_pointer(string)
    end
  end

  defp unescape_json_pointer(str) do
    str
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
    |> URI.decode()
  end

  @doc """
  Encodes the given string as a JSON representation of a JSON pointer, that is
  with `~` as `~0` and `/` as `~1`.
  """
  @spec escape_json_pointer(binary | iodata()) :: binary
  def escape_json_pointer(str) when is_binary(str) do
    str
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
  end

  def escape_json_pointer(str) do
    str
    |> IO.iodata_to_binary()
    |> escape_json_pointer()
  end
end
