Feature: Task rules through the API
  A task rule tags issues from the repos or Linear teams its pattern names, and may put them in a project.
  Saving a new rule applies it to the tasks already imported; editing one does not.

  Background:
    Given an API token

  Scenario: The rule list orders rules by pattern with their provider and tags
    Then the API calls answer:
      | call             | body | status | holds |
      | GET /task_rules  |      | 200    | {"task_rules": []} |
      | POST /task_rules | {"pattern": "aaronmallen/aaronmallen.me", "tags": ["ruby", "hanami"]} | 201 | |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["projects"]} | 201 | |
      | POST /task_rules | {"pattern": "acme/ENG", "provider": "linear", "tags": ["work"]} | 201 | {"provider": "linear", "pattern": "acme/eng"} |
      | GET /task_rules  |      | 200    | {"task_rules": [{"id": 2, "pattern": "aaronmallen/*", "provider": "github", "tags": ["projects"]}, {"id": 1, "pattern": "aaronmallen/aaronmallen.me", "tags": ["hanami", "ruby"]}, {"provider": "linear", "pattern": "acme/eng"}]} |

  Scenario: Saving a rule answers it and makes its tags as private tags
    Given the projects:
      | name    | visibility | archived  | started    |
      | Blog    | public     |           |            |
      | Hidden  | private    |           |            |
      | Retired | public     | today - 1 | today - 30 |
    Then the API calls answer:
      | call             | body                                                    | status | holds |
      | POST /task_rules | {"pattern": "AaronMallen/*", "tags": ["projects", "brand-new"]} | 201 | {"id": 1, "pattern": "aaronmallen/*", "provider": "github", "tags": ["brand-new", "projects"], "projects": []} |
      | POST /task_rules | {"pattern": "octocat/*", "projects": [1]}               | 201    | {"tags": [], "projects": [{"id": 1, "name": "Blog"}]} |
      | POST /task_rules | {"pattern": "hidden/*", "projects": [2]}                | 201    | {"projects": [{"id": 2}]} |
      | POST /task_rules | {"pattern": "retired/*", "projects": [3]}               | 201    | {"projects": [{"id": 3}]} |
      | POST /task_rules | {"pattern": "acme/*", "provider": "github", "tags": ["work"]} | 201 | |
      | POST /task_rules | {"pattern": "acme/*", "provider": "linear", "tags": ["work"]} | 201 | |
    And the database reads "brand-new, private" for:
      """
      SELECT name, scope FROM tags WHERE name = 'brand-new'
      """
    And the database reads "github / linear" for:
      """
      SELECT provider FROM task_rules WHERE pattern = 'acme/*' ORDER BY provider
      """

  Scenario: Saving a rule refuses one it cannot keep and saves nothing
    Given the projects:
      | name |
      | One  |
      | Two  |
    Then the API calls answer:
      | call             | body                                                    | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "projects": [1, 2]}        | 422    | {"errors": {"projects": ["a rule names one project at most"]}} |
      | POST /task_rules | {"pattern": "aaronmallen/*", "projects": [999999]}      | 422    | {"errors": {"projects": ["no project has one of those IDs"]}} |
      | POST /task_rules | {"pattern": "acme/*", "provider": "jira", "tags": ["work"]} | 422 | "provider" |
      | POST /task_rules | {"pattern": "not a repo", "tags": ["ruby"]}             | 422    | {"error": "invalid", "message": "name one repo or team as owner/name, or all of an owner's as owner/*", "errors": {"pattern": ["name one repo or team as owner/name, or all of an owner's as owner/*"]}} |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": [], "projects": []} | 422   | {"errors": {"tags": ["name a tag or a project first"]}} |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["ruby_rails"]}    | 422    | {"errors": {"tags": ["a tag is lowercase words joined by hyphens"]}} |
      | POST /task_rules | {"tags": ["ruby"]}                                      | 422    | {"errors": {"pattern": ["pattern is missing"]}} |
    And the database holds 0 task_rules rows
    And the API calls answer:
      | call             | body                                                         | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["projects"]}           | 201    | |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["ruby"]}               | 422    | {"errors": {"pattern": ["another rule already holds that pattern"]}} |
      | POST /task_rules | {"pattern": "acme/*", "provider": "linear", "tags": ["ruby"]} | 201   | |
      | POST /task_rules | {"pattern": "acme/*", "provider": "linear", "tags": ["go"]}  | 422    | {"errors": {"pattern": ["another rule already holds that pattern"]}} |

  Scenario: A new GitHub rule tags the imported tasks from the repos it matches
    Given the tasks:
      | title  | list     | tags |
      | site   | external | ruby |
      | other  | external |      |
      | caps   | external |      |
      | near   | external |      |
      | linear | external |      |
      | plain  | next     |      |
    And the task sources:
      | task   | url                                                       |
      | site   | https://github.com/aaronmallen/aaronmallen.me/issues/1     |
      | other  | https://github.com/octocat/hello-world/issues/1           |
      | caps   | https://github.com/AaronMallen/AaronMallen.me/issues/2     |
      | near   | https://github.com/aaronmallen/aaronmallen.me2/issues/1    |
      | linear | https://linear.app/aaronmallen/issue/ABC-1                |
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "aaronmallen/*", "tags": ["ruby", "projects"] }
      """
    Then the tags on each task read "site: projects ruby / other: / caps: projects ruby / near: projects ruby / linear: / plain:"
    And the database reads "site, tagged, projects" for:
      """
      SELECT title, kind, tag_name FROM task_events JOIN tasks ON tasks.id = task_id WHERE title = 'site'
      """
    And the database reads "true" for:
      """
      SELECT bool_and(seen_at IS NULL) FROM task_sources
      """
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "aaronmallen/aaronmallen.me", "tags": ["one-repo"] }
      """
    Then the tags on each task read "site: one-repo projects ruby / other: / caps: one-repo projects ruby / near: projects ruby / linear: / plain:"

  Scenario: A new Linear rule tags only the Linear tasks from the teams it matches
    Given the tasks:
      | title   | list     |
      | eng     | external |
      | Eng     | external |
      | ops     | external |
      | octocat | external |
      | github  | external |
    And the task sources:
      | task    | url                                          |
      | eng     | https://linear.app/acme/issue/eng-12/a-title |
      | Eng     | https://linear.app/Acme/issue/ENG-7/a-title  |
      | ops     | https://linear.app/acme/issue/ops-3/a-title  |
      | octocat | https://linear.app/octocat/issue/eng-1/a-title |
      | github  | https://github.com/acme/eng/issues/1         |
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "acme/ENG", "provider": "linear", "tags": ["work"] }
      """
    Then the tags on each task read "eng: work / Eng: work / ops: / octocat: / github:"
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "acme/*", "provider": "linear", "tags": ["ruby"] }
      """
    Then the tags on each task read "eng: ruby work / Eng: ruby work / ops: ruby / octocat: / github:"

  Scenario: A new rule puts the imported tasks it matches in its project and keeps a project a task has
    Given the projects:
      | name | key  |
      | Blog | BLOG |
      | Held | HELD |
    And the tasks:
      | title | list     | project |
      | site  | external |         |
      | other | external |         |
      | held  | external | Held    |
    And the task sources:
      | task  | url                                                   |
      | site  | https://github.com/aaronmallen/aaronmallen.me/issues/1 |
      | other | https://github.com/octocat/hello-world/issues/1       |
      | held  | https://github.com/aaronmallen/aaronmallen.me/issues/2 |
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "aaronmallen/*", "projects": [1] }
      """
    Then the database reads "site, BLOG / other,  / held, HELD" for:
      """
      SELECT title, coalesce(key, '') FROM tasks LEFT JOIN projects ON projects.id = project_id ORDER BY tasks.id
      """
    When I DELETE "/task_rules/1" through the API
    Then the database reads "BLOG" for:
      """
      SELECT key FROM tasks JOIN projects ON projects.id = project_id WHERE title = 'site'
      """

  Scenario: Editing a rule changes what it names and applies to no task already imported
    Given the projects:
      | name |
      | Blog |
    And the tasks:
      | title   | list     |
      | octocat | external |
      | acme    | external |
    And the task sources:
      | task    | url                                          |
      | octocat | https://github.com/octocat/hello-world/issues/1 |
      | acme    | https://linear.app/acme/issue/eng-12/a-title |
    And the API calls answer:
      | call             | body                                                       | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["projects"]}         | 201    | |
      | POST /task_rules | {"pattern": "octolinear/*", "provider": "linear", "tags": ["ruby"]} | 201 | |
    Then the API calls answer:
      | call                | body                                          | status | holds |
      | PATCH /task_rules/1 | {"tags": ["ruby", "hanami"]}                  | 200    | {"id": 1, "pattern": "aaronmallen/*", "provider": "github", "tags": ["hanami", "ruby"], "projects": []} |
      | PATCH /task_rules/1 | {"projects": [1]}                             | 200    | {"tags": ["hanami", "ruby"], "projects": [{"id": 1, "name": "Blog"}]} |
      | PATCH /task_rules/1 | {"tags": ["ruby"]}                            | 200    | {"projects": [{"id": 1, "name": "Blog"}]} |
      | PATCH /task_rules/1 | {"tags": [], "projects": [1]}                 | 200    | {"tags": []} |
      | PATCH /task_rules/1 | {"pattern": "nope"}                           | 422    | |
      | PATCH /task_rules/1 | {"pattern": "octocat/*", "tags": ["ruby"]}    | 200    | {"pattern": "octocat/*", "tags": ["ruby"]} |
      | PATCH /task_rules/1 | {"provider": "linear"}                        | 200    | {"provider": "linear", "pattern": "octocat/*"} |
      | PATCH /task_rules/2 | {"tags": ["go"]}                              | 200    | {"provider": "linear"} |
      | PATCH /task_rules/2 | {"pattern": "acme/*", "tags": ["go"]}         | 200    | {"pattern": "acme/*"} |
    And the tags on each task read "octocat: / acme:"
    And the database reads "true" for:
      """
      SELECT bool_and(project_id IS NULL) FROM tasks
      """

  Scenario: Editing a rule to take its project out unlinks no task
    Given the projects:
      | name | key  |
      | Blog | BLOG |
    And the tasks:
      | title | list     |
      | site  | external |
    And the task sources:
      | task | url                                                   |
      | site | https://github.com/aaronmallen/aaronmallen.me/issues/1 |
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "aaronmallen/aaronmallen.me", "projects": [1] }
      """
    And I PATCH "/task_rules/1" through the API with:
      """
      { "tags": ["ruby"], "projects": [] }
      """
    Then the database reads "BLOG" for:
      """
      SELECT key FROM tasks JOIN projects ON projects.id = project_id
      """

  Scenario: Deleting a rule leaves the tags it gave
    Given the tasks:
      | title | list     |
      | site  | external |
    And the task sources:
      | task | url                                                   |
      | site | https://github.com/aaronmallen/aaronmallen.me/issues/1 |
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "aaronmallen/*", "tags": ["projects"] }
      """
    And I DELETE "/task_rules/1" through the API
    Then the API answer holds:
      """
      { "id": 1, "deleted": true }
      """
    And the database holds 0 task_rules rows
    And the tags on each task read "site: projects"

  Scenario: The rule tools answer as the rule endpoints do
    Given an MCP client connected with the scopes "read write delete"
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "aaronmallen/*", "tags": ["projects"] }
      """
    And I keep the API answer
    And I DELETE "/task_rules/1" through the API
    And I take back the kept API answer
    Then the MCP tool "save_task_rule" answers as the API did, apart from "id", with:
      """
      { "pattern": "aaronmallen/*", "tags": ["projects"] }
      """
    And the API answer to GET "/task_rules" matches the MCP tool "list_task_rules" with:
      """
      {}
      """
    When I PATCH "/task_rules/2" through the API with:
      """
      { "tags": ["ruby"] }
      """
    Then the MCP tool "save_task_rule" answers as the API did, apart from "", with:
      """
      { "id": 2, "tags": ["ruby"] }
      """
    When I POST "/task_rules" through the API with:
      """
      { "pattern": "not a repo", "tags": ["ruby"] }
      """
    Then the MCP tool "save_task_rule" answers as the API did, apart from "", with:
      """
      { "pattern": "not a repo", "tags": ["ruby"] }
      """
    When I call the MCP tool "delete_task_rule" with:
      """
      { "id": 2 }
      """
    Then the MCP answer holds:
      """
      { "id": 2, "deleted": true }
      """
