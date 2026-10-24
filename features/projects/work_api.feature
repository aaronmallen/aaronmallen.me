Feature: Work history through the API
  The API lists, reads, adds and removes roles, and answers as the MCP tools do.

  Background:
    Given an API token

  Scenario: The API lists the roles that overlap a range, as list_work_entries does
    Given an MCP client connected with the scopes "read"
    And the work entries:
      | role  | org   | from | to   |
      | Held  | Acme  | 2018 | 2020 |
      | Later | Acme  | 2022 | 2023 |
      | Now   | Acme  | 2019 |      |
    When I GET "/work_entries?from=2019-01-01&to=2019-12-31" through the API
    Then the API answers 200
    And the API answer holds "\"role\":\"Held\""
    And the API answer does not hold "Later"
    And the API answer to GET "/work_entries?from=2019-01-01&to=2019-12-31" matches the MCP tool "list_work_entries" with:
      """
      {"from": "2019-01-01", "to": "2019-12-31"}
      """

  Scenario: The API refuses a range that runs backward
    When I GET "/work_entries?from=2020-01-01&to=2019-01-01" through the API
    Then the API answers 422

  Scenario: The API adds a role, current when it has no end year
    When I POST "/work_entries" through the API with:
      """
      {"org": "Acme", "role": "Staff", "from_year": 2018}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"org": "Acme", "role": "Staff", "from_year": 2018, "current": true}
      """

  Scenario: The API refuses an end year before the start year
    When I POST "/work_entries" through the API with:
      """
      {"org": "Acme", "role": "Staff", "from_year": 2020, "to_year": 2018}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"to_year": ["the end year falls before the start year"]}}
      """

  Scenario: The API removes a role for good
    Given the work entries:
      | role  |
      | Staff |
    When I DELETE "/work_entries/{work_entry:Staff}" through the API
    Then the API answers 200
    And the API answer holds "\"deleted\":true"
    And the work entries are ""
    When I DELETE "/work_entries/999999" through the API
    Then the API answers 404
    And the API answer holds:
      """
      {"message": "no role has the ID 999999"}
      """

  Scenario: The API reads a role with its linked records, as read_work_entry does
    Given an MCP client connected with the scopes "read"
    And the work entries:
      | role  | org  | blurb        | from | to   |
      | Staff | Acme | built things | 2018 | 2021 |
      | Owner | Acme |              | 2022 |      |
    And the projects:
      | name |
      | blog |
    And the work_entry "Staff" links the project "blog"
    When I GET "/work_entries/{work_entry:Staff}" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {"id": {work_entry:Staff}, "org": "Acme", "role": "Staff", "blurb": "built things", "from_year": 2018,
        "to_year": 2021, "current": false,
        "record_links": {"project": [{"kind": "project", "id": {project:blog}, "title": "blog"}]}}
      """
    When I GET "/work_entries/{work_entry:Owner}" through the API
    Then the API answer holds:
      """
      {"to_year": null, "current": true, "record_links": {}}
      """
    And the API answer to GET "/work_entries/{work_entry:Staff}" matches the MCP tool "read_work_entry" with:
      """
      {"id": {work_entry:Staff}}
      """
