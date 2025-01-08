defmodule JSV.Resolver.Embedded.Draft202012.Meta.Unevaluated do
  @moduledoc false

  def schema do
    %{
      "$dynamicAnchor" => "meta",
      "$id" => "https://json-schema.org/draft/2020-12/meta/unevaluated",
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "properties" => %{
        "unevaluatedItems" => %{"$dynamicRef" => "#meta"},
        "unevaluatedProperties" => %{"$dynamicRef" => "#meta"}
      },
      "title" => "Unevaluated applicator vocabulary meta-schema",
      "type" => ["object", "boolean"]
    }
  end
end
