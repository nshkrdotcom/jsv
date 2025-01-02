defmodule JSV.Codec do
  @moduledoc """
  JSON encoder/decoder based on available implementation.
  """

  @doc false
  @spec codec :: module
  def codec

  cond do
    Code.ensure_loaded?(JSON) ->
      def codec do
        JSON
      end

      defp do_decode(json) do
        JSON.decode(json)
      end

      defp do_decode!(json) do
        JSON.decode!(json)
      end

      defp do_encode!(data) do
        JSON.encode!(data)
      end

      if Code.ensure_loaded?(:json) do
        defp do_format!(data) do
          data |> :json.format() |> :erlang.iolist_to_binary()
        end
      else
        defp do_format!(data) do
          Jason.encode!(data, pretty: true)
        end
      end

    Code.ensure_loaded?(Poison) ->
      def codec do
        Poison
      end

      defp do_decode(json) do
        Poison.decode(json)
      end

      defp do_decode!(json) do
        Poison.decode!(json)
      end

      defp do_encode!(data) do
        Poison.encode!(data)
      end

      defp do_format!(data) do
        Poison.encode!(data, pretty: true)
      end

    Code.ensure_loaded(Jason) ->
      def codec do
        Jason
      end

      defp do_decode(json) do
        Jason.decode(json)
      end

      defp do_decode!(json) do
        Jason.decode!(json)
      end

      defp do_encode!(data) do
        Jason.encode!(data)
      end

      defp do_format!(data) do
        Jason.encode!(data, pretty: true)
      end

    true ->
      # TODO this could be a runtime error, if library users do not use the
      # resolver at all, there is no need to require a codec.
      raise "could not define JSON codec for #{inspect(__MODULE__)}\n\n" <>
              "For Elixir versions lower than 1.18, make sure to declare a JSON parser " <>
              ~S|dependency such as {:jason, "~> 1.0"}, {:poison, "~> 5.0"} or | <>
              ~S|{:poison, "~> 6.0"}.|
  end

  @spec decode(binary) :: {:ok, term} | {:error, term}
  def decode(json) when is_binary(json) do
    do_decode(json)
  end

  @spec decode!(binary) :: term
  def decode!(json) when is_binary(json) do
    do_decode!(json)
  end

  @spec encode!(term) :: binary
  def encode!(term) do
    do_encode!(term)
  end

  @doc false
  # This is only useful for the test suite.
  @spec format!(term) :: binary
  def format!(term) do
    do_format!(term)
  end
end
