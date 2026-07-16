# AlertsUI

A UI for creating and modifying alerts

## Setup

### Requirements

- [`asdf`](https://asdf-vm.com/) with plugins: `elixir`, `erlang`, `nodejs`, `protoc`
  - `asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git`
  - `asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git`
  - `asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git`
  - `asdf plugin add protoc https://github.com/paxosglobal/asdf-protoc.git`
  - Make sure `asdf` is [configured](https://asdf-vm.com/guide/getting-started.html#_2-configure-asdf) to add shims to your PATH so that you can run i.e. `node` directly
- PostgreSQL 15 (using Homebrew: `brew install postgresql@15`)
  - You will need Postgres client tools in your PATH; if using Homebrew and you
  get an error about missing tools, use `brew link postgresql@15`
  - Make sure the postgres daemon has started: `brew services start postgresql@15`
- [`direnv`](https://direnv.net/) _(optional, for auto-loading env vars)_
- An MBTA v3 API key
  - Visit https://api-dev.mbtace.com for dev or https://api.mbtace.com for prod
  - Register for a developer account and request a key

### Instructions

Install dependencies
1. `asdf install`
2. `mix deps.get`
1. `npm --prefix assets i`

Set up environment variables
1. `cat .envrc.example | sed -e "s/__username__/$(logname)/g" > .envrc`
1. Paste your MBTA API Key to `.envrc` for `API_KEY` and `DEV_API_KEY`
1. `direnv allow`

Create the database and setup the app
1. `mix ecto.setup`
1. `mix ecto.test_setup`


The above assumes you have a PostgreSQL user with the same name as your OS user
(`logname`), which should be the default with a Homebrew install. Otherwise, you
may need to adjust the username in `.envrc`.

If not using `direnv`, you can instead `source .envrc` to perform a one-time
export of the environment variables into your current shell session.

### Running tests

- `mix test`

## Development

To start your Phoenix server:

- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4010`](http://localhost:4010) from your browser.

Swagger docs for the API enpoints can be found at `/api/swagger`.

### Mobile development

You can access your server on your phone by making the following changes:

- In `config/dev.exs`, change `http: [ip: {127, 0, 0, 1}, port: 4010]` to `http: [ip: {0, 0, 0, 0}, port: 4010]`
- Restart your Phoenix server with this change
- Look up your local IP address. On OSX: `ipconfig getifaddr en0`
- On any device connected to your network, visit `{ip_address}:4010`


## Debugging/special routes

- Live Debugger: `:4007` local only by default, change in `mix.exs`

- LiveDashboard dashboard: `/dev/dashboard` enabled only locally by default, use config item `dev_routes` to change

- Oban dashboard: `/oban`

- Client side flags: `/_flags`- mediated by Laboratory library (check `mix.exs` for github if you need docs)

- Server side flags: `/feature_flags`- these are hand rolled. To create one, call `FeatureFlags.enabled?("my_flag_name")` anywhere, and if the flag doesn't exist it will be created and put in the database. You can then go ot the `/feature_flags` route to toggle it on and off for the whole environment. It will be set to `false` by default.

- DB viewer: `/db`

- Version: `/_version` shows currently deployed version, must be developer to view

## Our Environments

- dev-green
  - sandbox environment, anything can be deployed here
  - main is automatically pushed here
  - pointed toward: keycloak dev, API dev
- dev-orange
  - currently used for test alerts and QA
  - main is automatically pushed here
  - pointed toward: keycloak dev, API dev
- staging
  - supposed to be as production-like as possible
  - main is automatically pushed here
  - used by MBTA teams to make test alerts
  - pointed toward: keycloak staging, API prod
- prod
  - this is production
  - deployed automatically when a release is created and approved via [GitHub's release page](https://github.com/mbta/alerts_ui/releases).
  - If you need to roll back you can create a release for a previous tag
  - pointed toward: keycloak prod, API prod
  
You can use the `SENTRY_ENV` environment variable to find out the name of the current environment. Note that `prod.exs` in `/config` runs for all deployed environments, so if you want a config that is just for a subset of deployed environments, you have to specify that.
