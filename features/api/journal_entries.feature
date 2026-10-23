Feature: API journal entries
  The JSON API and the MCP tools list a window of journal entries with the journal's stats, and read, write,
  change and delete one entry, with its tags and linked records.

  Background:
    Given an API token

  Scenario: Listing a window gives its entries newest first, with their tags, markdown and stamps
    Given the journal holds:
      | body                   | day        | time  | tags   | written              | changed              |
      | a **bold** day\n\n- one | 2026-03-01 | 08:00 |        | 2026-03-01T14:00:00Z | 2026-03-01T14:00:00Z |
      | second                 | 2026-03-02 | 21:15 | health | 2026-03-02T09:00:00Z | 2026-03-05T12:00:00Z |
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31"
    Then the call answers 200
    And the answer's "entries" is:
      """
      [{"id": 2, "date": "2026-03-02", "time": "21:15", "body": "second", "tags": ["health"],
        "created_at": "2026-03-02T09:00:00Z", "updated_at": "2026-03-05T12:00:00Z"},
        {"id": 1, "date": "2026-03-01", "time": "08:00", "body": "a **bold** day\n\n- one", "tags": [],
        "created_at": "2026-03-01T14:00:00Z", "updated_at": "2026-03-01T14:00:00Z"}]
      """

  Scenario: An empty window answers 200 and describes itself
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31"
    Then the call answers 200
    And the answer matches:
      """
      {"from": "2026-03-01", "to": "2026-03-31", "count": 0, "partial": false, "entries": [],
        "stats": {"entries": 0, "words": 0, "streak": {"days": 30, "written": 0}}}
      """

  Scenario: Listing leaves out entries outside the window
    Given the journal holds:
      | body  | day        |
      | april | 2026-04-01 |
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31"
    Then the answer's "entries" lists 0

  Scenario: Listing by tag keeps the entries that carry it, read in any case and trimmed
    Given the journal holds:
      | body    | day        | tags         |
      | none    | 2026-03-01 |              |
      | both    | 2026-03-02 | health, ruby |
      | ruby    | 2026-03-03 | ruby         |
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31&tag=Health"
    Then the answer's "entries" lists 1
    And the answer's "entries.0.body" is "both"
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31&tag=%20ruby%20"
    Then the answer's "entries" lists 2
    And the answer's "entries.0.body" is "ruby"
    And the answer's "entries.1.body" is "both"

  Scenario: Listing with a blank tag reads as no tag
    Given the journal holds:
      | body | day        |
      | none | 2026-03-02 |
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31&tag="
    Then the answer's "entries" lists 1

  Scenario: The stats count the whole journal, whatever the window and tag, as the admin's journal does
    Given the journal holds:
      | body          | day        |
      | one two three | {today}    |
      | four five     | {today-1}  |
      | six           | {today-40} |
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31&tag=health"
    Then the answer's "stats" is:
      """
      {"entries": 3, "words": 6, "streak": {"days": 30, "written": 2}}
      """
    Given I am signed in to the admin
    When I visit "/admin/journal"
    Then the journal page shows ".page-head-sub" holding "3 entries · 6 words · wrote on 2 of the last 30 days"

  Scenario: Listing stops at the row cap and says where to go on
    Given the journal holds numbered entries:
      | days back | count |
      | 0         | 1     |
    And the database runs:
      """
      update journal_entries set entry_date = '2026-03-01';
      insert into journal_entries (entry_date, entry_time, body, body_html)
        select '2026-03-02', '08:00', 'entry ' || n, '<p>entry</p>' from generate_series(1, 100) n;
      """
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31"
    Then the answer matches:
      """
      {"count": 100, "partial": true, "continue_to": "2026-03-01"}
      """

  Scenario: Listing refuses a window that runs backwards with a 422
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-31&to=2026-03-01"
    Then the call answers 422
    And the answer matches:
      """
      {"error": "invalid", "message": "from comes after to",
        "errors": {"from": ["from comes after to"], "to": ["from comes after to"]}}
      """

  Scenario: Listing refuses a window with no end
    When I call the API with "GET /api/v1/journal_entries?from=2026-03-01"
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"to": ["to is missing"]}
      """

  Scenario: Listing tells every cache not to store the answer
    Then the journal API sends the header "Cache-Control" as "private, no-store" for "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31"

  Scenario: Reading an entry answers it with its tags, markdown and stamps in UTC
    Given the journal holds:
      | body                    | day        | time  | tags         | written              | changed              |
      | a **bold** day\n\n- one | 2026-03-02 | 09:30 | health, ruby | 2026-03-02T09:30:00Z | 2026-03-04T18:00:00Z |
    When I call the API with "GET /api/v1/journal_entries/1"
    Then the call answers 200
    And the answer matches:
      """
      {"id": 1, "date": "2026-03-02", "time": "09:30", "body": "a **bold** day\n\n- one", "tags": ["health", "ruby"],
        "record_links": {}, "created_at": "2026-03-02T09:30:00Z", "updated_at": "2026-03-04T18:00:00Z"}
      """

  Scenario: Reading an entry answers its linked records grouped by kind
    Given the journal holds:
      | body  |
      | a day |
    And the database runs:
      """
      insert into tasks (title, list, position) values ('Move the server', 'next', 1);
      insert into record_links (left_kind, left_id, right_kind, right_id) values ('task', 1, 'journal_entry', 1);
      """
    When I call the API with "GET /api/v1/journal_entries/1"
    Then the answer matches:
      """
      {"record_links": {"task": [{"kind": "task", "id": 1, "title": "Move the server"}]}}
      """

  Scenario: Writing an entry saves it on today with its tags and answers 201
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"body": "Wrote about abc", "tags": ["ruby", "Health"]}
      """
    Then the call answers 201
    And the answer matches:
      """
      {"body": "Wrote about abc", "tags": ["health", "ruby"]}
      """
    And the database answers "true" for:
      """
      select entry_date = (now() at time zone 'America/Chicago')::date from journal_entries
      """

  Scenario: Writing an entry lands on the earlier day it names
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"body": "Back then", "entry_date": "2026-03-04"}
      """
    Then the database answers "2026-03-04" for:
      """
      select entry_date::text from journal_entries
      """

  Scenario: Writing a blank body answers 422 naming the field
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"body": "  "}
      """
    Then the call answers 422
    And the answer matches:
      """
      {"error": "invalid", "message": "body needs a character that is not a space",
        "errors": {"body": ["body needs a character that is not a space"]}}
      """

  Scenario: Writing refuses a control character, a missing body and a body that is not a string
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"body": "bad\u0000body"}
      """
    Then the answer's "errors" is:
      """
      {"body": ["body holds a control character"]}
      """
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"tags": ["ruby"]}
      """
    Then the answer's "errors" is:
      """
      {"body": ["body is missing"]}
      """
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"body": 5}
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"body": ["value at `/body` is not a string"]}
      """

  Scenario: Writing refuses a field it does not take
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"body": "fine", "mood": "good"}
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"mood": ["object property at `/mood` is a disallowed additional property"]}
      """

  Scenario: Writing refuses a tag the admin would refuse with a 422
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"body": "Tagged", "tags": ["no_good"]}
      """
    Then the call answers 422
    And the answer's "message" is "a tag is lowercase words joined by hyphens"

  Scenario: Writing refuses a day after today and saves nothing
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"body": "Not yet", "entry_date": "2999-01-01"}
      """
    Then the call answers 422
    And the answer includes "entry_date"
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """

  Scenario: Writing a body that is not JSON, or JSON that is not an object, answers 400
    When I send the journal API "POST /api/v1/journal_entries" the raw body "{nope"
    Then the journal API answers 400 with:
      """
      {"error": "invalid_json", "message": "the body takes a JSON object"}
      """
    When I send the journal API "POST /api/v1/journal_entries" the raw body "[]"
    Then the journal API answers 400 with:
      """
      {"error": "invalid_json"}
      """

  Scenario: Changing the body keeps the tags, the date and the written stamp, and moves the changed stamp
    Given the journal holds:
      | body   | day        | tags   | written              | changed              |
      | before | 2026-03-02 | health | 2026-03-02T09:00:00Z | 2026-03-02T09:00:00Z |
    When I call the API with "PATCH /api/v1/journal_entries/1" and:
      """
      {"body": "after"}
      """
    Then the answer matches:
      """
      {"body": "after", "tags": ["health"], "date": "2026-03-02", "created_at": "2026-03-02T09:00:00Z"}
      """
    And the database answers "true" for:
      """
      select updated_at > '2026-03-02T09:00:00Z' from journal_entries
      """

  Scenario: Changing the tags keeps the body, and an empty list clears them
    Given the journal holds:
      | body   | tags   |
      | before | health |
    When I call the API with "PATCH /api/v1/journal_entries/1" and:
      """
      {"tags": ["ruby"]}
      """
    Then the database answers "before, ruby" for:
      """
      select e.body, t.name from journal_entries e
      join journal_entry_tags jt on jt.journal_entry_id = e.id join tags t on t.id = jt.tag_id
      """
    When I call the API with "PATCH /api/v1/journal_entries/1" and:
      """
      {"tags": []}
      """
    Then the answer's "tags" is:
      """
      []
      """

  Scenario: Changing to a blank body answers 422 and keeps the old one
    Given the journal holds:
      | body   |
      | before |
    When I call the API with "PATCH /api/v1/journal_entries/1" and:
      """
      {"body": " "}
      """
    Then the call answers 422
    And the database answers "before" for:
      """
      select body from journal_entries
      """

  Scenario: Deleting an entry removes it
    Given the journal holds:
      | body |
      | gone |
    When I call the API with "DELETE /api/v1/journal_entries/1"
    Then the answer matches:
      """
      {"id": 1, "deleted": true}
      """
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """

  Scenario: The MCP tools list, read, write and change entries as the endpoints do
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    And a post "On racks" published an hour ago
    And the journal holds:
      | body   | day        | tags   |
      | tagged | 2026-03-02 | health |
      | plain  | 2026-03-03 |        |
    And the journal entry "tagged" links to the post "On racks"
    Then the journal MCP tool "list_journal_entries" answers as "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31" does, given:
      """
      {"from": "2026-03-01", "to": "2026-03-31"}
      """
    And the journal MCP tool "list_journal_entries" answers as "GET /api/v1/journal_entries?from=2026-03-01&to=2026-03-31&tag=health" does, given:
      """
      {"from": "2026-03-01", "to": "2026-03-31", "tag": "health"}
      """
    And the journal MCP tool "read_journal_entry" answers as "GET /api/v1/journal_entries/1" does, given:
      """
      {"id": 1}
      """
    And the journal MCP tool "create_journal_entry" answers as "POST /api/v1/journal_entries" does but for "id, time, created_at, updated_at", given:
      """
      {"body": "the same", "entry_date": "{today-1}", "tags": ["ruby"]}
      """
    And the journal MCP tool "update_journal_entry" answers as "PATCH /api/v1/journal_entries/2" does but for "updated_at", given:
      """
      {"id": 2, "body": "after", "tags": ["ruby"]}
      """

  Scenario: The MCP tools delete and refuse as the endpoints do
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    And the journal holds:
      | body  |
      | one   |
      | two   |
    When I call the API with "DELETE /api/v1/journal_entries/1"
    Then the answer matches:
      """
      {"id": 1, "deleted": true}
      """
    When I call the MCP tool "delete_journal_entry" with:
      """
      {"id": 2}
      """
    Then the answer matches:
      """
      {"id": 2, "deleted": true}
      """
    When I call the API with "POST /api/v1/journal_entries" and:
      """
      {"body": " "}
      """
    Then the answer's "message" is "body needs a character that is not a space"
    When I call the MCP tool "create_journal_entry" with:
      """
      {"body": " "}
      """
    Then it refuses
    And the answer includes "body needs a character that is not a space"
