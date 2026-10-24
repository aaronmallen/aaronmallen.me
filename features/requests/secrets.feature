Feature: Secrets a request carries
  The app logs each request and times it, but keeps out of the log and the timing rows every code, token,
  challenge, note, body, recipient, file and visitor address a request carries.

  Scenario: GitHub calling the admin back is logged without the code, the state or the token
    Given I note where the app log ends
    When I sign in through GitHub
    Then the app log since then includes "/admin/auth/github/callback"
    And the app log since then leaves out what I noted
    And the app log since then does not include "gho_"

  Scenario: An MCP authorization and token exchange are logged without a challenge, state, form token, code or token
    Given I am signed in to the admin
    And I note where the app log ends
    When an MCP client is approved and trades its code for tokens
    Then the app log since then includes "/oauth/authorize" at least 2 times
    And the app log since then includes "/oauth/token"
    And the app log since then leaves out what I noted

  Scenario: A visitor reading the home page is logged and timed without the visitor's address
    Given I note where the app log ends
    When I request "/" from the address "198.51.100.77"
    Then the app log since then matches "GET 200 .* / "
    And the app log since then leaves out what I noted
    And the database soon answers "/" for:
      """
      SELECT DISTINCT route FROM performance_requests
      """
    And the timing rows leave out what I noted

  Scenario: A visitor reading a post with secrets in the query is logged by slug and page, and timed by route
    Given the posts:
      | title |
      | Hello |
    And a secret "api"
    And a secret "access"
    And a secret "webhook"
    And a secret "signing"
    And I note where the app log ends
    When I request "/writing/hello?page=2" with the secrets I noted as "api_token, access_token, webhook_secret, signing_key"
    Then the app log since then includes "page: \"2\""
    And the app log since then includes "slug: \"hello\""
    And the app log since then leaves out what I noted
    And the database soon answers "/writing/:slug" for:
      """
      SELECT route FROM performance_requests WHERE route LIKE '/writing%'
      """
    And the timing rows leave out what I noted
    And the database answers "0" for:
      """
      SELECT count(*) FROM performance_requests WHERE route LIKE '%hello%'
      """

  Scenario: The owner capturing a task is logged without the note
    Given I am signed in to the admin
    And a secret "note"
    And I note where the app log ends
    When I post the form "/admin/tasks" with my token and the secrets I noted as "task[note], task[title]=Call the bank"
    Then the app log since then includes "/admin/tasks"
    And the app log since then leaves out what I noted

  Scenario: The owner opening a decision is logged without the problem or the note
    Given I am signed in to the admin
    And a secret "problem"
    And a secret "note"
    And I note where the app log ends
    When I post the form "/admin/decisions" with my token and the secrets I noted as "decision[problem], decision[note], decision[title]=Pick a host"
    Then the app log since then includes "/admin/decisions"
    And the app log since then leaves out what I noted

  Scenario: The owner sending mail or saving a draft is logged without the body or a recipient
    Given I am signed in to the admin
    And a secret "html"
    And a secret "body"
    And I note "to-4b1d@example.com"
    And I note "cc-4b1d@example.com"
    And I note "bcc-4b1d@example.com"
    And I note where the app log ends
    When I post the form "/admin/mail/send" with my token and the secrets I noted as "mail[html], mail[body], mail[to], mail[cc], mail[bcc]"
    And I post the form "/admin/mail/draft" with my token and the secrets I noted as "mail[html], mail[body], mail[to], mail[cc], mail[bcc]"
    Then the app log since then includes "/admin/mail/send"
    And the app log since then includes "/admin/mail/draft"
    And the app log since then leaves out what I noted

  Scenario: An agent uploading a photo through the API or MCP is logged without the photo
    Given my requests carry an API token
    And I note "c2VjcmV0LXBob3RvLWJ5dGVzLTRiMWQ="
    And I note where the app log ends
    When I post "/api/v1/photos" with the "application/json" body:
      """
      {"data": "c2VjcmV0LXBob3RvLWJ5dGVzLTRiMWQ=", "filename": "photo.png"}
      """
    And an MCP client connected with the scopes "read write"
    And I call the MCP tool "upload_photo" with:
      """
      {"data": "c2VjcmV0LXBob3RvLWJ5dGVzLTRiMWQ=", "filename": "photo.png"}
      """
    Then the app log since then includes "/api/v1/photos"
    And the app log since then leaves out what I noted

  Scenario: A timing row that fails to write is logged as lost, without the statement or its values
    Given the timing table refuses every row
    And I note "performance_requests"
    And I note where the app log ends
    When I request "/"
    Then the app log since then includes "Timing row lost"
    And the app log since then leaves out what I noted
