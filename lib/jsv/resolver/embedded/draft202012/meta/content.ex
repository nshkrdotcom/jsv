defmodule JSV.Resolver.Embedded.Draft202012.Meta.Content do
  @moduledoc false

  def schema do
    %{
      "$dynamicAnchor" => "meta",
      "$id" => "https://json-schema.org/draft/2020-12/meta/content",
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "properties" => %{
        "contentEncoding" => %{"type" => "string"},
        "contentMediaType" => %{"type" => "string"},
        "contentSchema" => %{"$dynamicRef" => "#meta"}
      },
      "title" => "Content vocabulary meta-schema",
      "type" => ["object", "boolean"]
    }
  end
end
