# Manual regression testing

## Logging in

The steps in this section only apply to non-local environments. In local
development you will be logged in automatically (see README.md).

- Log out of the site.
- Confirm you're logged out by trying to access the site. You should see the MBTA login screen.
- Log in.
- Confirm that you're taken to the alerts list view at `/alerts`.

Unless otherwise stated, this document assumes you have maximum privileges within
the application. (Maybe we revisit this when we have tooling for setting user roles?)

## Alerts list view

- The alerts list view (`/alerts`) should open on on the Current
tab of the timeline, with no filters selected, ordered by ascending
end time.
- Use the pagination links to go to the last page, and to return.
- Click "Filters" to open the filter modal. Ensure that all three sections
of the modal are populated with options. Select a combination, say, "Subway"
/ "Kingston Line" / "Station Issue" and confirm that results are filtered.
- Click through the timeline, selecting Current, Future, Past and All
alerts, and confirm the table responds as it should. Past and All tabs should
also be sorted by end time, but descending.
- In the search bar, search for an alert by alert id, and then search for
an alert using a text term, like "Needham."
- Click a row in the table to open a recent alert created in Alerts Manager.
Ensure the details modal opens with no issue. Repeat for an older imported
alert.

## Creating an alert

To create an alert, click "Create a new alert" from the alerts list view.
You will first see an option to select the service type. Once you select
the service type, the range of available effects will load. When you
select an effect, you will be taken to the alert details form, where you
will specify the route, stops, timing and so on. When you are done with
that page, clicking "Review and Submit" will open the review modal, where
you can check your work. Finally, clicking "Submit" will commit the change
to the server, and send you back to the alerts list view.

We will create an alert for each of the six service types:
- Bus
- Subway
- Commuter Rail
- Ferry
- Facility
- Systemwide

Of those six, one or more should:
- be a one-time alert
- be a recurring alert
- have reminders
- set an explicit cause
- have a URL
- have an image
- customize the main message and supporting information text
- set banner text

### Alert type

Select the service type affected by the alert. There should be a horizontal array of large buttons with icons:
- Bus
- Subway
- Commuter Rail
- Ferry
- Facility
- Systemwide

By default, the effect section will only say "Select a service type to see possible effects." Verify that
selecting a service type populates the list of effects, and that selecting a different one updates it.

Click an effect to be taken to the alert details page.

### Alert details

Enter the rest of the alert information on this page. As a quick reference, if you click "Review and Submit" on this
page without entering any information, you should see the following validation errors in the red toast message, depending
on the service type:

- Bus, Subway: Select direction, select stop(s), select route(s)
- Commuter Rail, Ferry: Select direction, select route(s), select trip(s)
- Facility: Select a facility
- Systemwide: Select a service type

#### Affected service

Use this selection to indicate what routes, trips, stops, facilities and/or modes affected by the alert.
The available selections in this section depend on the service type:

##### Bus

- Routes: a scrolling multiselect populated on load. Selecting a route should populate the available stops and directions. Selecting
  multiple routes should disable the stop and direction selects.
- Directions: A select directly under the "Stops" header, populated with "Both Directions", (default) "Inbound", and "Outbound" when active.
- Stops: A searchable multiselect of available stops. Verify stops can be filtered by name.

##### Subway

- Lines: A vertical array of selectable buttons with the line name and icon. Selecting a line should populate the available stops and
  directions. Selecting multiple lines should disable the stop and direction selects. Available lines should be:
    - Red Line
    - Orange Line
    - Green Line
    - Green Line B
    - Green Line C
    - Green Line D
    - Green Line E
    - Blue Line
- Directions: A select directly under the "Stops" header. When the Red or Orange Line is selected, the directions will be "Both Directions",
  "Northbound" and "Southbound". When the Blue Line or a Green Line is selected, the directions will be "Both Directions", "Eastbound" and "Westbound."
- Stops: A searchable multiselect of available stops. Verify stops can be filtered by name.

##### Commuter Rail:

