Feature: API authentication
  The JSON API takes a bearer API token and refuses anything else, in JSON.

  Scenario: A request with no token is refused in JSON and asked for a bearer token
    When I call the API GET "token" with no token
    Then the API answers 401
    And the answer has the header "Content-Type" holding "application/json"
    And the API answer is:
      """
      { "error_description": "this endpoint takes a bearer API token" }
      """
    And the answer has the header "WWW-Authenticate" set to "Bearer"

  Scenario: A token it never minted is refused, naming the token
    When I call the API GET "token" with the token "never-minted-token-value-that-is-long-enough"
    Then the API answers 401
    And the API answer is:
      """
      { "error": "invalid_token", "error_description": "the API token is unknown, revoked or expired" }
      """
    And the answer has the header "WWW-Authenticate" set to "Bearer error=\"invalid_token\""

  Scenario: A scheme it does not take is refused
    Given an API token
    When I call the API GET "token" with the authorization "Basic {token}"
    Then the API answers 401

  Scenario Outline: A <state> token is refused as invalid
    Given an API token
    And the database runs "UPDATE api_tokens SET <change>"
    When I GET "/token" through the API
    Then the API answers 401
    And the API answer at "error" is "\"invalid_token\""

    Examples:
      | state   | change                                    |
      | revoked | revoked_at = now()                        |
      | expired | expires_at = now() - interval '1 second'  |

  Scenario: An MCP access token gets no way into the API, and an API token none into MCP
    Given I am signed in to the admin
    And an API token
    When an MCP client connects and I approve it
    And I call the API GET "token" with the MCP access token
    Then the API answers 401
    When I call MCP with the API token
    Then the API answers 401

  Scenario: A valid token reaches the slice in any case of the scheme, named and kept from caches
    Given an API token named "Laptop"
    When I call the API GET "token" with the authorization "bearer {token}"
    Then the API answers 200
    And the API answer at "name" is "\"Laptop\""
    And the answer has the header "Cache-Control" set to "private, no-store"

  Scenario: A call stamps the token's last use and answers with it
    Given an API token named "Laptop"
    When I GET "/token" through the API
    Then the API answers 200
    And the database answers "true" for:
      """
      SELECT last_used_at > now() - interval '1 minute' FROM api_tokens
      """
    And the API answer at "last_used_at" is the stored last use

  Scenario: A call stamps the last use again once five minutes have passed
    Given an API token named "Laptop"
    And the database runs "UPDATE api_tokens SET last_used_at = now() - interval '6 minutes'"
    When I GET "/token" through the API
    Then the database answers "true" for:
      """
      SELECT last_used_at > now() - interval '1 minute' FROM api_tokens
      """

  Scenario: A call within five minutes leaves the last use alone and answers with the one it kept
    Given an API token named "Laptop"
    And the database runs "UPDATE api_tokens SET last_used_at = date_trunc('second', now()) - interval '4 minutes'"
    When I GET "/token" through the API
    Then the database answers "true" for:
      """
      SELECT last_used_at = date_trunc('second', last_used_at) AND last_used_at < now() - interval '3 minutes' FROM api_tokens
      """
    And the API answer at "last_used_at" is the stored last use

  Scenario: A token takes calls before the day it expires
    Given an API token named "Laptop"
    And the database runs "UPDATE api_tokens SET expires_at = now() + interval '1 day'"
    When I GET "/token" through the API
    Then the API answers 200
