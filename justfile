gen-test-suite:
  mix compile
  elixir tools/gen.test.suite.exs draft2020-12
  elixir tools/gen.test.suite.exs draft7
  # mix format --check-formatted
  # git status --porcelain | rg "test/generated" --count && mix test || true

test:
  mix test

lint:
  mix compile --force --warnings-as-errors
  mix credo

dialyzer:
  mix dialyzer

_mix_format:
  mix format

_git_status:
  git status

check: _mix_format test lint dialyzer _git_status

