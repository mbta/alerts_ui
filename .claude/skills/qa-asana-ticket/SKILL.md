---
name: qa-asana-ticket
description: Confirm whether the task specified in an Asana ticket is complete,
or if ti ticket is not complete.
model: haiku
---

# Goal

Verfy the Asana ticket works (or not) as specified

# Steps

First, load the ticket from Asana. Then parse the description field for the
various subsections. Typically, the relevant sections will be "Steps to
Reproduce" and "Acceptance Criteria", although it's possible some may be more
loosely defined than others.

Next, determine which environment you're going to connect to. If uncertain,
ask. However, you can use this list to help build a guess as to which base URL
to connect to:

* Local: http://localhost:4010/
* dev-green: https://alerts-manager-dev-green.mbtace.com/
* dev-orange: https://alerts-manager-dev-orange.mbtace.com/
* staging: https://alerts-manager-staging.mbtace.com/

If you require authentication, stop and ask the user to authenticate the
browser. Open the browser window if it wasn't already open.

Using playwright, try to reproduce using the "Steps to Reproduce" subsection of
the description.

Read through all of the Acceptance Criteria and confirm whether they all happen
as expected in a browser.

As for any help or clarification you need.

# Notes

There is no need to write any code for this skill. Any reports should be output
as normal, and a summary written to `cover/claude-qa-asana-ticket.md`
