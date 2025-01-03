defmodule JSV.SchemaTest do
  alias JSV.Schema
  use ExUnit.Case, async: true

  test "provides utility functions" do
    assert %Schema{type: :integer} = Schema.integer()
    assert %Schema{type: :integer, description: "hello"} = Schema.integer(description: "hello")
    # no override of type
    assert %Schema{type: :integer} = Schema.integer(type: :string)
  end

  test "larger example" do
    expected =
      %Schema{
        type: :object,
        properties: %{
          name: %Schema{type: :string, description: "the name of the user"},
          age: %Schema{type: :integer, description: "the age of the user"}
        },
        required: [:name, :age]
      }

    actual =
      %Schema{}
      |> Schema.props(
        name: Schema.string(description: "the name of the user"),
        age: Schema.integer(description: "the age of the user")
      )
      |> Schema.required([:name, :age])

    assert expected == actual
  end
end
