Feature: Projects through the API
  The API lists, reads, adds, changes, archives and restores projects, and answers as the project tools do.

  Background:
    Given an API token

  Scenario: The project list puts live projects before archived ones, as list_projects does
    Given the projects:
      | name | visibility | archived  | started    | tags |
      | old  | public     | today - 1 | today - 30 |      |
      | live | private    |           |            | ruby |
    And an MCP client connected with the scopes "read"
    When I GET "/projects" through the API
    Then the API answers 200
    And the API answer holds:
      """
      { "projects": [{ "name": "live" }, { "name": "old" }] }
      """
    And the API answer to GET "/projects" matches the MCP tool "list_projects" with:
      """
      {}
      """

  Scenario: Adding a project makes it active with its board unpublished, and fetches its stars
    Given GitHub holds a token for the issue sync
    And GitHub reports "aaronmallen/blog" with 42 stars and the release "v1.0.0"
    Then the API calls answer:
      | call           | body                                                                | status | holds |
      | POST /projects | {"name": "notes", "visibility": "private", "tags": ["ruby"]}        | 201    | {"name": "notes", "visibility": "private", "status": "active", "tags": ["ruby"], "board_published": false} |
      | POST /projects | {"name": "blog", "repo": "aaronmallen/blog", "visibility": "private"} | 201  | |
      | POST /projects | {"name": "nope"}                                                    | 422    | {"errors": {"visibility": ["pick public or private"]}} |
    When the queued project refreshes run
    Then the project "blog" holds 42 stars and the release "v1.0.0"
    And the project "notes" reads:
      | board_published | false |

  Scenario: Changing a project keeps every field the change leaves out
    Given the projects:
      | name | tags |
      | blog | ruby |
    Then the API calls answer:
      | call              | body              | status | holds |
      | PATCH /projects/1 | {"tagline": "new"} | 200   | {"name": "blog", "tagline": "new", "tags": ["ruby"]} |

  Scenario: Archiving and restoring a project
    Given the projects:
      | name    | started    | archived   |
      | live    |            |            |
      | later   | today + 40 |            |
      | gone    | today - 60 | today - 30 |
      | back    | today - 60 | today - 30 |
    Then the API calls answer:
      | call                      | body | status | holds |
      | POST /projects/1/archive   |      | 200    | {"status": "archived", "archived_on": "{day:today}"} |
      | POST /projects/2/archive   |      | 422    | {"message": "not archived: its start month has not come yet"} |
      | POST /projects/3/archive   |      | 422    | {"message": "not archived: it is archived already"} |
      | POST /projects/4/restore   |      | 200    | {"status": "active", "archived_on": null} |
      | POST /projects/4/restore   |      | 404    | {"message": "no archived project has the ID 4"} |
    And the project "gone" reads:
      | archived_on | {day:today - 30} |

  Scenario: Reading a project answers it whole with its stamps and linked records, as read_project does
    Given the projects:
      | name | key | tagline | visibility | board     | started    | archived   | tags | repo             | url                    | stars | release |
      | blog | BLO | my site | private    | published | 2024-06-01 | 2026-03-02 | ruby | aaronmallen/blog | https://aaronmallen.me | 12    | v2.0.0  |
    And a task "Move the server"
    And a published post "On hosting"
    And the database runs:
      """
      UPDATE projects SET created_at = now() - interval '2 days', updated_at = now() - interval '1 day';
      INSERT INTO record_links (left_kind, left_id, right_kind, right_id) VALUES ('post', 1, 'project', 1);
      """
    And an MCP client connected with the scopes "read"
    When I GET "/projects/1" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {
        "id": 1, "key": "BLO", "name": "blog", "tagline": "my site", "status": "archived", "visibility": "private",
        "board_published": true, "started_on": "2024-06-01", "archived_on": "2026-03-02", "tags": ["ruby"],
        "repo": "aaronmallen/blog", "url": "https://aaronmallen.me", "og_image_url": null, "stars": 12,
        "release": "v2.0.0", "record_links": { "post": [{ "kind": "post", "id": 1, "title": "On hosting" }] }
      }
      """
    And the API answer has the project's stamps as the database does
    And the API answer to GET "/projects/1" matches the MCP tool "read_project" with:
      """
      { "id": 1 }
      """
