defmodule MyApp.UserSchema do
  require JSV
  @moduledoc false

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
  @moduledoc false

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

  @moduledoc false
end
