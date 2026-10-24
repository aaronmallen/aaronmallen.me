Feature: The MCP project and work entry tools
  The tools list, save, archive and restore projects, and list, add and remove roles, refusing what the admin
  refuses with the same reasons.

  Background:
    Given an MCP client connected with the scopes "read write publish delete"

  Scenario: list_projects lists active projects, private ones too, then archived ones newest first
    Given the projects:
      | name   | key | visibility | started    | archived   | board     | tags |
      | first  | FIR | public     | 2024-06-01 |            | published |      |
      | second | SEC | private    |            |            |           | ruby |
      | older  | OLD | public     | 2025-01-02 | 2025-01-02 |           |      |
      | newer  | NEW | public     | 2025-03-04 | 2025-03-04 |           |      |
    When I call the MCP tool "list_projects"
    Then the MCP answer holds:
      """
      {
        "projects": [
          { "name": "first", "key": "FIR", "started_on": "2024-06-01", "archived_on": null, "status": "active", "visibility": "public", "board_published": true },
          { "name": "second", "visibility": "private", "board_published": false, "tags": ["ruby"] },
          { "name": "newer", "archived_on": "2025-03-04", "status": "archived" },
          { "name": "older" }
        ]
      }
      """

  Scenario: list_work_entries lists the roles that overlap a range, a role still held running to today
    Given the work_entries table holds the rows:
      | org    | role     | from_year | to_year | position |
      | early  | Engineer | 2010      | 2012    | 1        |
      | middle | Engineer | 2014      | 2018    | 2        |
      | present | Engineer | 2020     |         | 3        |
    Then the MCP work entries read:
      | from       | to         | orgs        |
      | 2017-01-01 | 2021-12-31 | middle, present |
      | 2030-01-01 | 2030-12-31 | present         |
      | 2013-01-01 | 2013-12-31 |             |
    When I call the MCP tool "list_work_entries" with:
      """
      { "from": "2020-01-01", "to": "2020-12-31" }
      """
    Then the MCP answer holds:
      """
      { "work_entries": [{ "org": "present", "to_year": null, "current": true }] }
      """
    When I call the MCP tool "list_work_entries" with:
      """
      { "from": "last year", "to": "2020-12-31" }
      """
    Then the MCP tool refuses with "give from and to as days, such as 2026-01-01"
    When I call the MCP tool "list_work_entries" with:
      """
      { "from": "2021-01-01", "to": "2020-12-31" }
      """
    Then the MCP tool refuses with "from comes after to"

  Scenario: save_project adds an active project with its board unpublished, a key and its stars
    Given GitHub holds a token for the issue sync
    And GitHub reports "aaronmallen/fresh" with 42 stars and the release "v1.0.0"
    When I call the MCP tool "save_project" with:
      """
      { "name": "fresh", "repo": "aaronmallen/fresh", "visibility": "private", "tags": ["ruby", "cli"] }
      """
    Then the MCP answer holds:
      """
      { "name": "fresh", "visibility": "private", "status": "active", "key": "FRE", "board_published": false }
      """
    When the queued project refreshes run
    Then the project "fresh" holds 42 stars and the release "v1.0.0"
    And the project "fresh" reads:
      | tags | cli ruby |
    When I call the MCP tool "save_project" with:
      """
      { "name": "other", "key": "oth9", "visibility": "public" }
      """
    Then the MCP answer holds:
      """
      { "key": "OTH9" }
      """

  Scenario: save_project hands a repo's imported issues to the project, and a later change keeps a link I removed off
    Given the projects:
      | name    |
      | project |
    And the tasks:
      | title | list     |
      | Issue | external |
    And the task sources:
      | task  | url                                          |
      | Issue | https://github.com/aaronmallen/fresh/issues/1 |
    When I call the MCP tool "save_project" with:
      """
      { "id": 1, "repo": "aaronmallen/fresh" }
      """
    Then the task rules read "github aaronmallen/fresh project"
    And the database reads "1" for:
      """
      SELECT project_id FROM tasks
      """
    When I call the MCP tool "unlink_records" with:
      """
      { "kind": "task", "id": 1, "other_kind": "project", "other_id": 1 }
      """
    And I call the MCP tool "save_project" with:
      """
      { "id": 1, "name": "renamed" }
      """
    Then the database reads "" for:
      """
      SELECT project_id FROM tasks WHERE project_id IS NOT NULL
      """

  Scenario: save_project keeps what a change leaves out and changes what it names
    Given the projects:
      | name   | key | visibility | tagline   | started    | tags | board     | archived  |
      | kept   | POD | private    | kept      | 2024-06-01 | ruby | published |           |
      | pub    | PUB | public     | gone soon |            |      | published |           |
      | shelf  | SHE | public     |           | 2024-01-01 | | | 2024-02-01 |
    When I call the MCP tool "save_project" with:
      """
      { "id": 1, "name": "renamed" }
      """
    Then the project "renamed" reads:
      | key             | POD        |
      | tagline         | kept       |
      | visibility      | private    |
      | started_on      | 2024-06-01 |
      | tags            | ruby       |
      | board_published | true       |
    When I call the MCP tool "save_project" with:
      """
      { "id": 2, "tagline": "", "visibility": "private", "board_published": false }
      """
    Then the project "pub" reads:
      | tagline         | none    |
      | visibility      | private |
      | board_published | false   |
    When I call the MCP tool "save_project" with:
      """
      { "id": 2, "board_published": true }
      """
    Then the project "pub" reads:
      | board_published | true |
    When I call the MCP tool "save_project" with:
      """
      { "id": 3, "name": "still archived" }
      """
    Then the project "still archived" reads:
      | archived_on | 2024-02-01 |

  Scenario: save_project refuses what the admin refuses, with its reasons, and saves nothing
    Given the projects:
      | name       | key | repo              | archived   | started    |
      | Site Tools | POD | aaronmallen/taken |            |            |
      | shelf      | SHE |                   | 2024-01-15 | 2023-01-01 |
    Then the MCP tool "save_project" refuses:
      | args                                                                          | message                                                                   |
      | {"name": "fresh"}                                                             | visibility: pick public or private                                         |
      | {"name": "fresh", "key": "POD", "visibility": "public"}                       | key: another project already has this key                                  |
      | {"name": "site tools!", "visibility": "public"}                               | name: another project's name makes the same link                           |
      | {"name": "copy", "repo": "aaronmallen/taken", "visibility": "public"}         | repo: another project already tracks this repository                       |
      | {"name": "later", "visibility": "public", "started_on": "{month:after next}"} | started_on: pick this month or one before it                               |
      | {"id": 2, "started_on": "2024-03"}                                            | started_on: the start month falls after the day this project was archived |
      | {"repo": "aaronmallen/nameless", "visibility": "public"}                      | name: add a name                                                           |
      | {"name": " 　", "visibility": "public"}                              | name: add a name                                                           |
      | {"name": "Pick\u0007a queue", "visibility": "public"}                         | name: holds a control character                                            |
      | {"id": 999999, "name": "ghost"}                                               | no project has the ID 999999                                               |
    When I call the MCP tool "save_project" with:
      """
      { "name": "fresh", "visibility": "secret" }
      """
    Then the MCP call is refused
    And the database holds 2 projects rows

  Scenario: save_project keeps a name with Unicode spaces around real words as typed
    When I call the MCP tool "save_project" with:
      """
      { "name": " Pick a queue ", "visibility": "public" }
      """
    And I call the MCP tool "read_project" with:
      """
      { "id": 1 }
      """
    Then the MCP answer holds:
      """
      { "name": " Pick a queue " }
      """

  Scenario: archive_project and restore_project archive as of today and restore as active
    Given the projects:
      | name  | started    | archived   |
      | live  |            |            |
      | later | today + 40 |            |
      | gone  | today - 60 | today - 30 |
    When I call the MCP tool "archive_project" with:
      """
      { "id": 1 }
      """
    Then the MCP answer holds:
      """
      { "status": "archived", "archived_on": "{day:today}" }
      """
    And the MCP tool "archive_project" refuses:
      | args          | message                                       |
      | {"id": 2}     | not archived: its start month has not come yet |
      | {"id": 3}     | not archived: it is archived already           |
      | {"id": 999999} | no project has the ID 999999                  |
    And the database reads "{day:today} / none / {day:today - 30}" for:
      """
      SELECT coalesce(archived_on::text, 'none') FROM projects ORDER BY id
      """
    When I call the MCP tool "restore_project" with:
      """
      { "id": 3 }
      """
    Then the MCP answer holds:
      """
      { "status": "active" }
      """
    And the MCP tool "restore_project" refuses:
      | args      | message                          |
      | {"id": 2} | no archived project has the ID 2 |

  Scenario: add_work_entry adds a role and refuses what the admin refuses; delete_work_entry removes one
    Then the MCP tool "add_work_entry" refuses:
      | args                                                                    | message                                           |
      | {"org": "Acme", "role": "Engineer", "from_year": 2019, "to_year": 2017} | to_year: the end year falls before the start year |
      | {"org": "Acme", "role": "Engineer", "from_year": 19}                    | from_year: use a four digit year, as 2018         |
      | {"org": " ", "role": "Engineer", "from_year": 2019}                     | org: name the organization                        |
      | {"org": "Acme", "role": "Engi\u0007neer", "from_year": 2019}            | role: holds a control character                   |
    And the database holds 0 work_entries rows
    When I call the MCP tool "add_work_entry" with:
      """
      { "org": "Acme", "role": "Engineer", "from_year": 2019 }
      """
    Then the MCP answer holds:
      """
      { "org": "Acme", "role": "Engineer", "from_year": 2019, "current": true }
      """
    When I call the MCP tool "delete_work_entry" with:
      """
      { "id": 1 }
      """
    Then the database holds 0 work_entries rows
    And the MCP tool "delete_work_entry" refuses:
      | args           | message                   |
      | {"id": 999999} | no role has the ID 999999 |
