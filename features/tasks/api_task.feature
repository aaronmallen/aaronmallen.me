Feature: Reading one task through the API
  GET /api/v1/tasks/:id answers a task with its comments, links, source, record links and timeline, and finds
  a task by its label.

  Background:
    Given an API token

  Scenario: A task answers with its comments, oldest first, and who wrote each
    Given the tasks:
      | title   |
      | Read me |
      | Other   |
    And the task comments:
      | task    | body      | at          | changed     | author  | url                                                              |
      | Read me | second    | today 14:00 |             |         |                                                                  |
      | Read me | first     | today 09:00 |             |         |                                                                  |
      | Read me | theirs    | today 15:00 | today 16:00 | octocat | https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-1 |
      | Other   | elsewhere | today 09:00 |             |         |                                                                  |
    When I GET "/tasks/{task:Read me}" through the API
    Then the API answer holds:
      """
      {
        "title": "Read me",
        "comments": [
          { "body": "first", "author": "Aaron Allen", "source": "local", "url": null, "created_at": "{at:today 09:00}" },
          { "body": "second" },
          {
            "id": 3,
            "body": "theirs",
            "author": "octocat",
            "source": "github",
            "url": "https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-1",
            "created_at": "{at:today 15:00}",
            "updated_at": "{at:today 16:00}"
          }
        ]
      }
      """
    When I GET "/tasks/{task:Other}" through the API
    Then the API answer holds:
      """
      { "comments": [{ "body": "elsewhere" }] }
      """

  Scenario: A task with no history answers empty comments, record links, timeline and source
    Given a task "Bare"
    When I GET "/tasks/{task:Bare}" through the API
    Then the API answer holds:
      """
      { "comments": [], "record_links": {}, "timeline": [], "source": null, "contributors": [{ "kind": "owner" }] }
      """

  Scenario: A task answers the records linked to it, grouped by kind, as read_task does
    Given a task "Ship it"
    And a published post "On hosting"
    And the database runs:
      """
      INSERT INTO decisions (title, problem) VALUES ('Pick a queue', 'Which queue?');
      INSERT INTO record_links (left_kind, left_id, right_kind, right_id) VALUES ('task', 1, 'decision', 1);
      """
    And the task "Ship it" links the post "On hosting"
    And an MCP client connected with the scopes "read"
    When I GET "/tasks/{task:Ship it}" through the API
    Then the API answer holds:
      """
      {
        "record_links": {
          "post": [{ "kind": "post", "id": 1, "title": "On hosting" }],
          "decision": [{ "kind": "decision", "id": 1, "title": "Pick a queue" }]
        }
      }
      """
    And the API answer to GET "/tasks/{task:Ship it}" matches the MCP tool "read_task" with:
      """
      { "id": {task:Ship it} }
      """

  Scenario: A task answers the issue it syncs from
    Given the tasks:
      | title   |
      | GitHub  |
      | Linear  |
      | Changed |
    And the task sources:
      | task   | url                                                     | state     | seen        |
      | GitHub | https://github.com/aaronmallen/aaronmallen.me/issues/12 | completed | today 09:00 |
      | Linear | https://linear.app/aaron/issue/AA-213/a-slug            |           |             |
    And the database runs:
      """
      UPDATE tasks SET updated_at = now() - interval '3 hours' WHERE title = 'Changed';
      """
    Then the API calls answer:
      | call                      | body | status | holds |
      | GET /tasks/{task:GitHub}  |      | 200    | {"source": {"provider": "github", "remote_state": "completed", "seen_at": "{at:today 09:00}", "url": "https://github.com/aaronmallen/aaronmallen.me/issues/12", "reference": "aaronmallen/aaronmallen.me#12"}} |
      | GET /tasks/{task:Linear}  |      | 200    | {"source": {"provider": "linear", "reference": "aaron/AA-213", "remote_state": "open", "seen_at": null}} |
    And the database answers "true" for:
      """
      SELECT updated_at < now() - interval '2 hours' FROM tasks WHERE title = 'Changed'
      """

  Scenario: A task answers its links from either end, its sprint day and when it closed
    Given the tasks with their times:
      | title    | status   | sprint    | closed |
      | blocker  | open     |           |        |
      | blocked  | open     |           |        |
      | gone     | canceled |           | today 12:00 |
      | freed    | open     |           |        |
      | planned  | open     | today + 2 |        |
    And the task "blocker" blocks the task "blocked"
    And the task "gone" blocks the task "freed"
    Then the API calls answer:
      | call                     | body | status | holds |
      | GET /tasks/{task:blocker} |     | 200    | {"blocked": false, "links": [{"label": "blocks", "title": "blocked"}]} |
      | GET /tasks/{task:blocked} |     | 200    | {"blocked": true, "links": [{"label": "blocked_by", "title": "blocker"}]} |
      | GET /tasks/{task:freed}   |     | 200    | {"blocked": false} |
      | GET /tasks/{task:gone}    |     | 200    | {"status": "canceled", "completed_at": "{at:today 12:00}"} |
      | GET /tasks/{task:planned} |     | 200    | {"sprint_on": "{day:today + 2}"} |

  Scenario: A task answers when it last changed
    Given the tasks with their times:
      | title   | changed     |
      | Changed | today 15:00 |
    When I GET "/tasks/{task:Changed}" through the API
    Then the API answer holds:
      """
      { "updated_at": "{at:today 15:00}" }
      """

  Scenario: A task answers its timeline oldest first, each entry saying what changed
    Given the tasks:
      | title  |
      | Busy   |
      | Timing |
    And the task events:
      | task | kind           | at          | tag   | from_list | to_sprint | from_status | to_status |
      | Busy | untagged       | today 14:00 | money |           |           |             |           |
      | Busy | moved          | today 08:00 |       | next      | today     |             |           |
      | Busy | tagged         | today 09:00 | money |           |           |             |           |
      | Busy | status_changed | today 13:00 |       |           |           | open        | in_progress |
      | Busy | recurred       | today 07:00 |       |           |           |             |           |
    And the task work sessions:
      | task   | from        | until       |
      | Busy   | today 10:00 | today 11:00 |
      | Timing | today - 1 09:00 | today - 1 10:30 |
      | Timing | 10 minutes ago |          |
    And the task comments:
      | task | body   | at          |
      | Busy | a note | today 12:00 |
    When I GET "/tasks/{task:Busy}" through the API
    Then the API answer holds:
      """
      {
        "timeline": [
          { "kind": "recurred", "occurred_at": "{at:today 07:00}" },
          { "kind": "moved", "occurred_at": "{at:today 08:00}", "from_list": "next", "from_sprint_on": null, "to_list": null, "to_sprint_on": "{day:today}" },
          { "kind": "tagged", "occurred_at": "{at:today 09:00}", "tag": "money" },
          { "kind": "session", "occurred_at": "{at:today 10:00}" },
          { "kind": "comment", "id": 1, "occurred_at": "{at:today 12:00}", "body": "a note", "author": "Aaron Allen", "source": "local", "url": null },
          { "kind": "status_changed", "occurred_at": "{at:today 13:00}", "from_status": "open", "to_status": "in_progress" },
          { "kind": "untagged", "occurred_at": "{at:today 14:00}", "tag": "money" }
        ]
      }
      """
    When I GET "/tasks/{task:Timing}" through the API
    Then the API answer holds:
      """
      {
        "timeline": [
          { "kind": "session", "id": 2, "occurred_at": "{at:today - 1 09:00}", "started_at": "{at:today - 1 09:00}", "ended_at": "{at:today - 1 10:30}", "seconds": 5400, "running": false },
          { "kind": "session", "ended_at": null, "running": true }
        ]
      }
      """
    And the running session counts between 600 and 660 seconds

  Scenario: A task answers by its label
    Given the projects:
      | name    | key |
      | Podcast | POD |
      | Compose | COM |
    And the tasks:
      | title  | project |
      | First  | Podcast |
      | Second | Podcast |
      | Loose  |         |
    And an MCP client connected with the scopes "read"
    Then the API calls answer:
      | call            | body | status | holds |
      | GET /tasks/POD-2 |     | 200    | {"id": 2, "label": "POD-2", "title": "Second"} |
      | GET /tasks/pod-1 |     | 200    | {"id": 1, "label": "POD-1"} |
      | GET /tasks/2     |     | 200    | {"id": 2, "label": "POD-2"} |
      | GET /tasks/POD-3 |     | 404    | {"message": "no task has the label POD-3"} |
      | GET /tasks/NOPE-1 |    | 404    | {"message": "no task has the label NOPE-1"} |
      | GET /tasks/POD-  |     | 422    | |
    When I call the MCP tool "read_task" with:
      """
      { "id": "1" }
      """
    Then the MCP answer holds:
      """
      { "id": 3, "label": "1" }
      """
    When I call the MCP tool "read_task" with:
      """
      { "id": "#POD-1" }
      """
    Then the MCP answer holds:
      """
      { "id": 1 }
      """
    When I call the MCP tool "read_task" with:
      """
      { "id": "#1" }
      """
    Then the MCP answer holds:
      """
      { "id": 3 }
      """

  Scenario: A label follows the task when it moves or its project's key changes
    Given the projects:
      | name    | key |
      | Podcast | POD |
      | Compose | COM |
    And the tasks:
      | title  | project |
      | Moved  | Podcast |
      | Stayed | Podcast |
    And the database runs:
      """
      UPDATE tasks SET project_id = (SELECT id FROM projects WHERE key = 'COM') WHERE title = 'Moved';
      UPDATE projects SET key = 'CAST' WHERE key = 'POD';
      """
    Then the API calls answer:
      | call              | body | status | holds |
      | GET /tasks/POD-1  |      | 404    | {"message": "no task has the label POD-1"} |
      | GET /tasks/COM-1  |      | 200    | {"id": 1} |
      | GET /tasks/POD-2  |      | 404    | {"message": "no task has the label POD-2"} |
      | GET /tasks/CAST-2 |      | 200    | {"id": 2, "label": "CAST-2"} |

  Scenario: The task endpoints act and link by label
    Given the projects:
      | name    | key |
      | Podcast | POD |
    And the tasks:
      | title | project |
      | Plain |         |
      | Done  | Podcast |
      | Other | Podcast |
    Then the API calls answer:
      | call                          | body                                 | status | holds |
      | POST /tasks/POD-1/complete    | {}                                   | 200    | {"id": 2, "status": "done"} |
      | POST /tasks/{task:Plain}/links | {"kind": "relates", "other_id": "POD-2"} | 201 | {"links": [{"id": 3, "task_label": "POD-2"}]} |
