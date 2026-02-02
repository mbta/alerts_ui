# Manual Regression Testing

## Logging In

The steps in this section only apply to non-local environments. In local
development you will be logged automatically (see README.md).

- Log out of the site
- Confirm you're logged out by trying to access the site; you should see the MBTA login screen
- Log in
- Confirm that you're taken to the alerts list view at `/alerts`

## Alerts List View

- The alerts list view (`/alerts`) should open on on the Current
tab of the timeline, with no filters selected, ordered by ascending
end time.
- Use the pagination links to go to the last page, and to return.
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

## Creating an Alert

To create an alert, click "Create a new alert" from the alerts list view.
You will first see an option to select the service type. Once you select
the service type, the range of available effects will load. When you
select an effect, you will be taken to the alert details form, where you
will specify the route, stops, timing and so on. When you are done with
that page, clicking "Review and Submit" will open the review modal, where
you can check your work. Finally, clicking "Submit" will commit the change
to the server, and send you back to the alerts list view.

Create an alert for each of the six service types:
    - Bus
    - Subway
    - Commuter Rail
    - Ferry
    - Facility
    - Systemwide

Of those six, at least one should: 
    - be a one-time alert
    - be a recurring alert
    - have reminders
    - set an explicit cause
    - have an image

While creating alerts, test form elements for effect period once:
    - Effect period start should default to "Now."
    - Selecting "Start of Service" should add a date picker widget
    - Selecting "Custom" should add a time component to the picker
    - Effect period end should default to "Later today", with no date picker
    - Selecting "End of service" should add a date picker widget
    - Selecting "Until further notice" should make the date picker go away
    - Selecting "Custom" should add a datetime picker

Test form elements for notification period once:
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

## Editing an Alert

- Click the pencil icon on an open alert to edit it. Any open alert will do, including the ones you just
made. You should be taken directly to the alert details screen, i.e., you should not be able to change the service type or effect.
Update one or more values in the form, submit it, then view the alert again to confirm your changes are present.

## Duplicating an Alert

- In the alerts list view, locate the one-time alert you just made, (or one of them) click the menu button with the three vertical dots on the right, and select "Duplicate" from the menu that opens. As when editing, you should be taken directly to the alerts detail form. Confirm your prior selections are present.
- Return to the alerts list view. Locate the recurring alert you just made (or one of them) and repeat the steps above.
- Locate and duplicate alert 688220. Selections should be present in the form as above.
- Locate and duplicate alert 4. Confirm that you get a modal warning about routes and stops
missing from GTFS. Confirming the modal should allow you to proceed to the form.

## Downloading an Alert History

- Download the alert history from a recent alert created in Alerts manager.
- Download the alert history from a legacy alert imported from IBI.
