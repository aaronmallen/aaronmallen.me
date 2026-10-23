Feature: API page and ID bounds
  Pages and IDs stay within a Postgres integer, and every published ID schema says so.

  Background:
    Given an API token
    And the task "Call the plumber"
    And the table sprints holds:
      | sprint_date                                           |
      | ((now() AT TIME ZONE 'America/Chicago')::date)        |
    And the table saved_views holds:
      | name  | screen | filters              |
      | Next  | tasks  | {"filter": "next"}   |

  Scenario Outline: <path> refuses a page past the largest and answers a distant page with no rows
    When I GET "/<path>?<query>page=2147483648" through the API
    Then the API answers 422
    And the API answer's errors are only "page"
    When I GET "/<path>?<query>page=2147483647" through the API
    Then the API answers 200
    And the API answer at "<key>" is "[]"

    Examples:
      | path                 | query          | key       |
      | tasks                |                | tasks     |
      | decisions            |                | decisions |
      | sprints              |                | sprints   |
      | search               | query=plumber& | results   |
      | saved_views/1/records |               | records   |

  Scenario Outline: <tool> refuses a page past the largest
    Given an MCP client connected with the scopes "read"
    When I call the MCP tool "<tool>" with:
      """
      { <arguments> "page": 2147483648 }
      """
    Then the MCP tool refuses

    Examples:
      | tool            | arguments            |
      | list_decisions  |                      |
      | search          | "query": "plumber",  |
      | read_saved_view | "id": 1,             |

  Scenario Outline: <path> refuses the ID <id> with 422 and a list of reasons under ids
    Given an API token that may do all but "nothing"
    When I POST "/<path>" through the API with:
      """
      { "ids": [<id>] }
      """
    Then the API answers 422
    And the API answer's errors are only "ids"
    And the API answer's errors under "ids" are words

    Examples:
      | path                       | id         |
      | tasks/bulk/complete        | 0          |
      | tasks/bulk/complete        | 2147483648 |
      | posts/bulk/delete          | 0          |
      | posts/bulk/delete          | 2147483648 |
      | mail/threads/bulk/read     | 0          |
      | mail/threads/bulk/read     | 2147483648 |
      | webmentions/bulk/approve   | 0          |
      | webmentions/bulk/approve   | 2147483648 |

  Scenario: Every published ID schema runs from 1 to the largest
    Given an MCP client connected with the scopes "read"
    Then every ID the API document and the MCP tools take runs from 1 to 2147483647
