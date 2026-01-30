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
1. `npm --prefix assets i`
4. `cat .envrc.example | sed -e "s/__username__/$(logname)/g" > .envrc`
6. `direnv allow`
7. `mix ecto.setup`
8. `mix ecto.test_setup`

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

Swagger docs for the API enpoints can be found at `/api/swagger`.

## Our Environments

- dev-green
  - sandbox environment, anything can be deployed here
  - pointed toward: keycloak dev, API dev
- dev-orange
  - main is automatically pushed here
  - currently used for test alerts and QA
  - pointed toward: keycloak dev, API dev
- staging
  - main is automatically pushed here
  - supposed to be as production-like as possible
  - pointed toward: keycloak staging, API prod
- prod
  - deployment strategy TBD
  - this is production
  - pointed toward: keycloak prod, API prod

## Manual Regression Testing

### Logging In

- Confirm you're logged out, and cannot access the site
- Log in
- Confirm that you're taken to the alerts list view

### Alerts List View

- The alerts list view (`/alerts`) should open on on the Current
tab of the timeline, with no filters selected, ordered by ascending
end time.
- Click "Filters" to open the filter modal. Ensure that all three sections
of the modal are populated with options. Select a combination, say, "Subway"
/ "Kingston Line" / "Station Issue" and confirm that results are filtered.
- Click through the timeline, selecting Current, Future, Past and All
alerts, and confirm the table responds as it should. Past and All tabs should
be sorted by end time, but descending.
- In the search bar, search for an alert by alert id, and then search for
an alert using a text term, like "Needham."
- Click a row in the table to open a recent alert created in Alerts Manager.
Ensure the details modal opens with no issue. Repeat for an older imported
alert.

### Creating an Alert

- Click the "Create new alert" button. For each of the available service
types, create an alert, selecting routes, stops, directions and facilities
as necessary:
    - Bus
    - Subway
    - Commuter Rail
    - Ferry
    - Facility
    - Systemwide
- Of those six, we need at least one of each alert timing:
    - One-time
    - Recurring
- At least one should have reminders
- At least one should set an explicit cause
- While creating alerts, test form elements for effect period:
    - Effect period start should default to "Now."
    - Selecting "Start of Service" should add a date picker widget
    - Selecting "Custom" should add a time component to the picker
    - Effect period end should default to "Later today", with no date picker
    - Selecting "End of service" should add a date picker widget
    - Selecting "Until further notice" should make the date picker go away
    - Selecting "Custom" should add a datetime picker
- Test form elements for notification period:
    - Notification period should default to "Now" to "When alert is closed"
    - Selecting "Same as effect period" should make the notification end input disappear
    - Selecting "Start of service" should add a date picker for the start, and "When alert is closed"
    - Selecting "Custom" should add a datetime picker, and "When alert is closed"
- Click Review and Submit. You should see the review modal. Confirm your answers are there.
- In the review modal, click "Keep Editing." The modal should disappear and your form answers should
still be present.
- Click "Review and Submit" to bring back the review modal. Now click "Submit." You should be taken
back to the Alerts List View page, and see a green toast message confirming the new alert has been
created.

### Duplicating an Alert

- Duplicate a recent alert created in Alert Manager. Confirm that route, stops and directions
from the old alert are selected in the form.
- Locate and duplicate alert 688220. Selections should be in the form as above.
- Locate and duplicate alert 4. Confirm that you get a modal warning about routes and stops
missing from GTFS. Confirming the modal should allow you to proceed to the form.


### Downloading an Alert History

- Download the alert history from a recent alert created in Alerts manager.
- Download the alert history from a legacy alert imported from IBI.
