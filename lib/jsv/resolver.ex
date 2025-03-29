defmodule JSV.Resolver do
  alias JSV.Helpers.EnumExt
  alias JSV.Key
  alias JSV.Ref
  alias JSV.RNS
  alias JSV.Vocabulary

  @moduledoc """
  A behaviour describing the implementation of a [guides/build/custom resolver.
  Resolves remote resources when building a JSON schema.
  """

  defmodule Resolved do
    @moduledoc """
    Metadata gathered from a remote schema or a sub-schema.
    """

    # TODO drop parent_ns once we do not support draft-7
    @enforce_keys [:raw, :meta, :vocabularies, :ns, :parent_ns, :rev_path]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            raw: term,
            meta: binary,
            vocabularies: term,
            ns: binary,
            parent_ns: binary
          }
  end

  defmodule Descriptor do
    @enforce_keys [:raw, :meta, :aliases, :ns, :parent_ns, :rev_path]
    defstruct @enforce_keys
    @moduledoc false
  end

  @doc """
  Receives an URI and the options passed in the resolver tuple to `JSV.build/2`
  and returns a result tuple for a raw JSON schema map.

  Returning boolean schemas from resolvers is not supported. You may wrap the
  boolean value in a `$defs` or any other pointer as a workaround.
  """
  @callback resolve(uri :: String.t(), opts :: term) :: {:ok, map} | {:error, term}

  @draft_202012_vocabulary %{
    "https://json-schema.org/draft/2020-12/vocab/core" => Vocabulary.V202012.Core,
    "https://json-schema.org/draft/2020-12/vocab/validation" => Vocabulary.V202012.Validation,
    "https://json-schema.org/draft/2020-12/vocab/applicator" => Vocabulary.V202012.Applicator,
    "https://json-schema.org/draft/2020-12/vocab/content" => Vocabulary.V202012.Content,
    "https://json-schema.org/draft/2020-12/vocab/format-annotation" => Vocabulary.V202012.Format,
    "https://json-schema.org/draft/2020-12/vocab/format-assertion" => {Vocabulary.V202012.Format, assert: true},
    "https://json-schema.org/draft/2020-12/vocab/meta-data" => Vocabulary.V202012.MetaData,
    "https://json-schema.org/draft/2020-12/vocab/unevaluated" => Vocabulary.V202012.Unevaluated
  }

  @draft7_vocabulary %{
    "https://json-schema.org/draft-07/--fallback--vocab/core" => Vocabulary.V7.Core,
    "https://json-schema.org/draft-07/--fallback--vocab/validation" => Vocabulary.V7.Validation,
    "https://json-schema.org/draft-07/--fallback--vocab/applicator" => Vocabulary.V7.Applicator,
    "https://json-schema.org/draft-07/--fallback--vocab/content" => Vocabulary.V7.Content,
    "https://json-schema.org/draft-07/--fallback--vocab/format-annotation" => Vocabulary.V7.Format,
    "https://json-schema.org/draft-07/--fallback--vocab/format-assertion" => {Vocabulary.V7.Format, assert: true},
    "https://json-schema.org/draft-07/--fallback--vocab/meta-data" => Vocabulary.V7.MetaData
  }

  @draft7_normalized_identifier "http://json-schema.org/draft-07/schema"
  @draft7_vocabulary_keyword_fallback Map.new(@draft7_vocabulary, fn {k, _mod} -> {k, true} end)

  @vocabulary %{} |> Map.merge(@draft_202012_vocabulary) |> Map.merge(@draft7_vocabulary)

  @derive {Inspect, except: [:fetch_cache]}
  defstruct chain: [{UnknownResolver, []}],
            default_meta: nil,
            # fetch_cache is a local cache for the resolver instance. Actual
            # caching of remote resources should be done in each resolver
            # implementation.
            fetch_cache: %{},
            resolved: %{}

  @opaque t :: %__MODULE__{}
  @type resolvable :: Key.ns() | Key.pointer() | Ref.t()

  @doc """
  Returns a new resolver, with the given behaviour implementations, and a
  default meta-schema URL to use with schemas that do not declare a `$schema`
  property.
  """
  @spec chain_of([{module, term}], binary) :: t
  def chain_of([_ | _] = resolvers, default_meta) do
    %__MODULE__{chain: resolvers, default_meta: default_meta}
  end

  @doc """
  Adds the given raw schema as a pre-resolved schema, using the `:root`
  namespace if the schema does not contain a `$id` property.
  """
  @spec resolve_root(t, JSV.raw_schema()) :: {:ok, :root | binary, t} | {:error, term}
  def resolve_root(rsv, raw_schema) when is_map(raw_schema) do
    # Bootstrap of the recursive resolving of schemas, metaschemas and
    # anchors/$ids. We just need to set the :root value in the context as the
    # $id (or `:root` atom if not set) of the top schema.

    root_ns = Map.get(raw_schema, "$id", :root)

    # rsv = %__MODULE__{rsv | root: root_ns}
    ^root_ns = Key.of(root_ns)

    with {:ok, rsv} <- resolve(rsv, {:prefetched, root_ns, raw_schema}) do
      {:ok, root_ns, rsv}
    end
  end

  @doc """
  Fetches the remote resource into the internal resolver cache and returns a new
  resolver with that updated cache.
  """
  @spec resolve(t, resolvable | {:prefetched, term, term}) :: {:ok, t} | {:error, term}
  def resolve(rsv, resolvable) do
    case check_resolved(rsv, resolvable) do
      :unresolved -> do_resolve(rsv, resolvable)
      :already_resolved -> {:ok, rsv}
    end
  end

  defp do_resolve(rsv, resolvable) do
    with {:ok, raw_schema, rsv} <- ensure_fetched(rsv, resolvable),
         {:ok, identified_schemas} <- scan_schema(raw_schema, external_id(resolvable), rsv.default_meta),
         {:ok, cache_entries} <- create_cache_entries(identified_schemas),
         {:ok, rsv} <- insert_cache_entries(rsv, cache_entries) do
      resolve_meta_loop(rsv, metas_of(cache_entries))
    else
      {:error, _} = err -> err
    end
  end

  defp metas_of(cache_entries) do
    cache_entries
    |> Enum.flat_map(fn
      {_, {:alias_of, _}} -> []
      {_, %{meta: meta}} -> [meta]
    end)
    |> Enum.uniq()
  end

  defp resolve_meta_loop(rsv, []) do
    {:ok, rsv}
  end

  defp resolve_meta_loop(rsv, [nil | tail]) do
    resolve_meta_loop(rsv, tail)
  end

  defp resolve_meta_loop(rsv, [meta | tail]) when is_binary(meta) do
    with :unresolved <- check_resolved(rsv, {:meta, meta}),
         {:ok, raw_schema, rsv} <- ensure_fetched(rsv, meta),
         {:ok, cache_entry} <- create_meta_entry(raw_schema, meta),
         {:ok, rsv} <- insert_cache_entries(rsv, [{{:meta, meta}, cache_entry}]) do
      resolve_meta_loop(rsv, [cache_entry.meta | tail])
    else
      :already_resolved -> resolve_meta_loop(rsv, tail)
      {:error, _} = err -> err
    end
  end

  defp check_resolved(rsv, {:prefetched, id, _}) do
    check_resolved(rsv, id)
  end

  defp check_resolved(rsv, id) when is_binary(id) or :root == id do
    case rsv do
      %{resolved: %{^id => _}} -> :already_resolved
      _ -> :unresolved
    end
  end

  defp check_resolved(rsv, {:meta, id}) when is_binary(id) do
    case rsv do
      %{resolved: %{{:meta, ^id} => _}} -> :already_resolved
      _ -> :unresolved
    end
  end

  defp check_resolved(rsv, %Ref{ns: ns}) do
    check_resolved(rsv, ns)
  end

  # Extract all $ids and achors. We receive the top schema
  defp scan_schema(top_schema, external_id, default_meta) when not is_nil(external_id) do
    {id, anchor, dynamic_anchor} = extract_keys(top_schema)

    # For self references that target "#" or "#some/path" in the document, when
    # the document does not have an id, we will force it. This is for the root
    # document only.

    ns =
      case id do
        nil -> external_id
        _ -> id
      end

    nss = [id, external_id] |> Enum.reject(&is_nil/1) |> Enum.uniq()

    # Anchor needs to be resolved from the $id or the external ID (an URL) if
    # set.
    anchors =
      case anchor do
        nil -> []
        _ -> Enum.map(nss, &Key.for_anchor(&1, anchor))
      end

    dynamic_anchors =
      case dynamic_anchor do
        # a dynamic anchor is also adressable as a regular anchor for the given namespace
        nil -> []
        _ -> Enum.flat_map(nss, &[Key.for_dynamic_anchor(&1, dynamic_anchor), Key.for_anchor(&1, dynamic_anchor)])
      end

    # The schema will be findable by its $id or external id.
    id_aliases = nss
    aliases = id_aliases ++ anchors ++ dynamic_anchors

    # If no metaschema is defined we will use the default draft as a fallback
    meta = normalize_meta(Map.get(top_schema, "$schema", default_meta))

    top_descriptor = %Descriptor{
      raw: top_schema,
      meta: meta,
      aliases: aliases,
      ns: ns,
      parent_ns: nil,
      rev_path: [external_id]
    }

    acc = [top_descriptor]

    scan_map_values(top_schema, id, nss, meta, [ns], acc)
  end

  defp scan_subschema(raw_schema, ns, nss, meta, path, acc) when is_map(raw_schema) do
    # If the subschema defines an id, we will discard the current namespaces, as
    # the sibling or nested anchors will now only relate to this id

    parent_ns = ns

    {id, anchors, dynamic_anchor} =
      case extract_keys(raw_schema) do
        # ID that is a fragment is replaced as an anchor
        {"#" <> frag_id, anchor, dynamic_anchor} -> {nil, [frag_id | List.wrap(anchor)], dynamic_anchor}
        {id, anchor, dynamic_anchor} -> {id, List.wrap(anchor), dynamic_anchor}
      end

    {id_aliases, ns, nss} =
      with true <- is_binary(id),
           {:ok, full_id} <- merge_id(ns, id) do
        {[full_id], full_id, [full_id]}
      else
        _ -> {[], ns, nss}
      end

    anchors =
      for new_ns <- nss, a <- anchors do
        Key.for_anchor(new_ns, a)
      end

    dynamic_anchors =
      case dynamic_anchor do
        nil -> []
        # a dynamic anchor is also adressable as a regular anchor for the given namespace
        da -> Enum.flat_map(nss, &[Key.for_dynamic_anchor(&1, da), Key.for_anchor(&1, da)])
      end

    # We do not check for the meta $schema is subschemas, we only add the
    # parent_one to the descriptor.

    acc =
      case(id_aliases ++ anchors ++ dynamic_anchors) do
        [] ->
          acc

        aliases ->
          descriptor =
            %Descriptor{
              raw: raw_schema,
              meta: meta,
              aliases: aliases,
              ns: ns,
              parent_ns: parent_ns,
              rev_path: path
            }

          [descriptor | acc]
      end

    scan_map_values(raw_schema, ns, nss, meta, path, acc)
  end

  defp scan_subschema(scalar, _parent_id, _nss, _meta, _path, acc)
       when is_binary(scalar)
       when is_atom(scalar)
       when is_number(scalar) do
    {:ok, acc}
  end

  defp scan_subschema(list, parent_id, nss, meta, path, acc) when is_list(list) do
    list
    |> Enum.with_index()
    |> EnumExt.reduce_ok(acc, fn {item, index}, acc ->
      scan_subschema(item, parent_id, nss, meta, [index | path], acc)
    end)
  end

  defp extract_keys(schema) do
    id =
      case Map.fetch(schema, "$id") do
        {:ok, id} -> id
        :error -> nil
      end

    anchor =
      case Map.fetch(schema, "$anchor") do
        {:ok, anchor} -> anchor
        :error -> nil
      end

    dynamic_anchor =
      case Map.fetch(schema, "$dynamicAnchor") do
        {:ok, dynamic_anchor} -> dynamic_anchor
        :error -> nil
      end

    {id, anchor, dynamic_anchor}
  end

  defp scan_map_values(schema, parent_id, nss, meta, path, acc) do
    EnumExt.reduce_ok(schema, acc, fn
      {"properties", props}, acc when is_map(props) ->
        scan_map_values(props, parent_id, nss, meta, ["properties" | path], acc)

      {"properties", props}, _ ->
        raise "invalid properties: #{inspect(props)}"

      {ignored, _}, _ when ignored in ["enum", "const"] ->
        {:ok, acc}

      {k, v}, acc ->
        scan_subschema(v, parent_id, nss, meta, [k | path], acc)
    end)
  end

  defp create_cache_entries(identified_schemas) do
    {:ok, Enum.flat_map(identified_schemas, &to_cache_entries/1)}
  end

  defp to_cache_entries(descriptor) do
    %Descriptor{aliases: aliases, meta: meta, raw: raw, ns: ns, parent_ns: parent_ns, rev_path: rev_path} = descriptor

    resolved =
      %Resolved{meta: meta, raw: raw, ns: ns, parent_ns: parent_ns, vocabularies: nil, rev_path: rev_path}

    case aliases do
      [single] -> [{single, resolved}]
      [first | aliases] -> [{first, resolved} | Enum.map(aliases, &{&1, {:alias_of, first}})]
    end
  end

  defp insert_cache_entries(rsv, entries) do
    %{resolved: cache} = rsv

    cache_result =
      EnumExt.reduce_ok(entries, cache, fn {k, resolved}, cache ->
        case cache do
          %{^k => existing} ->
            # Allow a duplicate resolution that is the exact same value as the
            # preexisting copy. This allows a root schema with an $id to reference
            # itself with an external id such as `jsv:module:MODULE`.
            check_duplicated_cache_entry(k, resolved, existing, cache)

          _ ->
            {:ok, Map.put(cache, k, resolved)}
        end
      end)

    with {:ok, cache} <- cache_result do
      {:ok, %__MODULE__{rsv | resolved: cache}}
    end
  end

  defp check_duplicated_cache_entry(k, resolved, existing, cache) do
    case {resolved, existing} do
      {%Resolved{raw: same}, %Resolved{raw: same}} -> {:ok, cache}
      _ -> {:error, {:duplicate_resolution, k}}
    end
  end

  defp create_meta_entry(raw_schema, ext_id) when not is_struct(raw_schema) do
    vocabulary = Map.get(raw_schema, "$vocabulary")

    # Meta entries are only identified by they external URL so their :ns and
    # :raw value should not be used anywhere.

    case load_vocabularies(vocabulary, ext_id) do
      {:ok, vocabularies} ->
        {:ok,
         %Resolved{
           vocabularies: vocabularies,
           meta: nil,
           ns: :__meta__,
           parent_ns: nil,
           raw: :__meta__,
           rev_path: [ext_id]
         }}

      {:error, _} = err ->
        err
    end
  end

  defp external_id({:prefetched, ext_id, _}) do
    ext_id
  end

  defp external_id(%Ref{ns: ns}) do
    ns
  end

  defp ensure_fetched(rsv, {:prefetched, _, raw_schema}) do
    {:ok, raw_schema, rsv}
  end

  defp ensure_fetched(rsv, fetchable) do
    with :unfetched <- check_fetched(rsv, fetchable),
         {:ok, ext_id, raw_schema} <- fetch_raw_schema(rsv, fetchable) do
      %{fetch_cache: cache} = rsv
      {:ok, raw_schema, %__MODULE__{rsv | fetch_cache: put_cache(cache, ext_id, raw_schema)}}
    else
      {:already_fetched, raw_schema} -> {:ok, raw_schema, rsv}
      {:error, _} = err -> err
    end
  end

  defp put_cache(cache, ext_id, raw_schema) do
    Map.put(cache, ext_id, raw_schema)
  end

  defp check_fetched(rsv, %Ref{ns: ns}) do
    check_fetched(rsv, ns)
  end

  defp check_fetched(rsv, id) when is_binary(id) do
    case rsv do
      %{fetch_cache: %{^id => fetched}} -> {:already_fetched, fetched}
      _ -> :unfetched
    end
  end

  @spec fetch_raw_schema(t, binary | {:meta, binary} | Ref.t()) :: {:ok, binary, JSV.raw_schema()} | {:error, term}
  defp fetch_raw_schema(rsv, {:meta, url}) do
    fetch_raw_schema(rsv, url)
  end

  defp fetch_raw_schema(rsv, url) when is_binary(url) do
    call_chain(rsv.chain, url)
  end

  defp fetch_raw_schema(rsv, %Ref{ns: ns}) do
    fetch_raw_schema(rsv, ns)
  end

  defp call_chain(chain, url) do
    call_chain(chain, url, _err_acc = [])
  end

  defp call_chain([{module, opts} | chain], url, err_acc) do
    case module.resolve(url, opts) do
      {:ok, resolved} when is_map(resolved) ->
        {:ok, url, normalize_resolved(resolved)}

      {:error, reason} ->
        call_chain(chain, url, [{module, reason} | err_acc])

      other ->
        raise "invalid return from #{inspect(module)}.resolve/2, expected {:ok, map} or {:error, reason}, got: #{inspect(other)}"
    end
  end

  defp call_chain([], _url, err_acc) do
    {:error, {:resolver_error, :lists.reverse(err_acc)}}
  end

  defp normalize_resolved(map) when is_map(map) do
    JSV.Schema.normalize(map)
  end

  defp merge_id(nil, child) do
    RNS.derive(child, "")
  end

  defp merge_id(parent, child) do
    RNS.derive(parent, child)
  end

  # Removes the fragment from the given URL. Accepts nil values
  defp normalize_meta(nil) do
    nil
  end

  defp normalize_meta(meta) do
    case URI.parse(meta) do
      %{fragment: nil} -> meta
      uri -> URI.to_string(%{uri | fragment: nil})
    end
  end

  defp load_vocabularies(map, meta_id) do
    with {:ok, vocabs} <- do_load_vocabularies(map, meta_id) do
      {:ok, sort_vocabularies([Vocabulary.Internal | vocabs])}
    end
  end

  # This function is called for all schemas, but only metaschemas should define
  # vocabulary, so nil is a valid vocabulary map. It will not be looked up for
  # normal schemas, and old metaschemas without vocabulary should have a default
  # vocabulary in the library.
  defp do_load_vocabularies(nil, @draft7_normalized_identifier = id) do
    load_vocabularies(@draft7_vocabulary_keyword_fallback, id)
  end

  defp do_load_vocabularies(nil, id) do
    {:error, {:no_vocabulary, id}}
  end

  defp do_load_vocabularies(map, _) when is_map(map) do
    known =
      Enum.flat_map(map, fn {uri, required} ->
        case Map.fetch(@vocabulary, uri) do
          {:ok, module} -> [module]
          :error when required -> throw({:unknown_vocabulary, uri})
          :error -> []
        end
      end)

    {:ok, known}
  catch
    {:unknown_vocabulary, uri} -> {:error, {:unknown_vocabulary, uri}}
  end

  defp sort_vocabularies(modules) do
    Enum.sort_by(modules, fn
      {module, _} -> module.priority()
      module -> module.priority()
    end)
  end

  @doc """
  Returns the raw schema identified by the given namespace if was previously
  resolved as a meta-schema.
  """
  # TODO hide the Resolved module and Resolved.t() type, just directly expose a
  # fetch_vocabularies function.
  @spec fetch_meta(t, binary) :: {:ok, Resolved.t()} | {:error, term}
  def fetch_meta(rsv, meta) do
    fetch_resolved(rsv, {:meta, meta})
  end

  @doc """
  Returns the raw schema identified by the given key if was previously resolved.
  """
  @spec fetch_resolved(t(), resolvable | {:meta, resolvable}) ::
          {:ok, Resolved.t() | {:alias_of, Key.t()}} | {:error, term}
  def fetch_resolved(rsv, {:pointer, _, _} = pointer) do
    fetch_pointer(rsv.resolved, pointer)
  end

  def fetch_resolved(rsv, key) do
    fetch_local(rsv.resolved, key)
  end

  defp fetch_pointer(cache, {:pointer, ns, docpath}) do
    with {:ok, %Resolved{raw: raw, meta: meta, ns: ns, parent_ns: parent_ns, rev_path: rev_path}} <-
           fetch_local(cache, ns, :dealias),
         {:ok, [sub | _] = parent_chain} <- fetch_docpath(raw, docpath),
         {:ok, ns, parent_ns} <- derive_docpath_ns(parent_chain, ns, parent_ns) do
      {:ok,
       %Resolved{
         raw: sub,
         meta: meta,
         vocabularies: nil,
         ns: ns,
         parent_ns: parent_ns,
         rev_path: :lists.reverse(docpath, rev_path)
       }}
    else
      {:error, _} = err -> err
    end
  end

  defp fetch_local(cache, key, aliases \\ nil) do
    case Map.fetch(cache, key) do
      {:ok, {:alias_of, key}} when aliases == :dealias -> fetch_local(cache, key)
      {:ok, {:alias_of, key}} -> {:ok, {:alias_of, key}}
      {:ok, cached} -> {:ok, cached}
      :error -> {:error, {:unresolved, key}}
    end
  end

  defp fetch_docpath(raw_schema, docpath) do
    case do_fetch_docpath(raw_schema, docpath, []) do
      {:ok, sub} -> {:ok, sub}
      :error -> {:error, {:invalid_docpath, docpath, raw_schema}}
    end
  end

  # When fetching a docpath we will create a list of all parents up to the
  # fetched subschema. The top parent is the last item in the list, the fetched
  # subschema is the head.
  #
  # TODO This is to support Draft 7 to define the correct NS for the subschema.
  # We can remove that list building once Draft 7 is not supported anymore.
  defp do_fetch_docpath(list, [h | t], parents) when is_list(list) and is_integer(h) do
    with {:ok, item} <- Enum.fetch(list, h) do
      do_fetch_docpath(item, t, [list | parents])
    end
  end

  defp do_fetch_docpath(raw_schema, [h | t], parents) when is_map(raw_schema) and is_binary(h) do
    with {:ok, sub} <- Map.fetch(raw_schema, h) do
      do_fetch_docpath(sub, t, [raw_schema | parents])
    end
  end

  defp do_fetch_docpath(raw_schema, [], parents) do
    {:ok, [raw_schema | parents]}
  end

  # TODO remove derive_docpath_ns/3, this is only to support Draft7 where we
  # must keep the parent_ns around in a %Resolved{}
  defp derive_docpath_ns([%{"$id" => id} | [_ | _] = tail], parent_ns, parent_parent_ns) do
    # Recursion first to go back to the top schema of the docpath
    with {:ok, parent_ns, _parent_parent_ns} <- derive_docpath_ns(tail, parent_ns, parent_parent_ns),
         {:ok, new_ns} <- RNS.derive(parent_ns, id) do
      {:ok, new_ns, parent_ns}
    end
  end

  defp derive_docpath_ns([_sub_no_id | [_ | _] = tail], parent_ns, parent_parent_ns) do
    derive_docpath_ns(tail, parent_ns, parent_parent_ns)
  end

  defp derive_docpath_ns([_single], ns, parent_ns) do
    # Do not derive from the last schema in the list, as `ns, parent_ns` represent that schema itself
    {:ok, ns, parent_ns}
  end
end
