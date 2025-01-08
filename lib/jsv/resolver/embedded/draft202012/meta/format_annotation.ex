defmodule JSV.Resolver.Embedded.Draft202012.Meta.FormatAnnotation do
  @moduledoc false

  @spec schema :: map
  def schema do
    %{
      "$dynamicAnchor" => "meta",
      "$id" => "https://json-schema.org/draft/2020-12/meta/format-annotation",
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "properties" => %{"format" => %{"type" => "string"}},
      "title" => "Format vocabulary meta-schema for annotation results",
      "type" => ["object", "boolean"]
    }
  end
end
