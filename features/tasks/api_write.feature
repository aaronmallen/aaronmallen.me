Feature: Writing tasks through the API
  The API captures, saves, deletes, starts, closes, schedules, moves, stages and reorders tasks, and refuses
  what it cannot store.

  Background:
    Given an API token

  Scenario: Capturing a task stores what it names
    Given the photo "0123456789abcdef0123456789abcdef.jpg" uploaded 1 days ago
    Then the API calls answer:
      | call        | body                                                                   | status | holds |
      | POST /tasks | {"title": "Email the accountant", "tags": ["admin", "money"]}          | 201    | {"title": "Email the accountant", "list": "next", "stage": "backlog", "tags": ["admin", "money"]} |
      | POST /tasks | {"title": "Plan Q3", "note": "Ask about **Q3**"}                       | 201    | {"note": "Ask about **Q3**"} |
      | POST /tasks | {"title": "Later", "sprint_on": "{day:today + 3}"}                     | 201    | {"sprint_on": "{day:today + 3}"} |
      | POST /tasks | {"title": "Ship it", "list": "today"}                                  | 201    | {"list": null, "sprint_on": "{day:today}"} |
      | POST /tasks | {"title": "Email the accountant #admin"}                               | 201    | {"title": "Email the accountant #admin", "tags": []} |
      | POST /tasks | {"title": "Fix the gutter", "note": "![The gutter](/media/0123456789abcdef0123456789abcdef.jpg)"}    | 201    | {"id": 6} |
    And the database answers "task, 6, 1" for:
      """
      SELECT owner, owner_id, photo_id FROM photo_claims
      """

  Scenario: Capturing a task refuses what it cannot store and captures nothing
    Given the projects:
      | name | key  | archived  | started    |
      | Gone | GONE | today - 1 | today - 30 |
    Then the API calls answer:
      | call        | body                                                       | status | holds |
      | POST /tasks | {"title": "  "}                                            | 422    | {"error": "invalid", "message": "title: write the task down first", "errors": {"title": ["write the task down first"]}} |
      | POST /tasks | {"tags": ["admin"]}                                        | 422    | {"errors": {"title": ["title is missing"]}} |
      | POST /tasks | {"title": "Bad", "note": "bad\u0000note"}                  | 422    | {"errors": {"note": ["holds a control character"]}} |
      | POST /tasks | {"title": "Too late", "sprint_on": "{day:today - 1}"}      | 422    | {"errors": {"sprint_on": ["a sprint opens on today or a day after it"]}} |
      | POST /tasks | {"title": "Someday", "sprint_on": "next week"}             | 422    | {"errors": {"sprint_on": ["give sprint_on as a day, such as 2026-01-01"]}} |
      | POST /tasks | {"title": "Lost", "list": "nowhere"}                       | 422    | "list" |
      | POST /tasks | {"title": "Bad tag", "tags": ["not_a_tag"]}                | 422    | {"errors": {"tags": ["a tag is lowercase words joined by hyphens"]}} |
      | POST /tasks | {"title": "Record the intro", "project": "NOPE"}           | 422    | "project" |
      | POST /tasks | {"title": "Record the intro", "project": "GONE"}           | 422    | "project" |
      | POST /tasks | {"title": "Record the intro", "project": "no way"}         | 422    | "project" |
    And the database holds 0 tasks rows

  Scenario: A body that is not JSON gets a 400
    When I POST "/tasks" through the API with a body of "{nope"
    Then the API answers 400
    And the API answer holds:
      """
      { "error": "invalid_json", "message": "the body takes a JSON object" }
      """

  Scenario: Capturing into a project numbers the task there
    Given the projects:
      | name    | key |
      | Podcast | POD |
    Then the API calls answer:
      | call        | body                                               | status | holds |
      | POST /tasks | {"title": "First"}                                 | 201    | {"label": "1"} |
      | POST /tasks | {"title": "Record the intro", "project": "POD"}    | 201    | {"label": "POD-1"} |
      | POST /tasks | {"title": "Record the outro", "project": "pod"}    | 201    | {"label": "POD-2"} |
      | POST /tasks | {"title": "Second"}                                | 201    | {"label": "2"} |

  Scenario: Saving a task changes what it names and keeps the rest
    Given the tasks:
      | title | note     | tags  |
      | Draft | the plan | admin |
    And the tasks:
      | title  | sprint    |
      | Later  | today + 2 |
      | Pulled | today + 2 |
    Then the API calls answer:
      | call                      | body                                                     | status | holds |
      | PATCH /tasks/{task:Draft}  | {"title": "Final"}                                      | 200    | {"title": "Final", "note": "the plan", "tags": ["admin"]} |
      | PATCH /tasks/{task:Final}  | {"tags": ["site", "ruby"]}                              | 200    | {"tags": ["ruby", "site"]} |
      | PATCH /tasks/{task:Final}  | {"list": "someday"}                                     | 200    | {"list": "someday"} |
      | PATCH /tasks/{task:Final}  | {"sprint_on": "{day:today + 2}"}                        | 200    | {"sprint_on": "{day:today + 2}"} |
      | PATCH /tasks/{task:Pulled} | {"list": "today"}                                       | 200    | {"sprint_on": "{day:today}"} |
      | PATCH /tasks/{task:Later}  | {"list": "today", "sprint_on": "{day:today + 2}"}       | 200    | {"sprint_on": "{day:today + 2}"} |

  Scenario: Saving a task refuses what it cannot store and keeps the old title
    Given the tasks:
      | title | tags  |
      | Draft | admin |
    And the tasks with their times:
      | title  | status | closed      |
      | Closed | done   | today 08:00 |
    Then the API calls answer:
      | call                      | body                                                   | status | holds |
      | PATCH /tasks/{task:Draft}  | {"title": ""}                                         | 422    | |
      | PATCH /tasks/{task:Draft}  | {"title": "　"}                                   | 422    | {"errors": {"title": ["write the task down first"]}} |
      | PATCH /tasks/{task:Draft}  | {"note": "bad\u0000note"}                             | 422    | {"errors": {"note": ["holds a control character"]}} |
      | PATCH /tasks/{task:Draft}  | {"tags": ["two words!"]}                              | 422    | {"errors": {"tags": ["a tag is lowercase words joined by hyphens"]}} |
      | PATCH /tasks/{task:Draft}  | {"title": "Final", "sprint_on": "{day:today - 1}"}    | 422    | "sprint_on" |
      | PATCH /tasks/{task:Draft}  | {"title": "Final", "sprint_on": "next week"}          | 422    | {"errors": {"sprint_on": ["give sprint_on as a day, such as 2026-01-01"]}} |
      | PATCH /tasks/{task:Closed} | {"title": "Final", "sprint_on": "{day:today + 3}"}    | 422    | {"message": "task 2 is already done or canceled"} |
    And the database reads "Draft,  / Closed, " for:
      """
      SELECT title, sprint_id FROM tasks ORDER BY id
      """

  Scenario: Saving a task sets who worked on it
    Given a task "Draft"
    Then the API calls answer:
      | call                      | body | status | holds |
      | GET /tasks/{task:Draft}    |      | 200    | {"contributors": [{"kind": "owner"}]} |
      | PATCH /tasks/{task:Draft}  | {"contributors": [{"kind": "agent", "agent": "claude-code", "model": "claude-opus-5-5"}]} | 200 | {"contributors": [{"kind": "agent", "agent": "claude-code", "model": "claude-opus-5-5"}]} |
      | GET /tasks/{task:Draft}    |      | 200    | {"contributors": [{"kind": "agent", "agent": "claude-code", "model": "claude-opus-5-5"}]} |
      | PATCH /tasks/{task:Draft}  | {"title": "Final"}                                     | 200 | {"contributors": [{"kind": "agent"}]} |
      | PATCH /tasks/{task:Final}  | {"contributors": [{"kind": "agent", "agent": "claude-code"}]} | 422 | "contributors" |
      | PATCH /tasks/{task:Final}  | {"contributors": [{"kind": "owner", "model": "claude-opus-5-5"}]} | 422 | |
      | PATCH /tasks/{task:Final}  | {"contributors": [{"kind": "agent", "agent": "Claude Code", "model": "claude-opus-5-5"}]} | 422 | |
      | PATCH /tasks/{task:Final}  | {"contributors": [{"kind": "human"}]}                  | 422 | |
      | GET /tasks/{task:Final}    |      | 200    | {"contributors": [{"kind": "agent", "agent": "claude-code", "model": "claude-opus-5-5"}]} |
      | PATCH /tasks/{task:Final}  | {"contributors": [{"kind": "owner"}, {"kind": "agent", "agent": "claude-code", "model": "claude-opus-5-5"}]} | 200 | {"contributors": [{"kind": "owner"}, {"kind": "agent"}]} |
      | PATCH /tasks/{task:Final}  | {"contributors": [{"kind": "agent", "agent": "codex", "model": "gpt-6"}, {"kind": "agent", "agent": "codex", "model": "gpt-6"}]} | 200 | {"contributors": [{"kind": "agent", "agent": "codex", "model": "gpt-6"}]} |
      | PATCH /tasks/{task:Final}  | {"contributors": []}                                   | 200 | {"contributors": [{"kind": "owner"}]} |
    And the database answers "0" for:
      """
      SELECT count(*) FROM task_contributors
      """

  Scenario: Deleting a task removes it
    Given a task "Gone"
    When I DELETE "/tasks/{task:Gone}" through the API
    Then the API answers 200
    And the API answer holds:
      """
      { "id": 1, "title": "Gone", "deleted": true }
      """
    And the database holds 0 tasks rows

  Scenario: The status endpoints start, close and reopen a task
    Given the tasks with their times:
      | title    | status      | closed      |
      | Start    | open        |             |
      | Complete | open        |             |
      | Cancel   | open        |             |
      | Doing    | in_progress |             |
      | Finished | done        | today 08:00 |
      | Dropped  | canceled    | today 08:00 |
    Then the API calls answer:
      | call                               | body | status | holds |
      | POST /tasks/{task:Start}/start      | {}   | 200    | {"status": "in_progress", "sprint_on": "{day:today}"} |
      | POST /tasks/{task:Complete}/complete | {}  | 200    | {"status": "done"} |
      | POST /tasks/{task:Cancel}/cancel    | {}   | 200    | {"status": "canceled"} |
      | POST /tasks/{task:Doing}/cancel     | {}   | 200    | "completed_at":"20 |
      | POST /tasks/{task:Finished}/cancel  | {}   | 422    | {"errors": {"id": ["task 5 is already done or canceled"]}} |
      | POST /tasks/{task:Finished}/complete | {}  | 422    | {"errors": {"id": ["task 5 is already done or canceled"]}} |
      | POST /tasks/{task:Dropped}/cancel   | {}   | 422    | {"errors": {"id": ["task 6 is already done or canceled"]}} |
      | POST /tasks/{task:Dropped}/complete | {}   | 422    | {"errors": {"id": ["task 6 is already done or canceled"]}} |
    And the database reads "done, true / canceled, true" for:
      """
      SELECT status, completed_at = '{at:today 08:00}' FROM tasks WHERE title IN ('Finished', 'Dropped') ORDER BY id
      """
    And the API calls answer:
      | call                               | body | status | holds |
      | POST /tasks/{task:Finished}/reopen  | {}   | 200    | {"status": "open", "completed_at": null} |
      | POST /tasks/{task:Dropped}/reopen   | {}   | 200    | {"status": "open", "completed_at": null} |

  Scenario: Scheduling a task sets its sprint day
    Given the tasks:
      | title     | sprint    | status   |
      | Plain     |           | open     |
      | Scheduled | today + 1 | open     |
      | Finished  |           | done     |
      | Dropped   |           | canceled |
    Then the API calls answer:
      | call                                 | body                                  | status | holds |
      | POST /tasks/{task:Plain}/schedule     | {"sprint_on": "{day:today + 1}"}      | 200    | {"sprint_on": "{day:today + 1}"} |
      | POST /tasks/{task:Scheduled}/schedule | {"sprint_on": ""}                     | 200    | {"list": "next", "sprint_on": null} |
      | POST /tasks/{task:Plain}/schedule     | {"sprint_on": "{day:today - 1}"}      | 422    | {"message": "a sprint opens on today or a day after it"} |
      | POST /tasks/{task:Plain}/schedule     | {"sprint_on": "tomorrow"}             | 422    | {"errors": {"sprint_on": ["give sprint_on as a day, such as 2026-01-01"]}} |
      | POST /tasks/{task:Plain}/schedule     | {}                                    | 422    | {"errors": {"sprint_on": ["sprint_on is missing"]}} |
      | POST /tasks/{task:Finished}/schedule  | {"sprint_on": "{day:today + 3}"}      | 422    | {"message": "task 3 is already done or canceled"} |
      | POST /tasks/{task:Dropped}/schedule   | {"sprint_on": "{day:today + 3}"}      | 422    | {"message": "task 4 is already done or canceled"} |
    And the database reads "0" for:
      """
      SELECT count(*) FROM sprints WHERE sprint_date = '{day:today + 3}'
      """
    And the database answers "2" for:
      """
      SELECT count(*) FROM tasks WHERE status IN ('done', 'canceled') AND sprint_id IS NULL
      """

  Scenario: Marking a synced task seen stamps it and leaves it in its list
    Given the tasks:
      | title  | list     |
      | Synced | external |
      | Local  | next     |
    And the task sources:
      | task   | url                                                    |
      | Synced | https://github.com/aaronmallen/aaronmallen.me/issues/3 |
    Then the API calls answer:
      | call                          | body | status | holds |
      | POST /tasks/{task:Synced}/seen | {}  | 200    | {"id": 1, "list": "external"} |
      | GET /tasks/{task:Synced}       |     | 200    | {"timeline": []} |
      | POST /tasks/{task:Local}/seen  | {}  | 422    | {"errors": {"id": ["task 2 has no synced issue to mark seen"]}} |
    And the database answers "true" for:
      """
      SELECT seen_at BETWEEN now() - interval '1 minute' AND now() FROM task_sources
      """

  Scenario: Moving and staging a task
    Given the tasks:
      | title    | list | sprint | status      |
      | Plain    | next |        | open        |
      | Today    |      |        | open        |
      | Doing    |      | today  | in_progress |
      | Started  | next |        | in_progress |
      | Finished | next |        | done        |
      | Dropped  | next |        | canceled    |
    Then the API calls answer:
      | call                              | body                   | status | holds |
      | POST /tasks/{task:Plain}/move      | {"list": "someday"}    | 200    | {"list": "someday"} |
      | POST /tasks/{task:Plain}/move      | {"list": "nowhere"}    | 422    | "list" |
      | POST /tasks/{task:Today}/move      | {"list": "today"}      | 200    | {"list": null, "sprint_on": "{day:today}"} |
      | POST /tasks/{task:Doing}/move      | {"list": "someday"}    | 200    | {"list": "someday", "status": "open"} |
      | POST /tasks/{task:Plain}/stage     | {"stage": "ready"}     | 200    | {"stage": "ready"} |
      | POST /tasks/{task:Started}/stage   | {"stage": "ready"}     | 200    | {"stage": "ready", "status": "in_progress"} |
      | POST /tasks/{task:Plain}/stage     | {"stage": "doing"}     | 422    | "stage" |
      | POST /tasks/{task:Finished}/stage  | {"stage": "ready"}     | 422    | {"errors": {"id": ["task 5 is already done or canceled"]}} |
      | POST /tasks/{task:Dropped}/stage   | {"stage": "ready"}     | 422    | {"errors": {"id": ["task 6 is already done or canceled"]}} |
      | GET /tasks/{task:Plain}            |                        | 200    | {"stage": "ready"} |
      | GET /tasks?statuses=in_progress    |                        | 200    | {"tasks": [{"title": "Started", "stage": "ready"}]} |
    And the database reads "backlog / backlog" for:
      """
      SELECT stage FROM tasks WHERE status IN ('done', 'canceled') ORDER BY id
      """

  Scenario: Reordering a task moves it past its neighbour
    Given the tasks:
      | title  | position |
      | first  | 1        |
      | second | 2        |
    Then the API calls answer:
      | call                             | body                    | status | holds |
      | POST /tasks/{task:second}/reorder | {"direction": "up"}     | 200    | {"moved": true} |
      | POST /tasks/{task:second}/reorder | {"direction": "up"}     | 200    | {"moved": false} |
      | POST /tasks/{task:first}/reorder  | {"direction": "sideways"} | 422  | "direction" |
    And the next list reads "second, first"
    And the API calls answer:
      | call                             | body                    | status | holds |
      | POST /tasks/{task:second}/reorder | {"direction": "down"}   | 200    | {"moved": true} |
    And the next list reads "first, second"

  Scenario: Reordering a task past one that shares its position
    Given the tasks:
      | title  | position |
      | first  | 1        |
      | second | 2        |
      | tied   | 2        |
    When I POST "/tasks/{task:tied}/reorder" through the API with:
      """
      { "direction": "up" }
      """
    Then the next list reads "first, tied, second"

  Scenario: Reordering leaves a closed task where it is
    Given the tasks:
      | title    | position | status   |
      | first    | 1        | open     |
      | second   | 2        | open     |
      | finished | 3        | done     |
      | dropped  | 4        | canceled |
    Then the API calls answer:
      | call                               | body                | status | holds |
      | POST /tasks/{task:finished}/reorder | {"direction": "up"} | 200    | {"moved": false} |
      | POST /tasks/{task:dropped}/reorder  | {"direction": "up"} | 200    | {"moved": false} |
      | POST /tasks/{task:finished}/reorder | {"after_id": null}  | 200    | {"moved": false} |
    And the database reads "first / second / finished / dropped" for:
      """
      SELECT title FROM tasks ORDER BY position, id
      """

  Scenario: Reordering within a sprint
    Given the tasks:
      | title      | sprint | position |
      | sprint one | today  | 3        |
      | sprint two | today  | 4        |
    When I POST "/tasks/{task:sprint two}/reorder" through the API with:
      """
      { "direction": "up" }
      """
    Then the database reads "sprint two / sprint one" for:
      """
      SELECT title FROM tasks ORDER BY position, id
      """

  Scenario: Reordering by after_id places the task after another
    Given the tasks:
      | title     | position | list    | sprint    |
      | first     | 1        | next    |           |
      | second    | 2        | next    |           |
      | third     | 3        | next    |           |
      | elsewhere | 4        | someday |           |
      | held      | 5        |         | today     |
      | later     | 6        |         | today + 1 |
    Then the API calls answer:
      | call                             | body                            | status | holds |
      | POST /tasks/{task:third}/reorder  | {"after_id": {task:first}}      | 200    | {"moved": true} |
      | POST /tasks/{task:second}/reorder | {"after_id": {task:elsewhere}}  | 422    | {"errors": {"after_id": ["task 4 is not in task 2's list or sprint"]}} |
      | POST /tasks/{task:later}/reorder  | {"after_id": {task:held}}       | 422    | {"errors": {"after_id": ["task 5 is not in task 6's list or sprint"]}} |
      | POST /tasks/{task:first}/reorder  | {"after_id": 999999}            | 404    | {"error": "not_found", "message": "no task has the ID 999999"} |
      | POST /tasks/{task:second}/reorder | {"direction": "up", "after_id": null} | 422 | {"errors": {"input": ["give either direction or after_id, not both"]}} |
      | POST /tasks/{task:second}/reorder | {}                              | 422    | {"errors": {"input": ["give either direction or after_id, not both"]}} |
    And the next list reads "first, third, second"
    And the API calls answer:
      | call                             | body                | status | holds |
      | POST /tasks/{task:second}/reorder | {"after_id": null}  | 200    | {"position": 1} |
    And the next list reads "second, first, third"

  Scenario: The task tools answer as the task endpoints do
    Given the tasks:
      | title  | tags  | list     | status |
      | Draft  | admin | next     | open   |
      | same   |       | next     | open   |
      | same   |       | next     | open   |
      | Reopen | ruby  | next     | done   |
      | Reopen | ruby  | next     | done   |
    And an MCP client connected with the scopes "read write delete"
    When I POST "/tasks/{task:Draft}/stage" through the API with:
      """
      { "stage": "ready" }
      """
    Then the MCP tool "stage_task" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Draft}, "stage": "ready" }
      """
    When I PATCH "/tasks/{task:Draft}" through the API with:
      """
      { "title": "Final", "note": "done looks like this" }
      """
    Then the MCP tool "save_task" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Final}, "title": "Final", "note": "done looks like this" }
      """
    When I PATCH "/tasks/{task:Final}" through the API with:
      """
      { "contributors": [{ "kind": "agent", "agent": "claude-code", "model": "claude-opus-5-5" }] }
      """
    Then the MCP tool "save_task" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Final}, "contributors": [{ "kind": "agent", "agent": "claude-code", "model": "claude-opus-5-5" }] }
      """
    When I POST "/tasks/{task:Final}/schedule" through the API with:
      """
      { "sprint_on": "{day:today + 2}" }
      """
    Then the MCP tool "schedule_task" answers as the API did, apart from "updated_at, created_at", with:
      """
      { "id": {task:Final}, "sprint_on": "{day:today + 2}" }
      """
    When I POST "/tasks/{task:Final}/move" through the API with:
      """
      { "list": "external" }
      """
    Then the MCP tool "move_task" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Final}, "list": "external" }
      """
    When I POST "/tasks/{task:Final}/reorder" through the API with:
      """
      { "direction": "up" }
      """
    Then the MCP tool "reorder_task" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Final}, "direction": "up" }
      """
    When I POST "/tasks/{task:Final}/reorder" through the API with:
      """
      { "after_id": null }
      """
    Then the MCP tool "reorder_task" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Final}, "after_id": null }
      """
    When I POST "/tasks/4/reopen" through the API with:
      """
      {}
      """
    Then the MCP tool "reopen_task" answers as the API did, apart from "id, label, number, position, created_at, updated_at, timeline", with:
      """
      { "id": 5 }
      """
    And the API answer to GET "/tasks/{task:Reopen}" matches the MCP tool "read_task" with:
      """
      { "id": {task:Reopen} }
      """
    And the API answer to GET "/tasks?statuses=open,done" matches the MCP tool "list_tasks" with:
      """
      { "statuses": ["open", "done"] }
      """
    And the API answer to GET "/tasks?lists=next&tag=ruby&query=label:ruby%20is:closed%20nowhere:yet" matches the MCP tool "list_tasks" with:
      """
      { "lists": ["next"], "tag": "ruby", "query": "label:ruby is:closed nowhere:yet" }
      """

  Scenario Outline: A status tool answers as its endpoint does
    Given the tasks:
      | title |
      | same  |
      | same  |
    And an MCP client connected with the scopes "read write"
    When I POST "/tasks/1/<verb>" through the API with:
      """
      {}
      """
    Then the MCP tool "<verb>_task" answers as the API did, apart from "id, label, position, completed_at, created_at, updated_at, timeline", with:
      """
      { "id": 2 }
      """

    Examples:
      | verb     |
      | start    |
      | complete |
      | cancel   |

  Scenario: The write tools answer as the endpoints do
    Given the tasks:
      | title  | list     |
      | same   | next     |
      | same   | next     |
      | Synced | external |
    And the task sources:
      | task   | url                                                    |
      | Synced | https://github.com/aaronmallen/aaronmallen.me/issues/3 |
    And an MCP client connected with the scopes "read write delete"
    When I POST "/tasks" through the API with:
      """
      { "title": "the same", "list": "someday", "tags": ["ruby"] }
      """
    Then the MCP tool "capture_task" answers as the API did, apart from "id, label, number, position, created_at, updated_at", with:
      """
      { "title": "the same", "list": "someday", "tags": ["ruby"] }
      """
    When I POST "/tasks" through the API with:
      """
      { "title": " " }
      """
    Then the MCP tool "capture_task" answers as the API did, apart from "", with:
      """
      { "title": " " }
      """
    When I POST "/tasks/{task:Synced}/seen" through the API with:
      """
      {}
      """
    Then the MCP tool "mark_task_seen" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Synced} }
      """
    When I DELETE "/tasks/1" through the API
    Then the MCP tool "delete_task" answers as the API did, apart from "id", with:
      """
      { "id": 2 }
      """
