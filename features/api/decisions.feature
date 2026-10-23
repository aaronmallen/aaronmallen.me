Feature: API decisions
  The JSON API and the MCP tools open, edit, close and list decisions, with their options, comments, tags and tasks.

  Background:
    Given an API token

  Scenario: Opening a decision answers 201, records it and adds its task to the end of the next list
    Given the database runs:
      """
      insert into tasks (title, list, position) values ('Earlier', 'next', 5)
      """
    When I call the API with "POST /api/v1/decisions" and:
      """
      {"title": "Pick a queue", "problem": "Jobs pile up", "tags": ["Queues"]}
      """
    Then the call answers 201
    And the answer matches:
      """
      {"title": "Pick a queue", "problem": "Jobs pile up", "status": "open", "resolved_option_id": null,
        "tags": ["queues"], "options": []}
      """
    And the database answers "opened" for:
      """
      select string_agg(kind::text, ' | ' order by id) from decision_events where decision_id = 1
      """
    And the database answers "Earlier | Resolve decision #1: Pick a queue" for:
      """
      select string_agg(title, ' | ' order by position) from tasks where list = 'next'
      """
    And the database answers "task, 2, decision, 1, sourced_from" for:
      """
      select left_kind, left_id, right_kind, right_id, relation from record_links
      """

  Scenario: Opening a decision with a blank problem answers 422 naming the field
    When I call the API with "POST /api/v1/decisions" and:
      """
      {"title": "Pick a queue", "problem": " "}
      """
    Then the call answers 422
    And the answer matches:
      """
      {"error": "invalid", "message": "problem: write the problem down first",
        "errors": {"problem": ["write the problem down first"]}}
      """

  Scenario: Editing a decision changes what it names and keeps the rest
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "PATCH /api/v1/decisions/1" and:
      """
      {"title": "Pick a job queue"}
      """
    Then the answer matches:
      """
      {"title": "Pick a job queue", "problem": "Jobs pile up"}
      """

  Scenario: Editing an open decision's problem needs no note and drops one given
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "PATCH /api/v1/decisions/1" and:
      """
      {"problem": "Jobs pile up fast", "note": "Load grew"}
      """
    Then the call answers 200
    And the database answers "Jobs pile up fast" for:
      """
      select problem from decisions
      """
    And the database answers "none" for:
      """
      select coalesce(note, 'none') from decision_events where kind = 'edited'
      """

  Scenario: Editing an open decision's problem with no note saves it
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "PATCH /api/v1/decisions/1" and:
      """
      {"problem": "Jobs pile up fast"}
      """
    Then the call answers 200
    And the database answers "Jobs pile up fast" for:
      """
      select problem from decisions
      """

  Scenario: A closed decision's new problem without a note is refused and the old one kept
    Given a dropped decision "Pick a queue" opened 1 hour ago
    When I call the API with "PATCH /api/v1/decisions/1" and:
      """
      {"problem": "Jobs pile up fast"}
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"note": ["a resolved or dropped decision needs a note to say why it changed"]}
      """
    And the database answers "It came up" for:
      """
      select problem from decisions
      """

  Scenario: A closed decision's edit keeps its note
    Given a dropped decision "Pick a queue" opened 1 hour ago
    When I call the API with "PATCH /api/v1/decisions/1" and:
      """
      {"problem": "Jobs pile up fast", "note": "Load grew"}
      """
    Then the database answers "Load grew" for:
      """
      select note from decision_events where kind = 'edited'
      """

  Scenario: An edit that changes nothing records no event
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "PATCH /api/v1/decisions/1" and:
      """
      {"title": "Pick a queue", "problem": "Jobs pile up"}
      """
    Then the call answers 200
    And the database answers "0" for:
      """
      select count(*) from decision_events
      """

  Scenario: A note over 500 characters is refused
    Given a dropped decision "Pick a queue" opened 1 hour ago
    When I call the API with "PATCH /api/v1/decisions/1" and:
      """
      {"problem": "Jobs pile up fast", "note": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
      """
    Then the call answers 422
    And the database answers "0" for:
      """
      select count(*) from decision_events
      """

  Scenario: Editing an unknown decision answers 404
    When I call the API with "PATCH /api/v1/decisions/999999" and:
      """
      {"title": "Gone"}
      """
    Then the call answers 404
    And the answer matches:
      """
      {"error": "not_found", "message": "no decision has the ID 999999"}
      """

  Scenario: Resolving with its own option resolves the decision and answers its options
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs today"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "It runs today"}
      """
    Then the answer matches:
      """
      {"status": "resolved", "resolved_option_id": 1, "options": [{"id": 1, "title": "Sidekiq", "body": "Runs today"}]}
      """

  Scenario: Resolving with another decision's option is refused with a field error
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the option "Fly"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "It runs"}
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"option_id": ["pick one of this decision's own options"]}
      """
    And the database answers "open" for:
      """
      select status from decisions where id = 1
      """

  Scenario: Resolving an unknown decision answers 404
    When I call the API with "POST /api/v1/decisions/999999/resolve" and:
      """
      {"option_id": 1, "reason": "It runs today"}
      """
    Then the call answers 404

  Scenario: Resolving with a blank reason is refused
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": ""}
      """
    Then the answer's "errors" is:
      """
      {"reason": ["write down why first"]}
      """

  Scenario: Resolving a closed decision is refused
    Given a dropped decision "Pick a queue" opened 1 hour ago
    And the decision "Pick a queue" has the option "Sidekiq"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "Now"}
      """
    Then the answer's "errors" is:
      """
      {"id": ["decision 1 is already resolved or dropped"]}
      """

  Scenario: Dropping a decision leaves no choice
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "POST /api/v1/decisions/1/drop" and:
      """
      {"reason": "Not needed"}
      """
    Then the answer matches:
      """
      {"status": "dropped", "resolved_option_id": null}
      """

  Scenario: Dropping with no reason is refused
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "POST /api/v1/decisions/1/drop" and:
      """
      {}
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"reason": ["reason is missing"]}
      """

  Scenario: Reopening a resolved decision clears the choice
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "It runs today"}
      """
    And I call the API with "POST /api/v1/decisions/1/reopen" and:
      """
      {"reason": "Load grew"}
      """
    Then the answer matches:
      """
      {"status": "open", "resolved_option_id": null}
      """

  Scenario: Reopening an open decision is refused
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "POST /api/v1/decisions/1/reopen" and:
      """
      {"reason": "Again"}
      """
    Then the answer's "errors" is:
      """
      {"id": ["decision 1 is already open"]}
      """

  Scenario: Adding an option answers 201 with it
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "POST /api/v1/decisions/1/options" and:
      """
      {"title": "Resque", "body": "Runs on **Redis**"}
      """
    Then the call answers 201
    And the answer matches:
      """
      {"title": "Resque", "body": "Runs on **Redis**"}
      """

  Scenario: Adding an option with no body takes it
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "POST /api/v1/decisions/1/options" and:
      """
      {"title": "Do nothing"}
      """
    Then the answer's "body" is ""

  Scenario: Adding an option to a closed decision is refused
    Given a dropped decision "Pick a queue" opened 1 hour ago
    When I call the API with "POST /api/v1/decisions/1/options" and:
      """
      {"title": "Resque"}
      """
    Then the answer's "errors" is:
      """
      {"id": ["decision 1 is resolved or dropped, so reopen it to add an option"]}
      """

  Scenario: Adding an option to an unknown decision answers 404
    When I call the API with "POST /api/v1/decisions/999999/options" and:
      """
      {"title": "Resque"}
      """
    Then the call answers 404

  Scenario: Editing an option changes what it names and keeps the rest
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs today"
    When I call the API with "PATCH /api/v1/decisions/1/options/1" and:
      """
      {"title": "Sidekiq 8"}
      """
    Then the answer matches:
      """
      {"title": "Sidekiq 8", "body": "Runs today"}
      """

  Scenario: Editing an option on a closed decision without a note is refused
    Given a dropped decision "Pick a queue" opened 1 hour ago
    And the decision "Pick a queue" has the option "Sidekiq"
    When I call the API with "PATCH /api/v1/decisions/1/options/1" and:
      """
      {"title": "Renamed"}
      """
    Then the answer's "errors" is:
      """
      {"note": ["a resolved or dropped decision needs a note to say why it changed"]}
      """

  Scenario: An option edit that changes nothing records no event
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs today"
    When I call the API with "PATCH /api/v1/decisions/1/options/1" and:
      """
      {"title": "Sidekiq", "body": "Runs today"}
      """
    Then the call answers 200
    And the database answers "0" for:
      """
      select count(*) from decision_events
      """

  Scenario: Editing another decision's option answers 404
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the option "Fly"
    When I call the API with "PATCH /api/v1/decisions/1/options/1" and:
      """
      {"title": "Mine"}
      """
    Then the call answers 404
    And the answer matches:
      """
      {"error": "not_found", "message": "decision 1 has no option with the ID 1"}
      """

  Scenario: Deleting an option removes it with its events
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "POST /api/v1/decisions/1/options" and:
      """
      {"title": "Resque"}
      """
    And I call the API with "DELETE /api/v1/decisions/1/options/1"
    Then the answer matches:
      """
      {"id": 1, "option_id": 1, "deleted": true}
      """
    And the database answers "0, 0" for:
      """
      select (select count(*) from decision_options) as options, (select count(*) from decision_events where option_id = 1) as events
      """

  Scenario: Deleting another decision's option answers 404
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the option "Fly"
    When I call the API with "DELETE /api/v1/decisions/1/options/1"
    Then the call answers 404

  Scenario: An option once chosen can go after the decision reopens
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "It runs today"}
      """
    And I call the API with "POST /api/v1/decisions/1/reopen" and:
      """
      {"reason": "Load grew"}
      """
    And I call the API with "DELETE /api/v1/decisions/1/options/1"
    Then the call answers 200
    And the database answers "0" for:
      """
      select count(*) from decision_options
      """

  Scenario: The option a decision was resolved with cannot go
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "It runs today"}
      """
    And I call the API with "DELETE /api/v1/decisions/1/options/1"
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"option_id": ["the decision was resolved with this option, so reopen it first"]}
      """

  Scenario: Adding a comment trims it and answers 201
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "POST /api/v1/decisions/1/comments" and:
      """
      {"body": "  Leaning on Sidekiq "}
      """
    Then the call answers 201
    And the answer's "body" is "Leaning on Sidekiq"

  Scenario: A blank comment is refused
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "POST /api/v1/decisions/1/comments" and:
      """
      {"body": " "}
      """
    Then the answer's "errors" is:
      """
      {"body": ["write the comment first"]}
      """

  Scenario: Editing and deleting a comment
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the comment "Leaning on Sidekiq"
    When I call the API with "PATCH /api/v1/decisions/1/comments/1" and:
      """
      {"body": "Leaning on Resque"}
      """
    Then the answer matches:
      """
      {"id": 1, "body": "Leaning on Resque"}
      """
    When I call the API with "DELETE /api/v1/decisions/1/comments/1"
    Then the answer matches:
      """
      {"id": 1, "comment_id": 1, "deleted": true}
      """
    And the database answers "0" for:
      """
      select count(*) from decision_comments
      """

  Scenario: Editing another decision's comment answers 404
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the comment "Elsewhere"
    When I call the API with "PATCH /api/v1/decisions/1/comments/1" and:
      """
      {"body": "Mine"}
      """
    Then the call answers 404

  Scenario: Tagging adds tags and keeps the ones it has
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" carries the tag "queues"
    When I call the API with "POST /api/v1/decisions/1/tags" and:
      """
      {"tags": ["Ruby", "queues"]}
      """
    Then the call answers 201
    And the answer's "tags" lists 2
    And the answer includes '"queues"'
    And the answer includes '"ruby"'

  Scenario: Tagging a closed decision needs no note
    Given a dropped decision "Pick a queue" opened 1 hour ago
    When I call the API with "POST /api/v1/decisions/1/tags" and:
      """
      {"tags": ["ruby"]}
      """
    Then the answer's "tags" is:
      """
      ["ruby"]
      """

  Scenario: A tag that is not lowercase words joined by hyphens is refused
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "POST /api/v1/decisions/1/tags" and:
      """
      {"tags": ["no way!"]}
      """
    Then the answer's "errors" is:
      """
      {"tags": ["a tag is lowercase words joined by hyphens"]}
      """

  Scenario: Untagging takes one tag off
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" carries the tags "queues, ruby"
    When I call the API with "DELETE /api/v1/decisions/1/tags/queues"
    Then the answer's "tags" is:
      """
      ["ruby"]
      """

  Scenario: Untagging a tag the decision does not carry answers 404
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the API with "DELETE /api/v1/decisions/1/tags/queues"
    Then the call answers 404
    And the answer matches:
      """
      {"error": "not_found", "message": "decision 1 has no tag queues"}
      """

  Scenario: The list holds every decision, newest first, with its counts
    Given an open decision "Older" opened 2 hours ago
    And a dropped decision "Newer" opened 1 hour ago
    When I call the API with "GET /api/v1/decisions"
    Then the answer's "decisions" lists 2
    And the answer matches:
      """
      {"decisions": [{"id": 2}, {"id": 1}], "count": 2, "partial": false,
        "counts": {"open": 1, "resolved": 0, "dropped": 1}}
      """

  Scenario Outline: The list narrows by status, tag and words
    Given an open decision "Older" opened 2 hours ago
    And a dropped decision "Newer" opened 1 hour ago
    And the decision "Older" carries the tags "queues, ruby"
    And the decision "Newer" carries the tag "queues"
    When I call the API with "GET /api/v1/decisions?<query>"
    Then the answer matches:
      """
      {"decisions": <ids>}
      """

    Examples:
      | query                       | ids                    |
      | status=dropped              | [{"id": 2}]            |
      | tag=Ruby                    | [{"id": 1}]            |
      | tag=%20ruby%20              | [{"id": 1}]            |
      | tag=                        | [{"id": 2}, {"id": 1}] |
      | query=+                     | [{"id": 2}, {"id": 1}] |
      | status=open&tag=queues      | [{"id": 1}]            |

  Scenario: The list answers each decision with its options and tags
    Given an open decision "Older" opened 2 hours ago
    And the decision "Older" has the option "Sidekiq"
    And the decision "Older" carries the tag "queues"
    When I call the API with "GET /api/v1/decisions?status=open"
    Then the answer matches:
      """
      {"decisions": [{"tags": ["queues"], "options": [{"title": "Sidekiq"}]}]}
      """

  Scenario: The list pages the decisions
    Given the database runs:
      """
      insert into decisions (title, problem, created_at)
      select 'Decision ' || n, 'It came up', now() - make_interval(mins => n) from generate_series(1, 101) as n
      """
    When I call the API with "GET /api/v1/decisions"
    Then the answer's "decisions" lists 100
    And the answer matches:
      """
      {"partial": true, "next_page": 2}
      """
    When I call the API with "GET /api/v1/decisions?page=2"
    Then the answer matches:
      """
      {"decisions": [{"id": 101}]}
      """

  Scenario: The list refuses an unknown status naming the field
    When I call the API with "GET /api/v1/decisions?status=done"
    Then the call answers 422
    And the answer's "errors.status" lists 1

  Scenario: The list keeps the decisions whose title holds the words, in any case
    Given an open decision "Pick a Job Queue" opened 2 hours ago
    And an open decision "Pick a host" opened 1 hour ago
    When I call the API with "GET /api/v1/decisions?query=job+queue"
    Then the answer matches:
      """
      {"decisions": [{"id": 1}]}
      """

  Scenario: The list keeps the decisions whose problem holds the words
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And an open decision "Pick a host" opened 1 hour ago
    When I call the API with "GET /api/v1/decisions?query=pile"
    Then the answer matches:
      """
      {"decisions": [{"id": 1}]}
      """

  Scenario: The list narrows by words, status and tag together and counts every status for them
    Given an open decision "Pick a queue" opened 4 hours ago
    And a dropped decision "Pick a queue" opened 3 hours ago
    And an open decision "Pick a queue" opened 2 hours ago
    And an open decision "Pick a host" opened 1 hour ago
    And the database runs:
      """
      insert into decision_options (decision_id, title) values (1, 'Sidekiq');
      update decisions set status = 'resolved', resolved_option_id = 1 where id = 1;
      insert into tags (name, color, scope) values ('queues', 'mk-blue', 'private'), ('ruby', 'mk-blue', 'private');
      insert into decision_tags (decision_id, tag_id) values (1, 1), (2, 2), (3, 1), (4, 1);
      """
    When I call the API with "GET /api/v1/decisions?query=queue&status=open&tag=queues"
    Then the answer matches:
      """
      {"decisions": [{"id": 3}]}
      """
    When I call the API with "GET /api/v1/decisions?query=queue&tag=queues&status=dropped"
    Then the answer's "counts" is:
      """
      {"open": 1, "resolved": 1, "dropped": 0}
      """

  Scenario: Reading a decision answers its problem, status, dates, options and tags with no choice
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    And the decision "Pick a queue" carries the tag "queues"
    When I call the API with "GET /api/v1/decisions/1"
    Then the answer matches:
      """
      {"title": "Pick a queue", "problem": "Jobs pile up", "status": "open", "tags": ["queues"],
        "options": [{"title": "Sidekiq"}], "record_links": {}}
      """
    And the answer includes '"created_at":"'
    And the answer includes '"updated_at":"'
    And the answer's "choice" is "null"

  Scenario: Reading a resolved decision answers the chosen option, the latest reason and when it was chosen
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "It runs today"}
      """
    And I call the API with "GET /api/v1/decisions/1"
    Then the answer matches:
      """
      {"choice": {"reason": "It runs today", "option": {"id": 1}}}
      """
    And the decisions API's "choice.resolved_at" for "GET /api/v1/decisions/1" falls within a minute of now
    When I call the API with "POST /api/v1/decisions/1/reopen" and:
      """
      {"reason": "Load grew"}
      """
    And I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "Still the best"}
      """
    And I call the API with "GET /api/v1/decisions/1"
    Then the answer's "choice.reason" is "Still the best"

  Scenario: Reading a decision answers its comments oldest first with their dates
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the database runs:
      """
      insert into decision_comments (decision_id, body, created_at) values
        (1, 'second', '2026-09-01 14:00 America/Chicago'),
        (1, 'first', '2026-09-01 09:00 America/Chicago')
      """
    When I call the API with "GET /api/v1/decisions/1"
    Then the answer's "comments" lists 2
    And the answer matches:
      """
      {"comments": [{"body": "first", "created_at": "2026-09-01T14:00:00Z"}, {"body": "second"}]}
      """
    And the answer includes '"updated_at":"'

  Scenario: Reading a decision answers the records linked to it
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the database runs:
      """
      insert into tasks (title, list, position) values ('Set up Sidekiq', 'next', 1);
      insert into record_links (left_kind, left_id, right_kind, right_id) values ('task', 1, 'decision', 1);
      """
    When I call the API with "GET /api/v1/decisions/1"
    Then the answer matches:
      """
      {"record_links": {"task": [{"kind": "task", "id": 1, "title": "Set up Sidekiq"}]}}
      """

  Scenario: Reading a decision answers the whole timeline, oldest first, each entry with its ID and time
    Given a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    And the database runs:
      """
      insert into decision_events (decision_id, kind, option_id, reason, note, created_at) values
        (1, 'opened', null, null, null, '2026-09-01 08:00 America/Chicago'),
        (1, 'option_added', 1, null, null, '2026-09-01 09:00 America/Chicago'),
        (1, 'resolved', 1, 'It runs today', null, '2026-09-01 11:00 America/Chicago'),
        (1, 'reopened', null, 'Load grew', null, '2026-09-01 12:00 America/Chicago'),
        (1, 'edited', null, null, 'Load grew more', '2026-09-01 13:00 America/Chicago');
      insert into decision_comments (decision_id, body, created_at)
        values (1, 'Ask ops first', '2026-09-01 10:00 America/Chicago');
      """
    When I call the API with "GET /api/v1/decisions/1"
    Then the answer's "timeline" lists 6
    And the answer matches:
      """
      {"timeline": [
        {"kind": "opened", "option_id": null, "reason": null, "note": null},
        {"kind": "option_added", "option_id": 1, "reason": null, "note": null},
        {"kind": "comment", "body": "Ask ops first", "id": 1, "occurred_at": "2026-09-01T15:00:00Z"},
        {"kind": "resolved", "option_id": 1, "reason": "It runs today", "note": null},
        {"kind": "reopened", "option_id": null, "reason": "Load grew", "note": null},
        {"kind": "edited", "option_id": null, "reason": null, "note": "Load grew more"}
      ]}
      """

  Scenario: Reading an unknown decision answers 404
    When I call the API with "GET /api/v1/decisions/999999"
    Then the call answers 404
    And the answer matches:
      """
      {"error": "not_found", "message": "no decision has the ID 999999"}
      """

  Scenario: The MCP tools list, find, read and open decisions as the endpoints do
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    And a decision "Pick a queue" with the problem "Jobs pile up"
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a queue" has the option "Sidekiq"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "It runs today"}
      """
    Then the decision MCP tool "list_decisions" answers as "GET /api/v1/decisions?status=open" does, given:
      """
      {"status": "open"}
      """
    And the decision MCP tool "list_decisions" answers as "GET /api/v1/decisions?query=queue" does, given:
      """
      {"query": "queue"}
      """
    And the decision MCP tool "read_decision" answers as "GET /api/v1/decisions/1" does, given:
      """
      {"id": 1}
      """
    And the decision MCP tool "open_decision" answers as "POST /api/v1/decisions" does but for its stamps, given:
      """
      {"title": "Pick a queue", "problem": "Jobs pile up"}
      """

  Scenario: The MCP tools refuse what the endpoints refuse
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    And a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq"
    And a decision "Pick a host" with the problem "The Pi is slow"
    And the decision "Pick a host" has the option "Fly"
    When I call the MCP tool "read_decision" with:
      """
      {"id": 999999}
      """
    Then it refuses
    And the answer includes "no decision has the ID 999999"
    When I call the MCP tool "resolve_decision" with:
      """
      {"id": 1, "option_id": 2, "reason": "It runs"}
      """
    Then it refuses
    And the answer includes "option_id: pick one of this decision's own options"
    When I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "It runs today"}
      """
    And I call the MCP tool "edit_decision" with:
      """
      {"id": 1, "problem": "Jobs pile up fast"}
      """
    Then it refuses
    And the answer includes "note: a resolved or dropped decision needs a note to say why it changed"
    And the database answers "Jobs pile up" for:
      """
      select problem from decisions where id = 1
      """

  Scenario: The MCP tools tag, untag and comment on a decision
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    And a decision "Pick a queue" with the problem "Jobs pile up"
    When I call the MCP tool "tag_decision" with:
      """
      {"id": 1, "tags": ["queues", "ruby"]}
      """
    And I call the MCP tool "untag_decision" with:
      """
      {"id": 1, "tag": "ruby"}
      """
    Then the answer's "tags" is:
      """
      ["queues"]
      """
    When I call the MCP tool "add_decision_comment" with:
      """
      {"id": 1, "body": "Leaning on Sidekiq"}
      """
    And I call the MCP tool "edit_decision_comment" with:
      """
      {"id": 1, "comment_id": 1, "body": "Resque"}
      """
    Then the answer's "body" is "Resque"
    When I call the MCP tool "delete_decision_comment" with:
      """
      {"id": 1, "comment_id": 1}
      """
    Then the answer matches:
      """
      {"id": 1, "comment_id": 1, "deleted": true}
      """

  Scenario: The decision's task follows its title and closes when it resolves
    When I call the API with "POST /api/v1/decisions" and:
      """
      {"title": "Pick a queue", "problem": "Jobs pile up"}
      """
    And I call the API with "PATCH /api/v1/decisions/1" and:
      """
      {"title": "Pick a job queue"}
      """
    Then the database answers "Resolve decision #1: Pick a job queue, open" for:
      """
      select title, status from tasks where id = 1
      """
    When I call the API with "POST /api/v1/decisions/1/options" and:
      """
      {"title": "Sidekiq"}
      """
    And I call the API with "POST /api/v1/decisions/1/resolve" and:
      """
      {"option_id": 1, "reason": "It runs today"}
      """
    Then the database answers "done" for:
      """
      select status from tasks where id = 1
      """

  Scenario: The decision's task cancels when the decision drops and reopens when it reopens
    When I call the API with "POST /api/v1/decisions" and:
      """
      {"title": "Pick a queue", "problem": "Jobs pile up"}
      """
    And I call the API with "POST /api/v1/decisions/1/drop" and:
      """
      {"reason": "Not needed"}
      """
    Then the database answers "canceled" for:
      """
      select status from tasks where id = 1
      """
    When I call the API with "POST /api/v1/decisions/1/reopen" and:
      """
      {"reason": "Load grew"}
      """
    Then the database answers "open" for:
      """
      select status from tasks where id = 1
      """

  Scenario: The decision's task comes back when I deleted it and the decision reopens
    When I call the API with "POST /api/v1/decisions" and:
      """
      {"title": "Pick a queue", "problem": "Jobs pile up"}
      """
    And I call the API with "POST /api/v1/decisions/1/drop" and:
      """
      {"reason": "Not needed"}
      """
    And I call the API with "DELETE /api/v1/tasks/1"
    And I call the API with "POST /api/v1/decisions/1/reopen" and:
      """
      {"reason": "Load grew"}
      """
    Then the database answers "Resolve decision #1: Pick a queue, open, next" for:
      """
      select t.title, t.status, t.list from tasks t
      join record_links l on l.left_kind = 'task' and l.left_id = t.id and l.relation = 'sourced_from'
      where l.right_kind = 'decision' and l.right_id = 1
      """
