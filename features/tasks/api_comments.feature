Feature: Task comments through the API
  The API adds, edits and deletes the owner's own comments on a task, and leaves synced comments alone.

  Background:
    Given an API token
    And the tasks:
      | title  |
      | Review |
      | Other  |
    And the task comments:
      | task   | body              | url                                                                  |
      | Review | Blocked on review |                                                                      |
      | Review | From GitHub       | https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-9 |
      | Other  | Elsewhere         |                                                                      |

  Scenario: Adding a comment stores it trimmed and shows it on the task
    Then the API calls answer:
      | call                           | body                           | status | holds |
      | POST /tasks/{task:Other}/comments | {"body": "  Blocked on deploy  "} | 201 | {"id": 4, "body": "Blocked on deploy", "author": "Aaron Allen", "source": "local", "url": null} |
      | GET /tasks/{task:Other}         |                                | 200    | {"comments": [{"body": "Elsewhere"}, {"body": "Blocked on deploy"}]} |
    And the database reads "Blocked on deploy, " for:
      """
      SELECT body, coalesce(remote_id, '') FROM task_comments WHERE id = 4
      """
    And the API answer has the comment's stamps as the database does

  Scenario: Adding a comment refuses a body it cannot store and adds nothing
    Then the API calls answer:
      | call                             | body                    | status | holds |
      | POST /tasks/{task:Other}/comments | {"body": "   "}         | 422    | {"error": "invalid", "message": "body: write the comment first", "errors": {"body": ["write the comment first"]}} |
      | POST /tasks/{task:Other}/comments | {"body": " "}      | 422    | {"errors": {"body": ["write the comment first"]}} |
      | POST /tasks/{task:Other}/comments | {"body": "bad\u0000body"} | 422  | {"errors": {"body": ["holds a control character"]}} |
      | POST /tasks/{task:Other}/comments | {}                      | 422    | {"errors": {"body": ["body is missing"]}} |
      | POST /tasks/999999/comments       | {"body": "Hello"}       | 404    | {"error": "not_found", "message": "no task has the ID 999999"} |
    And the database holds 3 task_comments rows

  Scenario: Editing a comment replaces its body and leaves synced and other comments alone
    Then the API calls answer:
      | call                                | body                            | status | holds |
      | PATCH /tasks/{task:Review}/comments/1 | {"body": " "}                  | 422    | {"errors": {"body": ["write the comment first"]}} |
      | PATCH /tasks/{task:Review}/comments/2 | {"body": "Mine"}               | 404    | {"error": "not_found", "message": "task 1 has no comment with the ID 2"} |
      | PATCH /tasks/{task:Review}/comments/3 | {"body": "Mine"}               | 404    | |
      | PATCH /tasks/{task:Review}/comments/1 | {"body": "  Blocked on deploy  "} | 200 | {"id": 1, "body": "Blocked on deploy", "author": "Aaron Allen", "source": "local", "url": null} |
    And the API answer has the comment's stamps as the database does
    And the database reads "Blocked on deploy / From GitHub / Elsewhere" for:
      """
      SELECT body FROM task_comments ORDER BY id
      """

  Scenario: Deleting a comment removes it and leaves synced and other comments alone
    Then the API calls answer:
      | call                                 | body | status | holds |
      | DELETE /tasks/{task:Review}/comments/2 |    | 404    | {"error": "not_found", "message": "task 1 has no comment with the ID 2"} |
      | DELETE /tasks/{task:Review}/comments/3 |    | 404    | |
      | DELETE /tasks/{task:Review}/comments/1 |    | 200    | {"id": 1, "comment_id": 1, "deleted": true} |
    And the database reads "From GitHub / Elsewhere" for:
      """
      SELECT body FROM task_comments ORDER BY id
      """

  Scenario: A comment pasted with Windows line endings saves the same body on a task and a decision
    Given the database runs:
      """
      INSERT INTO decisions (title, problem) VALUES ('Pick a queue', 'Which queue?');
      INSERT INTO decision_comments (decision_id, body) VALUES (1, 'Blocked');
      """
    When I POST "/tasks/{task:Other}/comments" through the API with:
      """
      { "body": "Blocked\r\non review\rtoday\r\n" }
      """
    And I POST "/decisions/1/comments" through the API with:
      """
      { "body": "Blocked\r\non review\rtoday\r\n" }
      """
    And I PATCH "/tasks/{task:Review}/comments/1" through the API with:
      """
      { "body": "Blocked\r\non review\rtoday\r\n" }
      """
    And I PATCH "/decisions/1/comments/1" through the API with:
      """
      { "body": "Blocked\r\non review\rtoday\r\n" }
      """
    Then the database reads "Blocked|on review|today / Blocked|on review|today / Blocked|on review|today / Blocked|on review|today" for:
      """
      SELECT replace(body, E'\n', '|') FROM task_comments WHERE id IN (1, 4)
      UNION ALL SELECT replace(body, E'\n', '|') FROM decision_comments
      """

  Scenario: The comment tools answer as the comment endpoints do
    Given the task comments:
      | task   | body   |
      | Review | second |
    And an MCP client connected with the scopes "read write delete"
    When I POST "/tasks/{task:Review}/comments" through the API with:
      """
      { "body": "the same" }
      """
    Then the MCP tool "add_task_comment" answers as the API did, apart from "id, created_at, updated_at", with:
      """
      { "id": {task:Other}, "body": "the same" }
      """
    When I POST "/tasks/{task:Review}/comments" through the API with:
      """
      { "body": " " }
      """
    Then the MCP tool "add_task_comment" answers as the API did, apart from "", with:
      """
      { "id": {task:Review}, "body": " " }
      """
    When I PATCH "/tasks/{task:Review}/comments/1" through the API with:
      """
      { "body": "the same" }
      """
    Then the MCP tool "edit_task_comment" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Review}, "comment_id": 1, "body": "the same" }
      """
    When I PATCH "/tasks/{task:Review}/comments/2" through the API with:
      """
      { "body": "Mine" }
      """
    Then the MCP tool "edit_task_comment" answers as the API did, apart from "", with:
      """
      { "id": {task:Review}, "comment_id": 2, "body": "Mine" }
      """
    When I DELETE "/tasks/{task:Review}/comments/2" through the API
    Then the MCP tool "delete_task_comment" answers as the API did, apart from "", with:
      """
      { "id": {task:Review}, "comment_id": 2 }
      """
    When I DELETE "/tasks/{task:Review}/comments/1" through the API
    Then the MCP tool "delete_task_comment" answers as the API did, apart from "comment_id", with:
      """
      { "id": {task:Review}, "comment_id": 4 }
      """
