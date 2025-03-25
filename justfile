gen-test-suite:
  mix compile
  elixir tools/gen.test.suite.exs draft2020-12
  elixir tools/gen.test.suite.exs draft7
  # mix format --check-formatted
  # git status --porcelain | rg "test/generated" --count && mix test || true

deps:
  mix deps.get

test:
  mix test

lint:
  mix compile --force --warnings-as-errors
  mix credo

dialyzer:
  mix dialyzer

_mix_format:
  mix format

_mix_check:
  mix check

_git_status:
  git status

readme:
  mix rdmx.update README.md

check: deps _mix_format _mix_check readme _git_status

