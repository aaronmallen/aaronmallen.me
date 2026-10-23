Feature: MCP agent record links
  Memory files and artifacts link to other records like any record, and only a connection with agents sees them.

  Background:
    Given the task "Index the activities table"

  Scenario: A memory file and an artifact link to a task, with their titles marked, and read_task shows the links
    Given an MCP client connected with the scopes "read write agents delete"
    When before it I call 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'create_artifact {"title": "Index plan", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'link_records {"kind": "memory_file", "id": 1, "other_kind": "task", "other_id": 1}'
    And before it I call 'link_records {"kind": "task", "id": 1, "other_kind": "artifact", "other_id": 1}'
    And I call the MCP tool "list_links" with:
      """
      { "kind": "task", "id": 1 }
      """
    Then the MCP tool answer at "links" matches:
      """
      {
        "memory_file": [{ "title": { "untrusted": true, "text": "hanami.md" } }],
        "artifact": [{ "title": { "untrusted": true, "text": "Index plan" } }]
      }
      """
    And the MCP tool answer at "links.memory_file.length" is "1"
    And the MCP tool answer at "links.artifact.length" is "1"
    When I call the MCP tool "read_task" with:
      """
      { "id": 1 }
      """
    Then the MCP tool answer at "record_links.artifact.0.id" is "1"

  Scenario: An artifact links to another artifact and to a commit
    Given an MCP client connected with the scopes "read write agents delete"
    And the database runs:
      """
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time, additions, deletions)
      VALUES (repeat('a', 40), 'aaronmallen/aaronmallen.me', 'main', 'Index it', current_date, '09:00', 1, 1)
      """
    When before it I call 'create_artifact {"title": "Index plan", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'create_artifact {"title": "Handoff", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'link_records {"kind": "artifact", "id": 1, "other_kind": "artifact", "other_id": 2}'
    And before it I call 'link_records {"kind": "artifact", "id": 1, "other_kind": "commit", "other_id": 1}'
    And I call the MCP tool "list_links" with:
      """
      { "kind": "artifact", "id": 1 }
      """
    Then the "id" of each row at "links.artifact" in the MCP tool answer, read as text, are:
      """
      [2]
      """
    And the "id" of each row at "links.commit" in the MCP tool answer, read as text, are:
      """
      [1]
      """

  Scenario: Deleting a memory file or an artifact removes its links
    Given an MCP client connected with the scopes "read write agents delete"
    When before it I call 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "global", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'create_artifact {"title": "Index plan", "type": "plan", "body": "## Steps", "agent": "claude-code", "model": "claude-opus-5-5"}'
    And before it I call 'link_records {"kind": "memory_file", "id": 1, "other_kind": "task", "other_id": 1}'
    And before it I call 'link_records {"kind": "artifact", "id": 1, "other_kind": "task", "other_id": 1}'
    And before it I call 'delete_memory_file {"id": 1}'
    And before it I call 'delete_artifact {"id": 1}'
    And I call the MCP tool "list_links" with:
      """
      { "kind": "task", "id": 1 }
      """
    Then the MCP tool answer at "links" is "{}"
    And the table record_links holds 0 rows

  Scenario: A file scoped to a task shows a link to it from both sides, refuses an unlink and a second link
    Given an MCP client connected with the scopes "read write agents delete"
    When before it I call 'create_memory_file {"path": "hanami", "description": "Notes", "scope": "task", "task_id": 1, "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I call the MCP tool "list_links" with:
      """
      { "kind": "task", "id": 1 }
      """
    Then the MCP tool answer at "links.memory_file.0.id" is "1"
    When I call the MCP tool "list_links" with:
      """
      { "kind": "memory_file", "id": 1 }
      """
    Then the MCP tool answer at "links.task.0.id" is "1"
    When I call the MCP tool "unlink_records" with:
      """
      { "kind": "task", "id": 1, "other_kind": "memory_file", "other_id": 1 }
      """
    Then the MCP tool refuses with "other_id: this memory file is scoped to that record, so change its scope instead"
    When I call the MCP tool "link_records" with:
      """
      { "kind": "memory_file", "id": 1, "other_kind": "task", "other_id": 1 }
      """
    Then the MCP tool refuses with "other_id: these two records are already linked"
    And the table record_links holds 0 rows
    When I call the MCP tool "list_links" with:
      """
      { "kind": "task", "id": 1 }
      """
    Then the MCP tool answer at "links.memory_file.0.id" is "1"

  Scenario: A file scoped to a project shows a link to it
    Given an MCP client connected with the scopes "read write agents delete"
    And the project "Blog"
    When before it I call 'create_memory_file {"path": "rails", "description": "Notes", "scope": "project", "project_id": 1, "agent": "claude-code", "model": "claude-opus-5-5"}'
    And I call the MCP tool "list_links" with:
      """
      { "kind": "project", "id": 1 }
      """
    Then the MCP tool answer at "links.memory_file.0.id" is "1"

  Scenario: A connection without agents is refused a link to an artifact, and sees no linked memory file or artifact
    Given an MCP client connected with the scopes "read write delete"
    And the table artifacts holds:
      | title      | type |
      | Index plan | plan |
    When I call the MCP tool "link_records" with:
      """
      { "kind": "task", "id": 1, "other_kind": "artifact", "other_id": 1 }
      """
    Then the MCP tool refuses with "this endpoint needs a token with the agents scope"
    And the table record_links holds 0 rows
    Given the table record_links holds:
      | left_kind | left_id | right_kind | right_id |
      | task      | 1       | artifact   | 1        |
    And the table memory_files holds:
      | path      | description | scope | task_id |
      | hanami.md | Notes       | task  | 1       |
    When I call the MCP tool "list_links" with:
      """
      { "kind": "task", "id": 1 }
      """
    Then the MCP tool answer at "links" is "{}"
    When I call the MCP tool "read_task" with:
      """
      { "id": 1 }
      """
    Then the MCP tool answer at "record_links" is "{}"
