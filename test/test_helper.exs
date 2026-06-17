{:ok, _} = Application.ensure_all_started(:ex_machina)
# `:known_bug` tests demonstrate currently-unfixed bugs (they assert the
# intended behavior and so fail until fixed). Excluded from the default run;
# see them with `mix test --include known_bug`.
ExUnit.start(exclude: [:known_bug])
Ecto.Adapters.SQL.Sandbox.mode(AlertsUI.Repo, :manual)
