Feature: Dynamic client registration
  An MCP client registers itself, as a public client with the code and refresh grants, a few at a time from one sender.

  Scenario: A registration Claude sends is stored and answered in JSON as a public client
    When a client registers with:
      """
      { "client_name": "Claude", "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"] }
      """
    Then the answer is 201
    And the answer has the header "Content-Type" set to "application/json"
    And the API answer holds:
      """
      { "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"], "token_endpoint_auth_method": "none",
        "grant_types": ["authorization_code", "refresh_token"], "response_types": ["code"] }
      """
    And the API answer at "client_id" is a word
    And the API answer at "client_id_issued_at" is about now in seconds
    And the API answer has no "client_secret"
    And the database answers "Claude, https://claude.ai/api/mcp/auth_callback" for:
      """
      SELECT client_name, array_to_string(redirect_uris, ' ') FROM oauth_clients
      """
    And the stored client keeps a daily visitor hash, not the address
    And the answer has no header "Access-Control-Allow-Origin"

  Scenario: Registrations past the limit come back throttled in JSON, before the body is read, and store no more
    When 11 clients register with:
      """
      { "client_name": "Claude", "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"] }
      """
    Then the answer is 429
    And the answer has the header "Content-Type" set to "application/json"
    And the API answer at "error" is '"temporarily_unavailable"'
    And the table oauth_clients holds 10 rows
    When a client registers with the body ""
    Then the answer is 429

  Scenario: A registration once the window has passed goes through
    When 10 clients register with:
      """
      { "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"] }
      """
    And the database runs "UPDATE oauth_clients SET created_at = now() - interval '61 minutes'"
    And a client registers with:
      """
      { "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"] }
      """
    Then the answer is 201

  Scenario: Each client gets its own ID, and the grants are settled whatever the client asks for
    When 2 clients register with:
      """
      { "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"], "grant_types": ["client_credentials"], "token_endpoint_auth_method": "none" }
      """
    Then the API answer at "grant_types" is '["authorization_code", "refresh_token"]'
    And the database answers "2" for:
      """
      SELECT count(DISTINCT client_id) FROM oauth_clients
      """

  Scenario Outline: The redirect URI <uri> is taken
    When a client registers with the body '{"redirect_uris": ["<uri>"]}'
    Then the answer is 201

    Examples:
      | uri                                     |
      | https://claude.ai/api/mcp/auth_callback |
      | http://localhost:53941/callback         |
      | http://127.0.0.1:53941/callback         |
      | http://[::1]:53941/callback             |
      | https://claude.ai/callback?next=1       |

  Scenario: More than one redirect URI is taken, and a padded one is stored and given back as validated
    When a client registers with:
      """
      { "redirect_uris": ["http://localhost:1234/callback", "http://127.0.0.1:1234/callback"] }
      """
    Then the API answer at "redirect_uris" holds 2 items
    When a client registers with:
      """
      { "redirect_uris": [" https://claude.ai/api/mcp/auth_callback "] }
      """
    Then the API answer at "redirect_uris" is '["https://claude.ai/api/mcp/auth_callback"]'
    And the database answers "https://claude.ai/api/mcp/auth_callback" for:
      """
      SELECT array_to_string(redirect_uris, ' ') FROM oauth_clients ORDER BY id DESC LIMIT 1
      """

  Scenario Outline: A registration with <what> is refused for its redirect URI and stores nothing
    When a client registers with the body '<body>'
    Then the answer is 400
    And the API answer at "error" is '"invalid_redirect_uri"'
    And the table oauth_clients holds 0 rows

    Examples:
      | what                                                   | body                                                                |
      | no redirect URIs at all                                | {"client_name": "Claude"}                                           |
      | an empty list of redirect URIs                         | {"redirect_uris": []}                                               |
      | a redirect URI that is not a URI                       | {"redirect_uris": ["not a uri"]}                                    |
      | a relative redirect URI                                | {"redirect_uris": ["/callback"]}                                    |
      | a redirect URI with a fragment                         | {"redirect_uris": ["https://claude.ai/callback#code"]}              |
      | a redirect URI with userinfo                           | {"redirect_uris": ["https://claude.ai@evil.example/callback"]}      |
      | a redirect URI with a user and password                | {"redirect_uris": ["https://user:secret@claude.ai/callback"]}       |
      | a loopback redirect URI with userinfo                  | {"redirect_uris": ["http://claude.ai@localhost:53941/callback"]}    |
      | a plain HTTP redirect URI on a host that starts like localhost | {"redirect_uris": ["http://localhost.evil.example/callback"]} |
      | a redirect URI in an app's own scheme                  | {"redirect_uris": ["claude://callback"]}                            |
      | a redirect URI with no host                            | {"redirect_uris": ["https://"]}                                     |
      | an empty redirect URI                                  | {"redirect_uris": [""]}                                             |
      | a null redirect URI                                    | {"redirect_uris": [null]}                                           |
      | a plain HTTP redirect URI on another host              | {"redirect_uris": ["http://claude.ai/api/mcp/auth_callback"]}       |
      | a redirect URI in another scheme                       | {"redirect_uris": ["ftp://claude.ai/callback"]}                     |
      | a redirect URI that is not a string                    | {"redirect_uris": [42]}                                             |
      | redirect URIs that are not a list                      | {"redirect_uris": "https://claude.ai/api/mcp/auth_callback"}        |
      | more redirect URIs than anyone needs                   | {"redirect_uris": ["https://claude.ai/callback/0", "https://claude.ai/callback/1", "https://claude.ai/callback/2", "https://claude.ai/callback/3", "https://claude.ai/callback/4", "https://claude.ai/callback/5", "https://claude.ai/callback/6", "https://claude.ai/callback/7", "https://claude.ai/callback/8", "https://claude.ai/callback/9", "https://claude.ai/callback/10"]} |

  Scenario Outline: A registration with <what> is refused for its metadata, says why and stores nothing
    When a client registers with the body '{"redirect_uris": ["https://claude.ai/api/mcp/auth_callback"], <field>}'
    Then the answer is 400
    And the API answer at "error" is '"invalid_client_metadata"'
    And the API answer's "error_description" holds "control character"
    And the table oauth_clients holds 0 rows

    Examples:
      | what                     | field                                      |
      | a NUL in the client name | "client_name": "Cla\u0000ude"              |
      | a NUL in the client URI  | "client_uri": "https://clau\u0000de.ai"    |
      | a NUL in the logo URI    | "logo_uri": "https://claude.ai/logo\u0000.png" |

  Scenario: A client name ten thousand characters long is refused for its metadata
    When a client registers a client_name of 10000 "a"s
    Then the answer is 400
    And the API answer at "error" is '"invalid_client_metadata"'
    And the table oauth_clients holds 0 rows

  Scenario: Both wrong names the redirect URI
    When a client registers with the body '{"redirect_uris": ["/callback"], "client_name": "Cla\u0000ude"}'
    Then the API answer at "error" is '"invalid_redirect_uri"'

  Scenario Outline: A body it cannot read is refused for its metadata and explained
    When a client registers with the body '<body>'
    Then the answer is 400
    And the API answer at "error" is '"invalid_client_metadata"'
    And the API answer at "error_description" is a word

    Examples:
      | body                                          |
      | redirect_uris=https://claude.ai               |
      |                                               |
      | ["https://claude.ai/api/mcp/auth_callback"]   |

  Scenario: Registration answers only to POST
    When I send GET "/oauth/register"
    Then the answer is 405

  Scenario: The metadata may run to its caps and no further, and nothing but redirect URIs is enough
    When a client registers a client_name of 200 "a"s
    Then the answer is 201
    When a client registers a client_name of 201 "a"s
    Then the API answer at "error" is '"invalid_client_metadata"'
    When a client registers a client_uri of 2048 "a"s
    Then the API answer at "error" is '"invalid_client_metadata"'
    When a client registers a logo_uri of 2048 "a"s
    Then the API answer at "error" is '"invalid_client_metadata"'
    When a client registers with:
      """
      { "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"] }
      """
    Then the answer is 201
