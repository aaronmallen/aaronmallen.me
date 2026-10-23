Feature: GitHub connection
  I connect one GitHub account, through GitHub's sign-in or with a personal
  access token. The record, issue and project jobs read GitHub with it.

  Background:
    Given I am signed in to the admin

  Scenario: The picker offers GitHub with no server field while it is not connected
    When I visit "/admin/settings/services"
    Then the service picker offers "GitHub"
    And the GitHub connect dialog asks for no server
    And the GitHub connect dialog offers a token field
    And the GitHub connect dialog hints "You approve access on GitHub, then come back here."
    And the GitHub connect dialog hints "Disconnect any time and the site revokes its token on GitHub."
    And the GitHub connect dialog hints "Classic or fine-grained."

  Scenario: Connecting sends me to GitHub for the scopes the reads need, with a PKCE challenge
    Given GitHub shows its sign-in page
    When I connect GitHub
    Then the authorize request went to "/github/login/oauth/authorize"
    And the authorize request asked with "client_id" as "stub-client-id"
    And the authorize request asked with "scope" as "repo read:org"
    And the authorize request sent a PKCE challenge and comes back to "/admin/auth/github/callback"

  Scenario: GitHub grants access and the site saves the account with its token
    Given GitHub shows its sign-in page
    And GitHub's token exchange grants "repo,read:org"
    And GitHub answers as the user "aaronmallen"
    When I connect GitHub
    And I approve the connection
    Then the services address opens the connection "@aaronmallen"
    And the connection toast says "GitHub connected as @aaronmallen"
    And the GitHub connection "@aaronmallen" has the account "931094" and the scopes "repo read:org"
    And the GitHub connection "@aaronmallen" holds the credentials '{"access_token": "gho_data"}'
    And GitHub's token exchange received the PKCE verifier and the callback
    And the service panel names the account "@aaronmallen"
    And the service line "Read repositories and issues" shows "granted"
    And the service line "Signed in with" shows "OAuth"
    And the service picker leaves out "GitHub"
    And the page has no axe breaches in light or dark

  Scenario: The record jobs read GitHub with a new connection and no restart
    Given GitHub shows its sign-in page
    And GitHub's token exchange grants "repo,read:org"
    And GitHub answers as the user "aaronmallen"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": []}}}}
      """
    When I connect GitHub
    And I approve the connection
    And the GitHub commit import runs on the new connection
    Then GitHub received POST "/graphql"

  Scenario: Reconnecting the account it holds replaces the token on the same connection
    Given a GitHub connection as "@old" with the token "gho_old"
    And GitHub shows its sign-in page
    And GitHub's token exchange grants "repo,read:org"
    And GitHub answers as the user "aaronmallen"
    When I start a GitHub connect from a stale tab
    And I approve the connection
    Then the connection toast says "GitHub connected as @aaronmallen"
    And the site holds the GitHub connections "@aaronmallen"
    And the GitHub connection "@aaronmallen" is still row 1
    And the GitHub connection "@aaronmallen" has the account "931094" and the scopes "repo read:org"
    And the GitHub connection "@aaronmallen" holds the credentials '{"access_token": "gho_data"}'

  Scenario: Declining on GitHub saves nothing
    Given GitHub shows its sign-in page
    When I connect GitHub
    And I decline the connection
    Then the connection toast says "GitHub didn't grant access"
    And the site holds no GitHub connection

  Scenario: The site refuses a state it never sent
    Given my admin sign-in is over a minute old
    And GitHub shows its sign-in page
    When I connect GitHub
    And I come back from GitHub with a state it never sent
    Then the connection answer has status 401
    And the site holds no GitHub connection

  Scenario: The site refuses a connect state once I sign out
    Given my admin sign-in is over a minute old
    And GitHub shows its sign-in page
    When I connect GitHub
    And I sign out of the admin
    And I come back from GitHub again with the same state
    Then the connection answer has status 401
    And the site holds no GitHub connection

  Scenario: The site refuses a state the second time it comes back
    Given GitHub shows its sign-in page
    And GitHub's token exchange grants "repo,read:org"
    And GitHub answers as the user "aaronmallen"
    When I connect GitHub
    And I approve the connection
    And the site drops every GitHub connection
    And I come back from GitHub again with the same state
    Then the site holds no GitHub connection

  Scenario: GitHub takes one account
    Given a GitHub connection as "@someone" with the token "ghp_token"
    And GitHub shows its sign-in page
    And GitHub's token exchange grants "repo,read:org"
    And GitHub answers as the user "aaronmallen"
    When I start a GitHub connect from a stale tab
    And I approve the connection
    Then the connection toast says "GitHub takes one account"
    And the site holds the GitHub connections "@someone"

  Scenario: A failed token exchange saves nothing
    Given GitHub shows its sign-in page
    And GitHub's token exchange fails
    When I connect GitHub
    And I approve the connection
    Then the site holds no GitHub connection

  Scenario: A personal access token GitHub accepts saves the account with the token sealed
    Given GitHub answers as the user "aaronmallen"
    When I paste the GitHub token " ghp_new "
    Then the services address opens the connection "@aaronmallen"
    And the connection toast says "GitHub connected as @aaronmallen"
    And the GitHub connection "@aaronmallen" holds the credentials '{"access_token": "ghp_new", "auth": "credentials"}'
    And the stored GitHub credentials do not hold "ghp_new"
    And the service line "Signed in with" shows "personal access token"
    And I do not see "Read repositories and issues"

  Scenario: The record jobs read GitHub with a pasted token and no restart
    Given GitHub answers as the user "aaronmallen"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": []}}}}
      """
    When I paste the GitHub token "ghp_new"
    And the GitHub commit import runs on the new connection
    Then GitHub received POST "/graphql"

  Scenario: The token form says GitHub takes a fine-grained token
    When I visit "/admin/settings/services?connect=github"
    Then the service panel shows "Classic or fine-grained."

  Scenario: A token GitHub refuses saves nothing and shows why
    Given GitHub refuses the token with "Bad credentials"
    When I paste the GitHub token "ghp_bad"
    Then the connection answer has status 422
    And the service panel shows the error "Bad credentials"
    And the site holds no GitHub connection

  Scenario: A blank token saves nothing and never reaches GitHub
    When I paste the GitHub token "  "
    Then the service panel shows the error "Paste a token first"
    And GitHub received no GET "/user"

  Scenario: The site refuses a token while GitHub is connected
    Given a GitHub connection as "@someone" with the token "ghp_token"
    And GitHub answers as the user "aaronmallen"
    When I paste the GitHub token "ghp_new"
    Then the service panel shows the error "The site holds one account"
    And the site holds the GitHub connections "@someone"

  Scenario: A test reports that GitHub answers a pasted token
    Given a GitHub connection as "@aaronmallen" with the pasted token "ghp_new"
    And GitHub answers as the user "aaronmallen"
    When I test the connection "@aaronmallen"
    Then the connection toast says "GitHub answered"

  Scenario: A test reports that GitHub refuses a pasted token
    Given a GitHub connection as "@aaronmallen" with the pasted token "ghp_new"
    And GitHub refuses the token with "Bad credentials"
    When I test the connection "@aaronmallen"
    Then the connection toast says "GitHub isn't answering"
    And the connection toast says "Bad credentials"

  Scenario: Disconnecting a pasted token deletes the row and asks me to revoke it on GitHub
    Given a GitHub connection as "@aaronmallen" with the pasted token "ghp_new"
    When I disconnect the connection "@aaronmallen"
    Then the connection toast says "revoke its token on GitHub"
    And the site holds no GitHub connection
    And GitHub received no DELETE "/applications/stub-client-id/token"

  Scenario: Disconnecting revokes the token on GitHub and deletes the row
    Given a GitHub connection as "@aaronmallen" with the token "ghp_token"
    And GitHub answers DELETE "/applications/stub-client-id/token" with status 204
    When I disconnect the connection "@aaronmallen"
    Then GitHub received DELETE "/applications/stub-client-id/token" holding "ghp_token"
    And the site holds no GitHub connection

  Scenario: Disconnecting deletes the row when GitHub will not revoke
    Given a GitHub connection as "@aaronmallen" with the token "ghp_token"
    And GitHub answers DELETE "/applications/stub-client-id/token" with status 422
    When I disconnect the connection "@aaronmallen"
    Then the site holds no GitHub connection

  Scenario: Disconnecting a connection it does not hold answers not found
    Given a GitHub connection as "@aaronmallen" with the token "ghp_token"
    When I disconnect the connection "@aaronmallen" after it is gone
    Then the connection answer has status 404
