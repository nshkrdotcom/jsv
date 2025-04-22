# credo:disable-for-this-file Credo.Check.Readability.Specs
# credo:disable-for-this-file Credo.Check.Readability.ModuleDoc
defmodule Mix.Tasks.Jsv.UpdateJstsRef do
  use Mix.Task

  @dep_dir "deps/json_schema_test_suite"

  def run(_argv) do
    IO.puts("pulling main on #{@dep_dir}")

    {_, 0} = System.cmd("git", ~w(reset --hard HEAD), cd: @dep_dir)
    {_, 0} = System.cmd("git", ~w(checkout main), cd: @dep_dir)
    {_, 0} = System.cmd("git", ~w(pull), cd: @dep_dir)
    {ref, 0} = System.cmd("git", ~w(rev-parse HEAD), cd: @dep_dir)
    ref = String.trim(ref)

    IO.puts("updating mix.exs")

    "mix.exs"
    |> File.read!()
    |> String.replace(~r/@jsts_ref "[^"]+"/, ~s(@jsts_ref "#{ref}"))
    |> then(&File.write!("mix.exs", &1))

    IO.puts("done")
  end

  # Format can be :binary or :atom, it changes the way the schemas will be
end
