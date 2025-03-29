#!/usr/bin/env elixir
defmodule Tool do
  def run do
    Path.wildcard(Path.join(File.cwd!(), "guides/**/*.md"))
    |> Enum.filter(&File.regular?/1)
    |> Enum.each(&check_file/1)
  end

  defp check_file(path) do
    path
    |> File.stream!()
    |> Stream.map(&String.trim_trailing(&1, "\n"))
    |> Stream.with_index(1)
    # Filter out TOCs and links
    |> Stream.reject(fn {text, _} -> String.contains?(text, "](#") || String.contains?(text, "](http") end)

    # Filter out generated content
    |> Stream.transform([], fn {text, line}, block_nesting ->
      case transform_lines(text, block_nesting) do
        {:keep, new_block_nesting} -> {[{text, line}], new_block_nesting}
        {:discard, new_block_nesting} -> {[], new_block_nesting}
      end
    end)
    |> Stream.map(fn {text, line} -> {String.length(text), line} end)
    |> Stream.filter(fn {len, _} -> len > 80 end)
    |> Enum.sort_by(fn {_, line} -> line end, :desc)
    |> Enum.each(fn {len, line} ->
      IO.puts("#{path}:#{line} line is #{len} chars long.")
    end)
  end

  # start a generated block, prepend :generated in the nested block types. This will only happen at the top level
  defp transform_lines(<<"<!-- rdmx "::binary, c::utf8, _::binary>>, []) when c != ?/ do
    {:discard, [:generated]}
  end

  # stop the generated block, pop the nested block type
  defp transform_lines("<!-- rdmx /" <> _, [:generated]) do
    {:discard, []}
  end

  # triple backticks end a code block if we can pop a :code from the nesting.
  defp transform_lines("```" <> _, [:code | t]) do
    {:discard, t}
  end

  # otherwise triple backticks start a code block
  defp transform_lines("```" <> _, block_nesting) do
    {:discard, [:code | block_nesting]}
  end

  # Not in a block, we return the line
  defp transform_lines(_, []) do
    {:keep, []}
  end

  # In a block, we skip the line
  defp transform_lines(_, [_ | _] = block_nesting) do
    {:discard, block_nesting}
  end
end

Tool.run()
