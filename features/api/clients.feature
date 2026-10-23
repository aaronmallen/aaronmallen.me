Feature: API MCP clients
  The API lists each MCP client holding a live token.

  Background:
    Given an API token

  Scenario: Each connected client shows its name, granted scopes and times
    Given the MCP clients:
      | name   | scopes     |
      | Cursor | read,write |
    When I GET "/clients" through the API
    Then the API answers 200
    And the API answer at "clients" matches:
      """
      [{ "id": 1, "name": "Cursor", "scopes": ["read", "write"], "last_used_at": null }]
      """
    And the API answer at "clients.0.created_at" is the client's creation time

  Scenario: A client with no name goes by its redirect host
    Given the MCP clients:
      | name | redirect                         |
      |      | https://cursor.example/callback |
    When I GET "/clients" through the API
    Then the API answer at "clients.0.name" is "\"cursor.example\""

  Scenario: A revoked client and one holding no live token stay out
    Given the MCP clients:
      | name    | tokens         |
      | Revoked | revoked access |
      | Bare    | none           |
    When I GET "/clients" through the API
    Then the API answer at "clients" is "[]"
