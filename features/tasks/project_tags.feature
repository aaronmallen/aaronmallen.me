Feature: Tags on project tasks
  A task in a project carries that project's tags. The admin links them to the project's tag pages, and the
  task tools make, move and drop them as the task's project changes.

  Background:
    Given the projects:
      | name    | key  |
      | Podcast | POD  |
      | Blog    | BLOG |
    And the tasks:
      | title            | project |
      | Record the intro | Podcast |
      | Loose            |         |
    And the tags table holds the rows:
      | name  | color     | scope   | project_id | description |
      | audio | mk-violet | project | 1          | Sound work  |
      | video | mk-green  | project | 1          |             |
      | video | mk-sand   | project | 2          |             |
      | home  | mk-blue   | private |            |             |

  Scenario: The admin links a project tag to the project's tag page and offers only the project's tags
    Given I am signed in to the admin
    And the task_tags table holds the rows:
      | task_id | tag_id | tag_scope |
      | 1       | 1      | project   |
    When I visit "/admin/tasks/{task:Record the intro}"
    Then the page part "a:text-is('#audio')" has "href" set to "/admin/projects/POD/tags/audio"
    When I visit "/admin/projects/1"
    Then the page part ".kc:has-text('Record the intro') a:text-is('#audio')" has "href" set to "/admin/projects/POD/tags/audio"
    When I visit "/admin/tasks/{task:Record the intro}/edit"
    Then the page part "#task-1-tags" has "value" set to "audio"
    And the page has "#task-1-form label:text-is('POD tags')"
    And the page part "#task-1-tags + .tag-pick" has "data-tag-field-src" set to "/admin/tags/private/choices?project=1"
    When I fetch the admin page "/admin/tags/private/choices?project=1" as JSON
    Then the admin answer holds:
      """
      { "tags": [{ "name": "audio" }, { "name": "video" }] }
      """
    And the answer does not show "home"

  Scenario: The admin task editor makes a project tag for a tag it saves
    Given I am signed in to the admin
    When I save the task "Record the intro" in the admin with:
      | task[tags] | audio, mix |
    Then the database reads "audio, project, 1 / mix, project, 1" for:
      """
      SELECT name, scope, tags.project_id FROM task_tags JOIN tags ON tags.id = tag_id ORDER BY name
      """

  Scenario: The task tools tag a task in its own scope and make no global tag for a project task
    Given an MCP client connected with the scopes "read write publish delete"
    When I call the MCP tool "save_task" with:
      """
      { "id": 1, "tags": ["audio", "drums"] }
      """
    And I call the MCP tool "tag_tasks" with:
      """
      { "ids": [1, 2], "tag": "mix" }
      """
    And I call the MCP tool "capture_task" with:
      """
      { "title": "Record the outro", "project": "POD", "tags": ["audio"] }
      """
    Then the database reads "1, audio, project, 1 / 1, drums, project, 1 / 1, mix, project, 1 / 2, mix, private,  / 3, audio, project, 1" for:
      """
      SELECT task_id, name, scope, tags.project_id FROM task_tags JOIN tags ON tags.id = tag_id ORDER BY task_id, name
      """
    And the database reads "home / mix" for:
      """
      SELECT name FROM tags WHERE scope = 'private' ORDER BY name
      """

  Scenario: untag_tasks takes a project tag off and notes it in the history
    Given the task_tags table holds the rows:
      | task_id | tag_id | tag_scope |
      | 1       | 1      | project   |
    And an MCP client connected with the scopes "read write publish delete"
    When I call the MCP tool "untag_tasks" with:
      """
      { "ids": [1], "tag": "audio" }
      """
    Then the database holds 0 task_tags rows
    And the database reads "untagged, audio" for:
      """
      SELECT kind, tag_name FROM task_events
      """

  Scenario: A task that moves to another project carries its tags there by name
    Given the task_tags table holds the rows:
      | task_id | tag_id | tag_scope |
      | 1       | 1      | project   |
      | 1       | 2      | project   |
    And an MCP client connected with the scopes "read write publish delete"
    When I call the MCP tool "link_records" with:
      """
      { "kind": "task", "id": 1, "other_kind": "project", "other_id": 2 }
      """
    Then the database reads "audio, 2, mk-violet, Sound work / video, 2, mk-sand, " for:
      """
      SELECT name, tags.project_id, color, coalesce(description, '') FROM task_tags JOIN tags ON tags.id = tag_id ORDER BY name
      """

  Scenario: A task that leaves every project keeps its tags as global tags
    Given the task_tags table holds the rows:
      | task_id | tag_id | tag_scope |
      | 1       | 1      | project   |
    And an MCP client connected with the scopes "read write publish delete"
    When I call the MCP tool "unlink_records" with:
      """
      { "kind": "task", "id": 1, "other_kind": "project", "other_id": 1 }
      """
    Then the database reads "audio, private, " for:
      """
      SELECT name, scope, tags.project_id FROM task_tags JOIN tags ON tags.id = tag_id
      """

  Scenario: A rule that files into a project holds that project's tags
    Given an API token
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "acme/*", "tags": ["audio"], "projects": [1] }
      """
    Then the database reads "audio, project, 1" for:
      """
      SELECT name, scope, tags.project_id FROM task_rule_tags JOIN tags ON tags.id = tag_id
      """
