Feature: The time report through the API
  The API and read_time_report sum the tracked time in a range, counting overlap once, as the time screen does.

  Background:
    Given an API token

  Scenario: Grouped by project, the API sums each project as the screen does and as read_time_report does
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And the worked tasks:
      | title           | sessions               | projects |
      | Ship the gem    | 2026-03-02 09:00-10:00 | gem      |
      | Polish the site | 2026-03-03 09:00-09:30 | site     |
      | Answer email    | 2026-03-04 09:00-09:15 |          |
      | Out of range    | 2026-03-20 09:00-10:00 | site     |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=project" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {"from": "2026-03-02", "to": "2026-03-08", "by": "project", "seconds": 6300, "groups": [
        {"key": {project:gem}, "name": "gem", "seconds": 3600, "shared": false,
          "tasks": [{"id": {task:Ship the gem}, "title": "Ship the gem", "seconds": 3600, "shared": false}]},
        {"key": {project:site}, "name": "site", "seconds": 1800, "shared": false,
          "tasks": [{"id": {task:Polish the site}, "title": "Polish the site", "seconds": 1800, "shared": false}]},
        {"key": null, "name": null, "seconds": 900, "shared": false}
      ]}
      """
    And the API answer to GET "/time_report?from=2026-03-02&to=2026-03-08&by=project" matches the MCP tool "read_time_report" with:
      """
      {"from": "2026-03-02", "to": "2026-03-08", "by": "project"}
      """
    When I open the time report from "2026-03-02" to "2026-03-08" by "project"
    Then the time rows read "gem 1h 00m | site 30m | No project 15m"

  Scenario: Grouped by tag, the API sums each tag and groups by tag when told nothing
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And the worked tasks:
      | title        | sessions               | tags      |
      | Tagged twice | 2026-03-02 09:00-10:00 | ruby site |
      | Tagged once  | 2026-03-03 09:00-09:30 | ruby      |
      | Untagged     | 2026-03-04 09:00-09:15 |           |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08" through the API
    Then the API answer holds:
      """
      {"by": "tag", "groups": [
        {"key": "ruby", "name": "ruby", "seconds": 5400},
        {"key": "site", "name": "site", "seconds": 3600},
        {"key": null, "name": null, "seconds": 900}
      ]}
      """
    And the API answer to GET "/time_report?from=2026-03-02&to=2026-03-08&by=tag" matches the MCP tool "read_time_report" with:
      """
      {"from": "2026-03-02", "to": "2026-03-08"}
      """
    And the API answer to GET "/time_report?from=2026-03-02&to=2026-03-08&by=tag" matches the MCP tool "read_time_report" with:
      """
      {"from": "2026-03-02", "to": "2026-03-08", "by": "tag"}
      """
    When I open the time report from "2026-03-02" to "2026-03-08" by "tag"
    Then the time rows read "ruby 1h 30m | site 1h 00m | No tag 15m"

  Scenario: Grouped by day, the API keys each day and flags none as shared
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And the worked tasks:
      | title                | sessions               | projects  |
      | Ship the shared work | 2026-03-02 09:00-10:00 | site, gem |
      | Answer email         | 2026-03-04 09:00-09:15 |           |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"groups": [
        {"key": "2026-03-02", "name": "2026-03-02", "seconds": 3600, "shared": false},
        {"key": "2026-03-04", "name": "2026-03-04", "seconds": 900, "shared": false}
      ]}
      """
    And the API answer to GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" matches the MCP tool "read_time_report" with:
      """
      {"from": "2026-03-02", "to": "2026-03-08", "by": "day"}
      """
    When I open the time report from "2026-03-02" to "2026-03-08" by "day"
    Then the time rows read "Monday, March 2 1h 00m | Wednesday, March 4 15m"

  Scenario: A session that crosses the range counts only the part inside it, on the day it counts
    Given the worked tasks:
      | title       | sessions                                                                   |
      | Late nights | 2026-03-01 23:00 to 2026-03-02 01:00; 2026-03-08 23:00 to 2026-03-09 02:00 |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"seconds": 7200, "groups": [
        {"key": "2026-03-02", "seconds": 3600, "tasks": [{"id": {task:Late nights}}]},
        {"key": "2026-03-08", "seconds": 3600}
      ]}
      """

  Scenario: A running session counts up to now, once beside a closed one
    Given the worked tasks:
      | title            | sessions                          |
      | Running          | 20 minutes ago to                |
      | Closed beside it | 10 minutes ago to 5 minutes ago    |
    When I GET "/time_report?from={day:today - 1}&to={day:today}" through the API
    Then the time report total is about 1200 seconds

  Scenario: Tasks that ran at the same time count the hour once in the total
    Given the worked tasks:
      | title | sessions               |
      | one   | 2026-03-02 09:00-10:00 |
      | two   | 2026-03-02 09:00-10:00 |
      | three | 2026-03-02 09:00-10:00 |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"seconds": 3600, "groups": [{"seconds": 3600, "overlapped": true}]}
      """
    And the time report day "2026-03-02" lists "one 3600, three 3600, two 3600" in some order

  Scenario: Overlap merges within a project or a tag, but not across projects
    Given the worked tasks:
      | title            | sessions               | projects | tags |
      | Side by side 0   | 2026-03-02 09:00-10:00 | site     | ruby |
      | Side by side 1   | 2026-03-02 09:00-10:00 | site     | ruby |
      | For the gem      | 2026-03-02 09:00-10:00 | gem      |      |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=project" through the API
    Then the API answer holds:
      """
      {"seconds": 3600, "groups": [
        {"name": "gem", "seconds": 3600, "overlapped": false},
        {"name": "site", "seconds": 3600, "overlapped": true}
      ]}
      """
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=tag" through the API
    Then the API answer holds:
      """
      {"groups": [{"name": "ruby", "seconds": 3600, "overlapped": true}, {"name": null}]}
      """

  Scenario: A task moved from one project to another counts once in the total
    Given the worked tasks:
      | title  | sessions               | projects  |
      | Shared | 2026-03-02 09:00-10:00 | site, gem |
      | Loose  | 2026-03-02 09:00-10:00 |           |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=project" through the API
    Then the API answer holds:
      """
      {"seconds": 3600}
      """

  Scenario: Short spans inside a long one merge, spans apart do not, and overlap past midnight lands on each day
    Given the worked tasks:
      | title        | sessions                             |
      | Long         | 2026-03-02 09:00-12:00               |
      | Inside early | 2026-03-02 09:30-10:00               |
      | Inside late  | 2026-03-02 11:00-11:30               |
      | Late         | 2026-03-04 22:00 to 2026-03-05 02:00  |
      | Later        | 2026-03-04 23:00 to 2026-03-05 01:00  |
      | Morning      | 2026-03-07 09:00-10:00               |
      | Noon         | 2026-03-07 12:00-13:00               |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"groups": [
        {"key": "2026-03-02", "seconds": 10800},
        {"key": "2026-03-04", "seconds": 7200},
        {"key": "2026-03-05", "seconds": 7200},
        {"key": "2026-03-07", "seconds": 7200, "overlapped": false}
      ]}
      """

  Scenario: A hand-set total above the sessions adds to the day the task closed
    Given the worked tasks:
      | title         | sessions               | total | closed           |
      | Ran alongside | 2026-03-02 09:00-10:00 |       |                  |
      | Set by hand   | 2026-03-02 09:00-10:00 | 10800 | 2026-03-02 10:00 |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"seconds": 10800, "groups": [{"key": "2026-03-02", "seconds": 10800}]}
      """

  Scenario: A hand-set total below the sessions never takes from the merged total
    Given the worked tasks:
      | title         | sessions               | total | closed           |
      | Ran alongside | 2026-03-02 09:00-10:00 |       |                  |
      | Set by hand   | 2026-03-02 09:00-10:00 | 1800  | 2026-03-02 10:00 |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"seconds": 3600, "groups": [{"key": "2026-03-02", "seconds": 3600}]}
      """

  Scenario: The rest of a hand-set total lands on the day the task closed
    Given the worked tasks:
      | title       | sessions                                       | total | closed           |
      | Set by hand | 2026-03-02 09:00-10:00; 2026-03-03 09:00-12:00 | 18000 | 2026-03-05 15:00 |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"groups": [
        {"key": "2026-03-02", "seconds": 3600},
        {"key": "2026-03-03", "seconds": 10800},
        {"key": "2026-03-05", "seconds": 3600}
      ]}
      """

  Scenario: An open task's hand-set total lands on its last closed session day
    Given the worked tasks:
      | title   | sessions                                  | total | status      |
      | Open    | 2026-03-03 09:00-10:00                    | 7200  | in_progress |
      | Running | 2026-03-04 09:00-10:00; 10 minutes ago to | 7200  |             |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"groups": [{"key": "2026-03-03", "seconds": 7200}, {"key": "2026-03-04", "seconds": 7200}]}
      """

  Scenario: A hand-set total with no sessions lands on the day the task closed, inside the range only
    Given the worked tasks:
      | title        | total | closed           | status |
      | Closed in    | 2700  | 2026-03-05 15:00 |        |
      | Closed after | 2700  | 2026-03-09 15:00 |        |
      | Never closed | 2700  |                  | open   |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"groups": [{"key": "2026-03-05", "seconds": 2700}]}
      """

  Scenario: Each group lists its tasks by their time in the range, most first
    Given the worked tasks:
      | title | sessions                                       |
      | small | 2026-03-02 09:00-09:20                         |
      | big   | 2026-03-02 10:00-12:00; 2026-03-12 10:00-11:00 |
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=day" through the API
    Then the API answer holds:
      """
      {"groups": [{"tasks": [{"id": {task:big}, "title": "big", "seconds": 7200},
                              {"id": {task:small}, "title": "small", "seconds": 1200}]}]}
      """

  Scenario: A range with no time answers no groups
    When I GET "/time_report?from=2026-03-02&to=2026-03-08" through the API
    Then the API answer holds:
      """
      {"seconds": 0, "groups": []}
      """

  Scenario: The API refuses a range it cannot use
    When I GET "/time_report?from=2026-03-08&to=2026-03-02" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"from": ["from comes after to"]}}
      """
    When I GET "/time_report?from=nope&to=2026-03-08" through the API
    Then the API answers 422
    When I GET "/time_report" through the API
    Then the API answers 422
    And the API answer holds "\"from\""
    And the API answer holds "\"to\""
    When I GET "/time_report?from=2026-03-02&to=2026-03-08&by=year" through the API
    Then the API answers 422
