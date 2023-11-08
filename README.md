# AlertsUI

A UI for creating and modifying alerts

## Setup

### Requirements

- [`asdf`](https://asdf-vm.com/) with plugins: `elixir`, `erlang`
- PostgreSQL 15 (using Homebrew: `brew install postgresql@15`)
- You will need Postgres client tools in your PATH; if using Homebrew and you
  get an error about missing tools, use `brew link postgresql@15`
- [`direnv`](https://direnv.net/) _(optional, for auto-loading env vars)_

### Instructions

1. `asdf install`
2. `mix deps.get`
4. `cat .envrc.example | sed -e "s/__username__/$(logname)/g" > .envrc`
6. `direnv allow`
7. `mix ecto.setup`
8. `MIX_ENV=test mix ecto.setup`

The above assumes you have a PostgreSQL user with the same name as your OS user
(`logname`), which should be the default with a Homebrew install. Otherwise, you
may need to adjust the username in `.envrc`.

If not using `direnv`, you can instead `source .envrc` to perform a one-time
export of the environment variables into your current shell session.

### Notes for deployment

Postgres 15 needs special permissions to allow migrations to be run, and they'll need set up for each new environment. cf this [asana ticket](https://app.asana.com/0/1113179098808463/1205855651255216/f)

### Running tests

- `mix test`

## Development

To start your Phoenix server:

- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4010`](http://localhost:4010) from your browser.
