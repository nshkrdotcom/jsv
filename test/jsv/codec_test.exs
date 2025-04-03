defmodule JSV.CodecTest do
  alias JSV.Codec

  use ExUnit.Case, async: true

  describe "ordered encoding" do
    defp sample_ordering_data do
      %{
        minimum: 100,
        default: 200,
        if: %{
          minimum: 200,
          default: 200,
          if: %{
            a: "va",
            b: "vb"
          }
        }
      }
    end

    # we will have keys in reverse order to be sure ordering is done, except `if`
    # will be first.
    defp sample_key_sorter(a, b) do
      case {a, b} do
        {:if, _} -> true
        {_, :if} -> false
        _ -> a > b
      end
    end

    defp expected_ordered_json do
      json =
        """
        {
          "if": {
            "if": {
              "b": "vb",
              "a": "va"
            },
            "minimum": 200,
            "default": 200
          },
          "minimum": 100,
          "default": 200
        }
        """

      String.trim(json)
    end

    # We will compare the values trimmed since the native encoder and Jason have
    # different behaviours.

    defp call_sort_encoder(module) do
      iodata = Codec.format_ordered_to_iodata!(module, sample_ordering_data(), &sample_key_sorter/2)

      iodata
      |> IO.iodata_to_binary()
      |> String.trim()
    end

    test "with Jason" do
      assert expected_ordered_json() == call_sort_encoder(JSV.Codec.JasonCodec)
    end

    test "with Poison" do
      assert_raise RuntimeError, ~r/ordered JSON encoding requires Jason/, fn ->
        call_sort_encoder(JSV.Codec.PoisonCodec)
      end
    end

    cond do
      Code.ensure_loaded?(JSV.Codec.NativeCodec) && JSV.Codec.NativeCodec.supports_ordered_formatting?() ->
        test "with Native" do
          assert expected_ordered_json() == call_sort_encoder(JSV.Codec.NativeCodec)
        end

      Code.ensure_loaded?(JSV.Codec.NativeCodec) ->
        test "with Native" do
          assert_raise RuntimeError, ~r/ordered JSON encoding requires Jason/, fn ->
            call_sort_encoder(JSV.Codec.NativeCodec)
          end
        end

      :otherwise ->
        IO.puts("no native JSON codec test")
    end
  end
end
