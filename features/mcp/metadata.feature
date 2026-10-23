Feature: OAuth discovery metadata
  The well-known documents tell a client where to register, authorize and trade codes, whatever Host it sends.

  Scenario: The protected resource metadata names the resource and its authorization server
    When I send GET "/.well-known/oauth-protected-resource/mcp"
    Then the answer is 200
    And the answer has the header "Access-Control-Allow-Origin" set to "*"
    And the answer has the header "Content-Type" set to "application/json"
    And the API answer holds:
      """
      { "authorization_servers": ["SITE"], "bearer_methods_supported": ["header"], "resource": "SITE/mcp",
        "resource_name": "127.0.0.1" }
      """
    And I keep the answer as "resource"
    When I send GET "/.well-known/oauth-protected-resource"
    Then the API answer is the one kept as "resource"

  Scenario: The authorization server metadata names its endpoints and the scopes, the same in both documents
    When I send GET "/.well-known/oauth-authorization-server"
    Then the answer is 200
    And the answer has the header "Access-Control-Allow-Origin" set to "*"
    And the answer has the header "Content-Type" set to "application/json"
    And the API answer holds:
      """
      { "authorization_endpoint": "SITE/oauth/authorize", "authorization_response_iss_parameter_supported": true,
        "code_challenge_methods_supported": ["S256"], "grant_types_supported": ["authorization_code", "refresh_token"],
        "issuer": "SITE", "registration_endpoint": "SITE/oauth/register",
        "scopes_supported": ["read", "suggest", "write", "publish", "delete", "health", "mail", "agents", "notes", "contacts"],
        "token_endpoint": "SITE/oauth/token", "token_endpoint_auth_methods_supported": ["none"] }
      """
    And the scopes it names match the protected resource's
    And its registration endpoint registers a client

  Scenario: A request whose Host somebody else picked still names the configured issuer and resource
    When I send GET "/.well-known/oauth-authorization-server" with the forwarded host "evil.example"
    Then the API answer holds:
      """
      { "issuer": "SITE", "authorization_endpoint": "SITE/oauth/authorize", "registration_endpoint": "SITE/oauth/register",
        "token_endpoint": "SITE/oauth/token" }
      """
    When I send GET "/.well-known/oauth-protected-resource/mcp" with the forwarded host "evil.example"
    Then the API answer holds:
      """
      { "resource": "SITE/mcp", "resource_name": "127.0.0.1", "authorization_servers": ["SITE"] }
      """

  Scenario: The rest of the site stays with the app, and unknown paths answer 404
    When I send GET "/writing"
    Then the answer is 200
    When I send GET "/nothing-here"
    Then the answer is 404
