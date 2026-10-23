Feature: Pull requests
  The admin shows each imported pull request on a page of its own, with its
  state and times. The API and MCP read the same pull request.

  Scenario: The pull request page shows an open pull request
    Given I am signed in to the admin
    And a pull request "parser" with:
      | repo     | someone/gem                          |
      | number   | 42                                   |
      | title    | Fix the parser                       |
      | body     | first para\n\n- one\n- two           |
      | url      | https://github.com/someone/gem/pull/42 |
      | ready_at | 2026-10-01T14:30:00-05:00            |
    And the pull request "parser" links to the task "Move the server"
    When I open the pull request page for "parser"
    Then the GitHub record heads with "Fix the parser"
    And the GitHub record kicker reads "Pull request #42"
    And the GitHub record subline reads "someone/gem"
    And the GitHub record stats read "State Open, Opened Oct 1, 2026, 14:30"
    And the GitHub record body shows the li items "one, two"
    And the GitHub record lists the linked task "Move the server" beside it
    And the GitHub record links back to the activity
    And the GitHub record links to "https://github.com/someone/gem/pull/42"
    And the page has no axe breaches in light or dark

  Scenario: The pull request page shows a merged pull request with its merged time
    Given I am signed in to the admin
    And a pull request "merged" with:
      | ready_at  | 2026-10-01T14:30:00-05:00 |
      | merged_at | 2026-10-03T09:05:00-05:00 |
    When I open the pull request page for "merged"
    Then the GitHub record stats read "State Merged, Opened Oct 1, 2026, 14:30, Merged Oct 3, 2026, 09:05"

  Scenario: The pull request page shows a closed pull request with its closed time
    Given I am signed in to the admin
    And a pull request "closed" with:
      | ready_at  | 2026-10-01T14:30:00-05:00 |
      | closed_at | 2026-10-03T09:05:00-05:00 |
    When I open the pull request page for "closed"
    Then the GitHub record stats read "State Closed, Opened Oct 1, 2026, 14:30, Closed Oct 3, 2026, 09:05"

  Scenario: The pull request page shows a draft with no times and no description
    Given I am signed in to the admin
    And a pull request "draft" with:
      | ready_at | none |
    When I open the pull request page for "draft"
    Then the GitHub record stats read "State Draft"
    And the GitHub record says "No description."

  Scenario: A visitor who has not signed in sees no pull request
    Given a pull request "payroll" with:
      | repo | employer/payroll  |
      | body | for the March run |
    When I open the pull request page for "payroll"
    Then I am sent to sign in
    And I do not see "employer/payroll"
    And I do not see "for the March run"

  Scenario: The pull request page answers 404 for a pull request that is not there
    Given I am signed in to the admin
    Then the GitHub record page at "/admin/pull-requests/999999" answers with status 404

  Scenario: The API reads a pull request with its state, times and links
    Given an API token
    And a pull request "feed fix" with:
      | body      | It broke             |
      | ready_at  | 2026-03-02T14:05:00Z |
      | merged_at | 2026-03-03T09:00:00Z |
    And the pull request "feed fix" links to the task "Move the server"
    When I read the pull request "feed fix" through the API
    Then the API answers with status 200
    And the API answer holds "\"repo\":\"aaronmallen/blog\",\"number\":4,\"title\":\"Fix the feed\",\"description\":\"It broke\""
    And the API answer holds "\"url\":\"https://github.com/aaronmallen/blog/pull/4\",\"state\":\"merged\""
    And the API answer holds "\"ready_at\":\"2026-03-02T14:05:00Z\",\"merged_at\":\"2026-03-03T09:00:00Z\",\"closed_at\":null"
    And the API answer holds "\"record_links\":{\"task\":[{"
    And the API answer holds "\"title\":\"Move the server\""

  Scenario: The API and read_pull_request answer the same pull request
    Given I am signed in to the admin
    And an API token
    And an MCP client connects with the scopes "read" and I approve it
    And a pull request "feed fix" with:
      | body | It broke |
    And the pull request "feed fix" links to the task "Move the server"
    Then the API read of the pull request "feed fix" matches the MCP tool "read_pull_request", less the untrusted marks
