defmodule JSV.Helpers.TraverseTest do
  alias JSV.Helpers.Traverse
  use ExUnit.Case, async: true

  doctest JSV.Helpers.Traverse

  defmodule SomeStruct do
    defstruct enum: []
  end

  describe "postwalk traversal" do
    test "sees children before" do
      # * postwalk is called on the children before the parents.
      # * whenever we see the integer value we increment it
      # * when the parent is called, it should be called with the incremented
      #   value
      #
      # Here we match directly of what is expected.
      data = %{"parent" => %{"child" => 0}}

      assert %{"parent" => %{"child" => 3}} =
               Traverse.postwalk(data, fn
                 {:val, 0} -> 1
                 {:key, k} -> k
                 {:val, %{"child" => 1}} -> %{"child" => 2}
                 {:val, %{"parent" => %{"child" => 2}}} -> %{"parent" => %{"child" => 3}}
               end)
    end

    test "keys added to maps are not traversed" do
      data = %{"parent" => %{"child" => 0}}

      assert %{"parent" => %{"child" => 1, "other_child" => 0}} =
               Traverse.postwalk(data, fn
                 {:val, 0} -> 1
                 {:key, k} -> k
                 # No map with an "other_child" key is given to the callback as
                 # the root data, only when nested in the map that has the
                 # "parent" key.
                 {:val, %{"child" => 1} = parent} when map_size(parent) == 1 -> Map.put(parent, "other_child", 0)
                 {:val, %{"parent" => %{"child" => 1, "other_child" => 0}} = map} -> map
               end)
    end

    test "supports lists" do
      data = [1, 2, [3, 4]]

      assert [10, 20, [30, 40]] =
               Traverse.postwalk(data, fn
                 {:val, n} when is_integer(n) -> n * 10
                 {:val, [30, 40] = v} -> v
                 {:val, [10, 20, [30, 40]] = v} -> v
               end)
    end

    test "supports tuples" do
      data = {1, 2, {3, 4}}

      assert {10, 20, {30, 40}} =
               Traverse.postwalk(data, fn
                 {:val, n} when is_integer(n) -> n * 10
                 {:val, {30, 40} = v} -> v
                 {:val, {10, 20, {30, 40}} = v} -> v
               end)
    end

    test "special handling of structs" do
      data = %SomeStruct{enum: [1, 2, 3]}

      # By default, sub values of struct are not called
      assert %SomeStruct{enum: [1, 2, 3]} ==
               Traverse.postwalk(data, fn
                 # This will not be called
                 {:val, _} -> raise "called with val"
                 # And so the struct in unchanged on post since we do not call the continuation
                 {:struct, %SomeStruct{enum: [1, 2, 3]} = s, _} -> s
               end)

      # But the tool provides a continuation that will traverse the given structure

      assert %{enum: [10, 20, 30]} ==
               Traverse.postwalk(data, fn
                 # This will now be called
                 {:val, n} when is_integer(n) ->
                   n * 10

                 # The list is still passed post-traversal
                 {:val, [10, 20, 30] = v} ->
                   v

                 # Keys are passed since we call Map.from_struct/1
                 {:key, :enum} ->
                   :enum

                 # The map-from-struct itself should not be passed as it represents the struct
                 {:val, %{enum: _}} ->
                   raise "should not be called"

                 # But it is not called before the struct is given to the
                 # callback.
                 {:struct, %SomeStruct{enum: [1, 2, 3]} = s, cont} ->
                   {map, nil} = cont.(Map.from_struct(s), nil)
                   map
               end)
    end

    test "keys are not traversed" do
      data = %{{1, 2} => "position"}

      assert %{{1, 2} => "position-2"} =
               Traverse.postwalk(data, fn
                 {:val, "position"} -> "position-1"
                 {:key, {1, 2} = k} -> k
                 {:val, %{{1, 2} => "position-1"}} -> %{{1, 2} => "position-2"}
               end)
    end

    test "catchall clause can just return the second tuple element" do
      original_data = %{
        :a => [~c"hello", {1, 3}],
        :x => %Inspect.Opts{},
        %{x: :y, z: %{z: 1}} => %{nested: [a: 1, b: {:c}] ++ [{}, self()]}
      }

      traversed_data = Traverse.postwalk(original_data, &elem(&1, 1))

      assert original_data == traversed_data
    end
  end

  describe "prewalk traversal" do
    test "sees parents before children" do
      # * prewalk is called on the parents before the children.
      # * whenever we see a map, we add a key to it
      # * when the child is called, it should be called with the modified parent
      data = %{"parent" => %{"child" => true}}

      assert %{
               "parent" => %{
                 "child" => true,
                 "other_child" => true
               },
               "other_parent" => true
             } =
               Traverse.prewalk(data, fn
                 {:val, %{"parent" => _} = map} ->
                   refute is_map_key(map, "other_parent")
                   Map.put(map, "other_parent", true)

                 {:val, %{"child" => true} = map} ->
                   refute is_map_key(map, "other_child")
                   Map.put(map, "other_child", true)

                 {:val, true} ->
                   true

                 {:key, key} ->
                   key
               end)
    end

    test "supports lists" do
      data = [1, 2, [3, 4]]

      # * whole list is called as-is
      # * [3,4] list is called without any atom inside, then we add it.
      # * the atom should be given to the function
      # * no list should be passed with a *10 integer

      assert [10, 20, [:changed, 30, 40]] =
               Traverse.prewalk(data, fn
                 {:val, [1, 2, [3, 4]] = full} -> full
                 {:val, [3, 4]} -> [:pre, 3, 4]
                 {:val, n} when is_integer(n) -> n * 10
                 {:val, :pre} -> :changed
               end)
    end

    test "supports tuples" do
      data = {1, 2, {3, 4}}

      # same as the list test

      assert {10, 20, {:changed, 30, 40}} =
               Traverse.prewalk(data, fn
                 {:val, {1, 2, {3, 4}} = full} -> full
                 {:val, {3, 4}} -> {:pre, 3, 4}
                 {:val, n} when is_integer(n) -> n * 10
                 {:val, :pre} -> :changed
               end)
    end

    test "no special handling of structs" do
      # contraty to postwalk, it is OK to dig into a struct since the prewalk
      # callback can return something else if it does not want structs to be
      # traversed.
      #
      # But structs are still given with a special :struct tagged tuple to have
      # resemblence with postwalk. Only it does not contain a 3d tuple element
      # with a continuation.

      data = %SomeStruct{enum: [1, 2, %{sub: 3}]}

      # When we return the struct itself, it will be iterated, but the keys will
      # not be passed to the callback, as we are not allowed to change keys from
      # a struct.
      assert %SomeStruct{enum: [:pre_1, 10, 20, %{sub: 40}]} ==
               Traverse.prewalk(data, fn
                 {:struct, %SomeStruct{} = s} -> s
                 {:val, list} when is_list(list) -> [:pre | list]
                 {:val, n} when is_integer(n) -> n * 10
                 {:val, %{sub: 3}} -> %{sub: 4}
                 {:val, :pre} -> :pre_1
                 # key :enum will not be given
                 {:key, :sub} -> :sub
               end)
    end

    test "keys are not traversed in prewalk" do
      data = %{{1, 2} => "position"}

      assert %{{1, 2} => "POSITION"} =
               Traverse.prewalk(data, fn
                 {:val, %{{1, 2} => _} = map} -> map
                 {:val, "position"} -> "POSITION"
                 {:key, {1, 2} = k} -> k
               end)
    end

    test "catchall clause can just return the second tuple element" do
      original_data = %{
        :a => [~c"hello", {1, 3}],
        :x => %Inspect.Opts{},
        %{x: :y, z: %{z: 1}} => %{nested: [a: 1, b: {:c}] ++ [{}, self()]}
      }

      traversed_data = Traverse.prewalk(original_data, &elem(&1, 1))

      assert original_data == traversed_data
    end
  end
end
