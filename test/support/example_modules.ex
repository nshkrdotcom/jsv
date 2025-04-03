# credo:disable-for-this-file Credo.Check.Readability.Specs
# credo:disable-for-this-file Credo.Check.Readability.ModuleDoc

defmodule MyApp.UserSchema do
  require JSV

  JSV.defschema(%{
    type: :object,
    properties: %{
      name: %{type: :string, default: ""},
      age: %{type: :integer, default: 0}
    }
  })
end

defmodule MyApp.CompanySchema do
  require JSV

  JSV.defschema(%{
    type: :object,
    properties: %{
      name: %{type: :string},
      owner: MyApp.UserSchema
    }
  })
end

defmodule MyApp.LocalResolver do
  require JSV
  use JSV.Resolver.Local, source: __ENV__.file |> Path.dirname() |> Path.join("schemas")
end

defmodule MyApp.Organization do
  defstruct [:name, :id]
end

defmodule MyApp.OrganizationSchema do
  require JSV

  JSV.defschema_for(MyApp.Organization, %{
    type: :object,
    properties: %{
      id: %{type: :string, format: :uuid},
      name: %{type: :string}
    }
  })
end

defmodule CustomSchemaStruct do
  defstruct [:type, :description]
end

defmodule Elixir.ASchemaExportingModule do
  def schema do
    %{}
  end
end

defmodule AModuleWithoutExportedSchema do
  def hello do
    "world"
  end
end
