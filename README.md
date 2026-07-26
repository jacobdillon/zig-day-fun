print a trains location on a mbta route

should look something like this:
`o=======o=============T========o`
with stop names.

calls the mbta's GTFS endpoints (using http.client and protobuf for schedules and realtime respectively)
