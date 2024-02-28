defmodule JSV.Key do
  alias JSV.Ref

  def of(binary) when is_binary(binary) do
    binary
  end

  def of(:root) do
    :root
  end

  def of(%Ref{} = ref) do
    of_ref(ref)
  end

  def of({:dynamic_anchor, _, _} = key) do
    key
  end

  defp of_ref(%{dynamic?: true, ns: ns, kind: :anchor} = ref) do
    %{arg: arg} = ref
    for_dynamic_anchor(ns, arg)
  end

  defp of_ref(%{dynamic?: false} = ref) do
    %Ref{kind: kind, ns: ns, arg: arg} = ref

    case kind do
      :top -> ns
      :pointer -> for_pointer(ns, arg)
      :anchor -> for_anchor(ns, arg)
    end
  end

  def for_pointer(ns, arg) do
    {:pointer, ns, arg}
  end

  def for_anchor(ns, arg) do
    {:anchor, ns, arg}
  end

  def for_dynamic_anchor(ns, arg) do
    {:dynamic_anchor, ns, arg}
  end

  def namespace_of(binary) when is_binary(binary) do
    binary
  end

  def namespace_of(:root) do
    :root
  end

  def namespace_of({:anchor, ns, _}) do
    ns
  end

  def namespace_of({:dynamic_anchor, ns, _}) do
    ns
  end

  def namespace_of({:pointer, ns, _}) do
    ns
  end

  def to_iodata(bin) when is_binary(bin) do
    bin
  end

  def to_iodata(:root) do
    [""]
  end

  def to_iodata({:pointer, ns, [_ | _] = path}) do
    [ns_to_iodata(ns), "/" | Enum.map_intersperse(path, "/", &to_iodata_segment/1)]
  end

  def to_iodata({:dynamic_anchor, ns, anchor}) do
    [ns_to_iodata(ns), "/", anchor]
  end

  def to_iodata({:anchor, ns, anchor}) do
    [ns_to_iodata(ns), "/", anchor]
  end

  defp ns_to_iodata(:root) do
    ""
  end

  defp ns_to_iodata(bin) when is_binary(bin) do
    bin
  end

  defp to_iodata_segment(bin) when is_binary(bin) do
    bin
  end

  defp to_iodata_segment(n) when is_integer(n) do
    Integer.to_string(n)
  end
end
