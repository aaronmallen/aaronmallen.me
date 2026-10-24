Feature: Syncing issues on demand
  The External tab, the API and the sync_issues tool queue an issue sync for each provider that holds a token or a
  key, say which they queued, and say why when they cannot.

  Scenario: The External tab offers the sync, and no other tab does
    Given I am signed in to the admin
    And GitHub holds a token for the issue sync
    When I visit "/admin/tasks?filter=external"
    Then the page has "form[action='/admin/tasks/issues/sync'] button:has-text('Sync issues')"
    When I visit "/admin/tasks?filter=next"
    Then the page has no "form[action='/admin/tasks/issues/sync']"

  Scenario: The sync with a GitHub token queues the GitHub sync alone and returns to the External tab
    Given I am signed in to the admin
    And GitHub holds a token for the issue sync
    And Linear holds no keys
    When I visit "/admin/tasks?filter=external"
    And I click "Sync issues"
    Then I am on "/admin/tasks?filter=external"
    And the toast says "Sync queued · new issues show on external shortly"
    When the queued issue syncs run
    Then GitHub was searched 1 time
    And Linear was asked nothing

  Scenario: The sync asks GitHub nothing while the request runs
    Given I am signed in to the admin
    And GitHub holds a token for the issue sync
    And GitHub never answers POST "/graphql"
    When I visit "/admin/tasks?filter=external"
    And I click "Sync issues"
    Then the toast says "Sync queued · new issues show on external shortly"

  Scenario: The sync with a Linear key and no GitHub token queues the Linear sync alone
    Given I am signed in to the admin
    And Linear holds the keys "lin_api_one"
    When I visit "/admin/tasks?filter=external"
    And I click "Sync issues"
    Then the toast says "Sync queued · new issues show on external shortly"
    When the queued issue syncs run
    Then Linear was sent 1 queries holding "assignedIssues("
    And GitHub was asked nothing

  Scenario: The sync with a GitHub token and a Linear key queues both
    Given I am signed in to the admin
    And GitHub holds a token for the issue sync
    And Linear holds the keys "lin_api_one"
    When I visit "/admin/tasks?filter=external"
    And I click "Sync issues"
    And the queued issue syncs run
    Then GitHub was searched 1 time
    And Linear was sent 1 queries holding "assignedIssues("

  Scenario: The sync with neither says no token is set and queues nothing
    Given I am signed in to the admin
    And Linear holds no keys
    When I visit "/admin/tasks?filter=external"
    And I click "Sync issues"
    Then the toast says "No GitHub token or Linear key is set."
    When the queued issue syncs run
    Then GitHub was asked nothing
    And Linear was asked nothing

  Scenario: The sync says so when the queue is down
    Given I am signed in to the admin
    And GitHub holds a token for the issue sync
    When I visit "/admin/tasks?filter=external"
    And the queue is down
    And I click "Sync issues"
    Then the toast says "Not queued · the job queue is down, so try again soon"

  Scenario: A sync without a CSRF token or a session queues nothing
    Given I am signed in to the admin
    And GitHub holds a token for the issue sync
    When I post the form "/admin/tasks/issues/sync"
    Then it answers 403
    When I sign out from the menu on "/admin"
    And I post the form "/admin/tasks/issues/sync"
    And the queued issue syncs run
    Then GitHub was asked nothing

  Scenario: The API with a GitHub token queues the GitHub sync alone and asks GitHub nothing while it answers
    Given an API token
    And GitHub holds a token for the issue sync
    And Linear holds no keys
    And GitHub never answers POST "/graphql"
    When I POST "/tasks/issues/sync" through the API
    Then the API answers 200
    And the API answer is:
      """
      {"queued": ["github"]}
      """

  Scenario: The API with a GitHub token searches GitHub once the sync runs
    Given an API token
    And GitHub holds a token for the issue sync
    And Linear holds no keys
    When I POST "/tasks/issues/sync" through the API
    And the queued issue syncs run
    Then GitHub was searched 1 time
    And Linear was asked nothing

  Scenario: The API with a Linear key and no GitHub token queues the Linear sync alone
    Given an API token
    And Linear holds the keys "lin_api_one"
    When I POST "/tasks/issues/sync" through the API
    Then the API answer is:
      """
      {"queued": ["linear"]}
      """
    When the queued issue syncs run
    Then Linear was sent 1 queries holding "assignedIssues("
    And GitHub was asked nothing

  Scenario: The API and the MCP tool with a GitHub token and a Linear key queue both
    Given an API token
    And an MCP client connected with the scopes "write"
    And GitHub holds a token for the issue sync
    And Linear holds the keys "lin_api_one"
    When I POST "/tasks/issues/sync" through the API
    Then the API answer is:
      """
      {"queued": ["github", "linear"]}
      """
    When the queued issue syncs run
    Then GitHub was searched 1 time
    And Linear was sent 1 queries holding "assignedIssues("
    When I call the MCP tool "sync_issues"
    Then the MCP answer holds:
      """
      {"queued": ["github", "linear"]}
      """
    When the queued issue syncs run
    Then GitHub was searched 2 times
    And Linear was sent 2 queries holding "assignedIssues("

  Scenario: The API and the MCP tool with neither refuse with the admin's reason and queue nothing
    Given an API token
    And an MCP client connected with the scopes "write"
    And Linear holds no keys
    When I POST "/tasks/issues/sync" through the API
    Then the API answers 503
    And the API answer is:
      """
      {"error": "unavailable", "message": "no GitHub token or Linear key is set, so no issue sync can run"}
      """
    When I call the MCP tool "sync_issues"
    Then the MCP tool refuses with "no GitHub token or Linear key is set, so no issue sync can run"
    When the queued issue syncs run
    Then GitHub was asked nothing
    And Linear was asked nothing

  Scenario: The API answers 503 when the queue is down, as its document says
    Given an API token
    And GitHub holds a token for the issue sync
    And the queue is down
    When I POST "/tasks/issues/sync" through the API
    Then the API answers 503
    And the API answer at "error" is '"unavailable"'
    When the queue is back
    Then the API document lists the status 503 for POST "/tasks/issues/sync"