- Lines: A vertical array of selectable buttons with the line name and icon. Selecting a line should populate the available trips and
  directions. Selecting multiple lines should disable the direction select, but not the trip select; when multiple lines are selected,
  the trip selector should separate them with headers for each. Available lines should be:
    - Fairmount Line
    - Fall River/New Bedford Line
    - Fitchburg Line
    - Framingham/Worcester Line
    - Franklin/Foxboro Line
    - Greenbush Line
    - Haverhill Line
    - Kingston Line
    - Lowell Line
    - Needham Line
    - Newbury/Rockport Line
    - Providence/Stoughton Line
    - Foxboro Event Service
- Directions: A select directly under the "Trips" header. When the Red or Orange Line is selected, the directions will be "Both Directions",
  "Northbound" and "Southbound". When the Blue Line or a Green Line is selected, the directions will be "Both Directions", "Eastbound" and "Westbound."
- Trips: A searchable multiselect of available trips. Verify trips can be filtered by name.
- Trip date filter: Above the direction select should be a link that opens a modal to filter by day. The default should be to show only the current day's trips.  Verify trips can be filtered by day.

##### Ferry:

- Routes: A vertical array of selectable buttons with the route name and icon. Selecting a route should populate the available trips and
  directions. Selecting multiple routes should disable the direction select, but not the trip select; when multiple routes are selected,
  the trip selector should separate them with headers for each. Available routes should be:
    - Charlestown Ferry
    - Hingham/Hull Ferry
    - East Boston Ferry
    - Lynn Ferry
    - Winthrop Ferry
    - Quincy Ferry
- Directions: A select directly under the "Trips" header. When active, the available selections should be "Both Directions", "Outbound" and "Inbound".
- Trips: A searchable multiselect of available trips. Verify trips can be filtered by name.
- Trip date filter: Above the direction select should be a link that opens a modal to filter by day. The default should be to show only the current day's trips.  Verify trips can be filtered by day.

##### Facility

- Facilities: A searchable single select of facilities. Verify facilities can be filtered by name.
- Stop filter: Above the facility select should be a link that opens a modal to filter facilities by stop. Verify facilities can be filtered by stop.

##### Systemwide

- Service types impacted: A vertical array of selectable buttons with the names and icons of the following service types:
    - Bus
    - Commuter Rail
    - Ferry
    - Subway

#### Timeframe

Available alert timings should be "One-time" and "Recurring," with "One-time" the default.

##### One-time alerts

- Effect period start should default to "Now."
- Selecting "Start of Service" should add a date picker widget with today's date, and trigger a validation error that the date can't be in the past.
- Selecting "Custom" should add a time component to the picker with the current date and time
- Effect period end should default to "Later today", with no date picker
- Selecting "End of service" should add a date picker widget with today's date
- Selecting "Until further notice" should make the date picker go away
- Selecting "Custom" should add a datetime picker with today's date at 11:59 PM
- Entering a date in the past should result in a validation error; past dates should not be selectable in the date picker

##### Recurring alert

Under Alert timing, select "Recurring".

- You should now see four selects, with the following labels and options. The first option should be selected by default in all four. There should be
a validation message for recurring alert start, warning that the start cannot
be in the past.
    - **Effect start**: Start of service, Custom
    - **Effect end**: End of service, Custom
    - **Recurring alert start**: Now, Custom
    - **Recurring alert end**: When alert is closed, Custom
- There should also be a row of buttons with one button for each day of the week. With
no days selected, there should be a validation warning that you must select at least one day.
- You must select at least the day of the week corresponding to the effect start. If you select a different day, you should see a validation error.

The notification period section is the same for both kinds of alert:
- Notification period should default to "Now" to "When alert is closed"
- Selecting "Same as effect period" should make the notification end input disappear
- Selecting "Start of service" should add a date picker for the start with today's date with a validation error that the date can't be in the past, and "When alert is closed" for the end
- Selecting "Custom" should add a datetime picker for the start with the current date and time, and "When alert is closed" for the end
- Entering a date in the past should result in a validation error; past dates should not be selectable in the date picker


#### Alert details

Cause, severity and main message:
- Verify that the available causes match the selected alert type. These options will be all lowercase
except for proper names.
- Verify the severity select is populated with the standard values. The default severity should be "about 15 minutes".
- You should be able to select a cause and a (different) severity
- The main message text area should show a running character count in the bottom right hand corner with a maximum of 255
- As you select causes and severities, the autotext in the main message should update; for example, on a bus delay
  alert, selecting "electrical work" and "about 25 minutes" should result in an autotext of "experiencing delays of about 25 minutes due to electrical work"
