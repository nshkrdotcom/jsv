defmodule JSV.RefTest do
  alias JSV.Ref
  use ExUnit.Case, async: true

  doctest JSV.Ref

  describe "parse/2" do
    test "parses a reference to the root" do
      {:ok, ref} = Ref.parse("", :root)

      assert %Ref{
               ns: :root,
               kind: :top,
               arg: [],
               dynamic?: false
             } = ref
    end

    test "parses a reference with just a fragment" do
      {:ok, ref} = Ref.parse("#/properties/name", :root)

      assert %Ref{
               ns: :root,
               kind: :pointer,
               arg: ["properties", "name"],
               dynamic?: false
             } = ref
    end

    test "parses a reference with an anchor" do
      {:ok, ref} = Ref.parse("#foo", :root)

      assert %Ref{
               ns: :root,
               kind: :anchor,
               arg: "foo",
               dynamic?: false
             } = ref
    end

    test "parses references with a different namespace" do
      {:ok, ref} = Ref.parse("http://example.com/schema.json", :root)

      assert %Ref{
               ns: "http://example.com/schema.json",
               kind: :top,
               arg: [],
               dynamic?: false
             } = ref
    end

    test "parses references with a different namespace and fragment" do
      {:ok, ref} = Ref.parse("http://example.com/schema.json#/properties/name", :root)

      assert %Ref{
               ns: "http://example.com/schema.json",
               kind: :pointer,
               arg: ["properties", "name"],
               dynamic?: false
             } = ref
    end

    test "handles relative paths" do
      current_ns = "http://example.com/schema/"
      {:ok, ref} = Ref.parse("user.json", current_ns)

      assert %Ref{
               ns: "http://example.com/schema/user.json",
               kind: :top,
               arg: [],
               dynamic?: false
             } = ref
    end
  end

  describe "parse_dynamic/2" do
    test "parses a dynamic reference" do
      {:ok, ref} = Ref.parse_dynamic("#foo", :root)

      assert %Ref{
               ns: :root,
               kind: :anchor,
               arg: "foo",
               dynamic?: true
             } = ref
    end

    test "only sets dynamic flag for anchors" do
      {:ok, ref} = Ref.parse_dynamic("#/properties/name", :root)

      assert %Ref{
               ns: :root,
               kind: :pointer,
               arg: ["properties", "name"],
               dynamic?: false
             } = ref
    end
  end

  describe "forced creation of pointer" do
    test "creates a pointer reference from string segments" do
      assert %Ref{
               ns: :root,
               kind: :pointer,
               arg: ["properties", "name"],
               dynamic?: false
             } = Ref.pointer!(["properties", "name"], :root)
    end

    test "creates a pointer reference from mixed string and integer segments" do
      assert %Ref{
               ns: :root,
               kind: :pointer,
               arg: ["items", 0, "name"],
               dynamic?: false
             } = Ref.pointer!(["items", 0, "name"], :root)
    end

    test "creates a pointer reference from empty segments list" do
      assert %Ref{
               ns: :root,
               kind: :pointer,
               arg: [],
               dynamic?: false
             } = Ref.pointer!([], :root)
    end

    test "creates a pointer reference with a custom namespace" do
      assert %Ref{
               ns: "http://example.com/schema.json",
               kind: :pointer,
               arg: ["properties", "user"],
               dynamic?: false
             } = Ref.pointer!(["properties", "user"], "http://example.com/schema.json")
    end
  end

  describe "escape_json_pointer/1" do
    test "escapes ~ as ~0" do
      assert "property~0name" == Ref.escape_json_pointer("property~name")
    end

    test "escapes / as ~1" do
      assert "property~1name" == Ref.escape_json_pointer("property/name")
    end

    test "escapes both ~ and / characters" do
      assert "~0~1property~1~0name~1" == Ref.escape_json_pointer("~/property/~name/")
    end

    test "handles strings without special characters" do
      assert "normal" == Ref.escape_json_pointer("normal")
    end
  end

  describe "JSON pointer parsing" do
    test "parses / as root" do
      {:ok, ref} = Ref.parse("#/", :root)

      assert %Ref{
               ns: :root,
               kind: :top,
               arg: [],
               dynamic?: false
             } = ref
    end

    test "parses numeric segments as integers" do
      {:ok, ref} = Ref.parse("#/items/0", :root)

      assert %Ref{
               ns: :root,
               kind: :pointer,
               arg: ["items", 0],
               dynamic?: false
             } = ref
    end

    test "handles URI encoded characters" do
      {:ok, ref} = Ref.parse("#/properties/user%20name", :root)

      assert %Ref{
               ns: :root,
               kind: :pointer,
               arg: ["properties", "user name"],
               dynamic?: false
             } = ref
    end

    test "decodes escaped sequences in JSON pointers" do
      {:ok, ref} = Ref.parse("#/properties/path~1name~0tilde", :root)

      assert %Ref{
               ns: :root,
               kind: :pointer,
               arg: ["properties", "path/name~tilde"],
               dynamic?: false
             } = ref
    end
  end
end
