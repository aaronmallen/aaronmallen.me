Feature: MCP clients
  An MCP client connects through OAuth with PKCE once the owner approves it, then calls tools.

  Scenario: A connected client calls a tool
    Given a post "Hello world" published an hour ago
    And I am signed in to the admin
    When an MCP client connects and I approve it
    Then the MCP tool "list_posts" answers with "Hello world"
