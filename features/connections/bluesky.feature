Feature: Bluesky connection
  I connect Bluesky accounts with a handle and an app password. The site signs
  in with the pair before it keeps it, sealed.

  Background:
    Given I am signed in to the admin

  Scenario: The connect form asks for a handle and an app password
    When I visit "/admin/settings/services?connect=bluesky"
    Then the Bluesky form asks for a handle and an app password
    And the page has no axe breaches in light or dark

  Scenario: A pair Bluesky takes saves the account under its DID with the pair sealed
    Given Bluesky signs in "aaron.bsky.social"
    When I connect Bluesky as " aaron.bsky.social " with the app password "abcd-efgh"
    Then Bluesky received POST "/xrpc/com.atproto.server.createSession" holding "\"identifier\":\"aaron.bsky.social\""
    And Bluesky received POST "/xrpc/com.atproto.server.createSession" holding "\"password\":\"abcd-efgh\""
    And the site holds the Bluesky connections "@aaron.bsky.social"
    And the Bluesky connection "@aaron.bsky.social" has the account "did:plc:ada" and the scopes ""
    And the Bluesky connection "@aaron.bsky.social" holds the credentials '{"app_password": "abcd-efgh", "handle": "aaron.bsky.social"}'
    And the stored Bluesky credentials do not hold "abcd-efgh"
    And the connection toast says "Bluesky connected as @aaron.bsky.social"

  Scenario: A pair Bluesky refuses saves nothing and says why
    Given Bluesky refuses the sign-in with "Invalid identifier or password"
    When I connect Bluesky as "aaron.bsky.social" with the app password "wrong"
    Then the connection answer has status 422
    And the service panel shows the error "Invalid identifier or password"
    And the site holds no Bluesky connection

  Scenario: A blank app password saves nothing and never reaches Bluesky
    When I connect Bluesky as "aaron.bsky.social" with the app password " "
    Then the service panel shows the error "Paste an app password first"
    And Bluesky received no POST "/xrpc/com.atproto.server.createSession"
    And the site holds no Bluesky connection

  Scenario: A connected account offers a test, another account and a disconnect
    Given a Bluesky connection as "ada.example"
    When I open the connection "@ada.example"
    Then the service panel offers "Test connection"
    And the service panel links "Add another account" to "/admin/settings/services?connect=bluesky#services"
    And the service panel offers "Disconnect"

  Scenario: A test reports that Bluesky answers
    Given a Bluesky connection as "ada.example"
    And Bluesky signs in "ada.example"
    When I test the connection "@ada.example"
    Then the connection toast says "Bluesky answered"

  Scenario: A test reports that Bluesky refuses the pair
    Given a Bluesky connection as "ada.example"
    And Bluesky refuses the sign-in with "Invalid identifier or password"
    When I test the connection "@ada.example"
    Then the connection toast says "Bluesky isn't answering"
    And the connection toast says "Invalid identifier or password"

  Scenario: A disconnect deletes the account
    Given a Bluesky connection as "ada.example"
    When I disconnect the connection "@ada.example"
    Then the site holds no Bluesky connection