- Before you edit the autotext, the reload button to the right should be highlighted. Edit the autotext. The reload button
  should no longer be highlighted, indicating the text has changed. Clicking the reload button should restore the autotext.
- Clicking the copy button under the reload button should copy the autotext to your operating system clipboard.
- Main message is required; trying to submit an otherwise-valid alert with a blank main message should result in a validation error.

Supporting information:
- The supporting information text area should be blank by default, and show a running character count in the lower right hand
  corner with a maximum of 3000.
- When the text area is blank, the reload button to the right should be highlighted. Enter some text. The reload button
  should no longer be highlighted, indicating the text has changed. Clicking the reload button should clear the text area.
- Clicking the copy button under the reload button should copy the supporting information text to your operating system clipboard.
- Supporting information is optional; no error should appear if it is not present.

URL and image:
- The URL and Image URL fields should require a properly formatted URL and show a validation error if not
- All three fields should be optional

#### Delivery

The "Send notification to alert subscribers" checkbox should be active and checkable.

Test banner text element:
- Clicking the "Banner on all MBTA.com pages" box should open a large input for the banner text, with checkbox below to confirm you know this will put a banner on all of MBTA's sites
- The banner text should default to the main message
- If visible, submitting the form without checking the confirmation box should result in a validation error

#### Rider remindres

- Clicking the "Add reminder" button should add a datetime input element, with an X button to remove it.
- You should be able to type a date and time into the reminder input
- Clicking calendar icon should open a date picker
- If you've already entered a time, changing the date with the picker should not reset it
- You should not be able to add a reminder that occurs before or after the notification period. Doing so from the keyboard should result in a validation error, and dates outside the period should not be selectable in the date picker
- Clicking "Add reminder" again should give you another reminder input element

#### Review and submission

- Click Review and Submit. You should see the review modal. Confirm your selections and answers are present. If you updated autotext, make sure your change is there. If you provided a URL for the alert, it should be clickable. If you provided an image url, the image should load.
- Click "Keep Editing." The modal should disappear, your form answers should still be present, and the window should be at the same scroll point.
- Click "Review and Submit" to bring back the review modal. Now click "Submit." If successful, you should be taken back to the Alerts List View page, and see a green toast message confirming the new alert has been created. This should never fail, as all validity issues should be sorted out by now.

### Editing Alerts

- Only open alerts can be edited. In the alerts list view, navigate to a past alert. The only action icon should be the vertical three dots. Opening it should reveal a menu with "Duplicate" and "Download History."
- Navigate to open alerts. Open alerts should have three available actions: a pencil to edit the alert, an X to close the alert, and the vertical three buttons as above.
- Click on an open alert to open the alert details modal. There should be three buttons across the bottom: "Close alert", (in red), "Duplicate", and "Edit this alert" (default).
- Click "Edit this alert".
- You should be taken to the Alert Details form for this alert, i.e., you cannot edit an alert's service type or effect. The form should behave as described above, only filled with the values provided when it was created.
- Update fields as you see fit, then repeat the "Review and submission" steps above to confirm your changes.

## Closing alerts

- In the alerts list view, find an to open alert. Click the X to close it.
- A "Close alert" modal should open, asking you to confirm that you want to delete the alert, with a checkbox labeled "Send \"all clear\" message to alert subscribers".
- If the alert has a `last_push_notification_timestamp` set, this checkbox will be enabled by default. If the timestamp is nil, it will be unchecked by default.


## Duplicating an alert

- In the alerts list view, locate the one-time alert you just made, (or one of them) click the menu button with the three vertical dots on the right, and select "Duplicate" from the menu that opens. As when editing, you should be taken directly to the alerts detail form. Confirm your prior selections are present.
- Return to the alerts list view. Locate the recurring alert you just made (or one of them) and repeat the steps above.
- Locate and duplicate alert 688220. Selections should be present in the form as above.
- Locate and duplicate alert 4. Confirm that you get a modal warning about routes and stops
missing from GTFS. Confirming the modal should allow you to proceed to the form.

## Downloading an alert history

- Download the alert history from a recent alert created in Alerts manager.
- Download the alert history from a legacy alert imported from IBI.
