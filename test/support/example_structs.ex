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
