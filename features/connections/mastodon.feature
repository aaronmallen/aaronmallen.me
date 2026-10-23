Feature: Mastodon connection
  I connect Mastodon accounts on any server. The site registers itself on the
  server once, then signs in with PKCE.

  Background:
    Given I am signed in to the admin

  Scenario: The picker asks for my server beside a cancel that only closes it
    When I visit "/admin/settings/services"
    Then the Mastodon connect dialog asks for the server beside a cancel

  Scenario: Connecting registers the site once and sends me to my server for the scopes it needs
    Given the Mastodon server "203.0.113.9" grants the account "aaronmallen"
    When I connect Mastodon on "https://203.0.113.9/@aaronmallen"
    Then I see "Sign in to approve"
    And the authorize request went to "/mastodon/203.0.113.9/oauth/authorize"
    And the authorize request asked with "client_id" as "app-id"
    And the authorize request asked with "scope" as "write:statuses write:media read:accounts read:search read:statuses"
    And the authorize request sent a PKCE challenge and comes back to "/admin/auth/mastodon/callback"
    And Mastodon received POST "/203.0.113.9/api/v1/apps" holding "scopes=write%3Astatuses%20write%3Amedia%20read%3Aaccounts%20read%3Asearch%20read%3Astatuses"
    And Mastodon received POST "/203.0.113.9/api/v1/apps" holding "%2Fadmin%2Fauth%2Fmastodon%2Fcallback"
    When I connect Mastodon on "203.0.113.9"
    Then I see "Sign in to approve"
    And the authorize request asked with "client_id" as "app-id"
    And Mastodon received POST "/203.0.113.9/api/v1/apps" once

  Scenario: Connecting registers the site again when the app it holds asked for other scopes
    Given the Mastodon server "203.0.113.9" holds an app with the scopes "read"
    And the Mastodon server "203.0.113.9" grants the account "aaronmallen"
    When I connect Mastodon on "203.0.113.9"
    Then I see "Sign in to approve"
    And the authorize request asked with "client_id" as "app-id"
    And the site holds one Mastodon app on "203.0.113.9" with the scopes "write:statuses write:media read:accounts read:search read:statuses"

  Scenario Outline: The site refuses a server it cannot use before anything leaves the site
    When I connect Mastodon on "<server>"
    Then the connection toast says "That isn't a server name"
    And the site holds no Mastodon connection

    Examples:
      | server       |
      | not a server |
      | 127.0.0.1    |
      | 192.168.1.20 |

  Scenario: The site refuses a server that does not answer as Mastodon
    Given Mastodon answers POST "/203.0.113.9/api/v1/apps" with status 404
    When I connect Mastodon on "203.0.113.9"
    Then the connection toast says "didn't answer as Mastodon"
    And the services address is "/admin/settings/services#services"

  Scenario: The server grants access and the site saves the account on its server
    Given the Mastodon server "203.0.113.9" grants the account "aaronmallen"
    When I connect Mastodon on "203.0.113.9"
    And I approve the connection
    Then the connection toast says "Mastodon connected as @aaronmallen@203.0.113.9"
    And the site holds the Mastodon connections "@aaronmallen@203.0.113.9"
    And the Mastodon connection "@aaronmallen@203.0.113.9" sits on "203.0.113.9"
    And the Mastodon connection "@aaronmallen@203.0.113.9" has the account "109" and the scopes "write:statuses write:media read:accounts read:search read:statuses"
    And the Mastodon connection "@aaronmallen@203.0.113.9" holds the credentials '{"access_token": "masto-token", "client_id": "app-id"}'
    And Mastodon received POST "/203.0.113.9/oauth/token" holding "code_verifier="

  Scenario: Reconnecting an account it holds replaces the token and keeps its scheduled posts
    Given a Mastodon connection as "@old@203.0.113.9" on "203.0.113.9" with the scopes "write:statuses"
    And a scheduled Mastodon post delivered through "@old@203.0.113.9"
    And the Mastodon server "203.0.113.9" grants the account "aaronmallen"
    When I connect Mastodon on "203.0.113.9"
    And I approve the connection
    Then the connection toast says "Mastodon connected as @aaronmallen@203.0.113.9"
    And the site holds the Mastodon connections "@aaronmallen@203.0.113.9"
    And the Mastodon connection "@aaronmallen@203.0.113.9" is still row 1
    And the Mastodon connection "@aaronmallen@203.0.113.9" holds the credentials '{"access_token": "masto-token", "client_id": "app-id"}'
    And the social post deliveries point at the Mastodon connection "@aaronmallen@203.0.113.9"

  Scenario: The same account on another server is its own connection
    Given a Mastodon connection as "@old@203.0.113.10" on "203.0.113.10" with the scopes "write:statuses"
    And the Mastodon server "203.0.113.9" grants the account "aaronmallen"
    When I connect Mastodon on "203.0.113.9"
    And I approve the connection
    Then the Mastodon connections sit on "203.0.113.10, 203.0.113.9"

  Scenario: Declining on the server saves nothing
    Given the Mastodon server "203.0.113.9" grants the account "aaronmallen"
    When I connect Mastodon on "203.0.113.9"
    And I decline the connection
    Then the connection toast says "Mastodon didn't grant access"
    And the site holds no Mastodon connection

  Scenario: The site refuses a state it never sent
    When I come back from Mastodon with a state it never sent
    Then the connection toast says "didn't start here"
    And the site holds no Mastodon connection

  Scenario: A failed token exchange saves nothing
    Given the Mastodon server "203.0.113.9" grants the account "aaronmallen"
    And Mastodon answers POST "/203.0.113.9/oauth/token" with status 500
    When I connect Mastodon on "203.0.113.9"
    And I approve the connection
    Then the connection toast says "didn't answer as Mastodon"
    And the site holds no Mastodon connection

  Scenario: Disconnecting revokes the token on the server and deletes the row
    Given the Mastodon server "203.0.113.9" grants the account "aaronmallen"
    And Mastodon answers POST "/203.0.113.9/oauth/revoke" with:
      """
      {}
      """
    When I connect Mastodon on "203.0.113.9"
    And I approve the connection
    Then the site holds the Mastodon connections "@aaronmallen@203.0.113.9"
    When I disconnect the connection "@aaronmallen@203.0.113.9"
    Then Mastodon received POST "/203.0.113.9/oauth/revoke" holding "client_id=app-id"
    And Mastodon received POST "/203.0.113.9/oauth/revoke" holding "client_secret=app-secret"
    And Mastodon received POST "/203.0.113.9/oauth/revoke" holding "token=masto-token"
    And the site holds no Mastodon connection

  Scenario: Disconnecting deletes the row when the server will not revoke
    Given the Mastodon server "203.0.113.9" grants the account "aaronmallen"
    And Mastodon answers POST "/203.0.113.9/oauth/revoke" with status 403
    When I connect Mastodon on "203.0.113.9"
    And I approve the connection
    Then the site holds the Mastodon connections "@aaronmallen@203.0.113.9"
    When I disconnect the connection "@aaronmallen@203.0.113.9"
    Then the site holds no Mastodon connection
