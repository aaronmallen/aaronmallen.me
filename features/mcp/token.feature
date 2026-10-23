Feature: OAuth token
  An approved MCP client trades its code and PKCE verifier for tokens, and rotates its refresh token.

  Background:
    Given an MCP client approved for "read suggest"

  Scenario: Exchanging a code hands out a bearer pair, kept out of caches and stored only as digests
    When the MCP client exchanges its code
    Then the answer is 200
    And the answer has the header "Content-Type" set to "application/json"
    And the answer has the header "Cache-Control" set to "no-store"
    And the API answer at "access_token" is a word
    And the API answer at "refresh_token" is a word
    And the API answer holds:
      """
      { "token_type": "Bearer", "expires_in": 3600, "scope": "read suggest" }
      """
    And the access token lasts an hour and the refresh token thirty days
    And the access token is stored as its digest and never in plain text
    And the stored tokens are tied to the client, the resource and the scopes "read suggest"
    And the database answers "true" for:
      """
      SELECT used_at IS NOT NULL FROM oauth_codes
      """

  Scenario: A code exchanged twice is refused and revokes what it bought
    When the MCP client exchanges its code
    And the MCP client exchanges its code
    Then the answer is 400
    And the OAuth error is "invalid_grant"
    And the database answers "true" for:
      """
      SELECT bool_and(revoked_at IS NOT NULL) FROM oauth_tokens
      """

  Scenario Outline: A code exchange with <what> is refused as <error> and issues no token
    Given another MCP client is registered
    When the MCP client exchanges its code with:
      | <field> | <value> |
    Then the OAuth error is "<error>"
    And the table oauth_tokens holds 0 rows

    Examples:
      | what                       | field         | value                                           | error          |
      | another PKCE verifier      | code_verifier | dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXkAAAA | invalid_grant  |
      | no PKCE verifier           | code_verifier | (none)                                          | invalid_grant  |
      | another redirect URI       | redirect_uri  | https://elsewhere.example/callback              | invalid_grant  |
      | no redirect URI            | redirect_uri  | (none)                                          | invalid_grant  |
      | a code it never issued     | code          | fQeOyzc13iWZbKK6piRoLGRaNtdsEpQGgK5p7G9VIVA     | invalid_grant  |
      | another client             | client_id     | {otherclient}                                  | invalid_client |

  Scenario: A code that expired is refused
    Given the database runs "UPDATE oauth_codes SET expires_at = now() - interval '1 second'"
    When the MCP client exchanges its code
    Then the OAuth error is "invalid_grant"

  Scenario Outline: A code exchange carrying <value> for <field> is refused
    When the MCP client exchanges its code with:
      | <field> | <value> |
    Then the OAuth error is "invalid_grant"
    And the table oauth_tokens holds 0 rows

    Examples:
      | field         | value                                               |
      | code          | short                                               |
      | code          | fQeOyzc13iWZbKK6piRoLGRaNtdsEpQGgK5p7G9VIVU\u0000   |
      | code          |                                                     |
      | code_verifier | short                                               |
      | code_verifier | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      | code_verifier | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/         |
      | code_verifier |                                                     |
      | redirect_uri  | https://claude.ai/\u0000                            |
      | redirect_uri  |                                                     |

  Scenario Outline: A code exchange sending <field> as a list is refused as <error>
    When the MCP client exchanges its code sending <field> as a list
    Then the OAuth error is "<error>"

    Examples:
      | field         | error                  |
      | grant_type    | unsupported_grant_type |
      | code          | invalid_grant          |
      | code_verifier | invalid_grant          |
      | redirect_uri  | invalid_grant          |

  Scenario: Refreshing hands out a new pair with the same resource and scopes, and retires the old one
    When the MCP client exchanges its code
    And I keep the answer's "access_token" as "firstaccess"
    And I keep the answer's "refresh_token" as "firstrefresh"
    And the MCP client refreshes with the token kept as "firstrefresh"
    And I keep the answer's "access_token" as "secondaccess"
    And I keep the answer's "refresh_token" as "secondrefresh"
    Then the answer is 200
    And the token kept as "firstrefresh" is revoked
    And the token kept as "firstaccess" is revoked
    And the token kept as "secondaccess" is live
    And the new refresh token is tied to the new access token
    And the database answers "read suggest" for:
      """
      SELECT DISTINCT array_to_string(scopes, ' ') FROM oauth_tokens WHERE revoked_at IS NULL
      """
    When the MCP client refreshes with the token kept as "secondrefresh" and:
      | scope | read suggest write |
    Then the API answer at "scope" is '"read suggest"'

  Scenario: A spent refresh token comes back refused and revokes every token of the client
    When the MCP client exchanges its code
    And I keep the answer's "refresh_token" as "firstrefresh"
    And the MCP client refreshes with the token kept as "firstrefresh"
    And the MCP client refreshes with the token kept as "firstrefresh"
    Then the OAuth error is "invalid_grant"
    And the database answers "true" for:
      """
      SELECT bool_and(revoked_at IS NOT NULL) FROM oauth_tokens
      """

  Scenario: Refreshing one of two pairs leaves the other live
    When the MCP client exchanges its code
    And I keep the answer's "access_token" as "otheraccess"
    And I keep the answer's "refresh_token" as "otherrefresh"
    And the MCP client asks the owner again and is approved
    And the MCP client exchanges its code
    And I keep the answer's "refresh_token" as "mine"
    And the MCP client refreshes with the token kept as "mine"
    Then the token kept as "otheraccess" is live
    And the token kept as "otherrefresh" is live

  Scenario: A pair issued before tokens were tied together rotates and leaves the old access token to expire
    When the MCP client exchanges its code
    And I keep the answer's "access_token" as "firstaccess"
    And I keep the answer's "refresh_token" as "firstrefresh"
    And the database runs "UPDATE oauth_tokens SET access_token_id = NULL"
    And the MCP client refreshes with the token kept as "firstrefresh"
    Then the API answer at "refresh_token" is a word
    And the token kept as "firstaccess" is live

  Scenario Outline: A refresh with <what> is refused as <error>
    Given another MCP client is registered
    When the MCP client exchanges its code
    And I keep the answer's "access_token" as "access"
    And I keep the answer's "refresh_token" as "refresh"
    And <setup>
    Then the OAuth error is "<error>"

    Examples:
      | what                              | setup                                                                                    | error          |
      | a refresh token it never issued   | the MCP client refreshes with the refresh token "wphZugY-nt2viw44vPHDmX1z_nIzf4j80ca6mhNmJYA" | invalid_grant |
      | an access token                   | the MCP client refreshes with the token kept as "access"                                 | invalid_grant  |
      | another client                    | the MCP client refreshes with the token kept as "refresh" and the other client          | invalid_client |
      | a short refresh token             | the MCP client refreshes with the refresh token "short"                                  | invalid_grant  |
      | a refresh token with a line break | the MCP client refreshes with the refresh token "wphZugY-nt2viw44vPHDmX1z_nIzf4j80ca6mhNmJYM\n" | invalid_grant |
      | an empty refresh token            | the MCP client refreshes with the refresh token ""                                       | invalid_grant  |
      | no refresh token                  | the MCP client refreshes with the refresh token "(none)"                                 | invalid_grant  |
      | a refresh token sent as a list    | the MCP client refreshes sending the token kept as "refresh" as a list                   | invalid_grant  |

  Scenario: A refresh token that expired is refused
    When the MCP client exchanges its code
    And I keep the answer's "refresh_token" as "refresh"
    And the database runs "UPDATE oauth_tokens SET expires_at = now() - interval '1 second' WHERE type = 'refresh'"
    And the MCP client refreshes with the token kept as "refresh"
    Then the OAuth error is "invalid_grant"

  Scenario: Two exchanges of one code at once grant one, refuse the other and revoke the pair
    When the MCP client exchanges its code twice at once
    Then the answers kept are "200 400"
    And the errors kept hold "invalid_grant"
    And the database answers "access, refresh, true" for:
      """
      SELECT string_agg(type::text, ', ' ORDER BY type), bool_and(revoked_at IS NOT NULL) FROM oauth_tokens
      """
    And the database answers "true" for:
      """
      SELECT used_at IS NOT NULL FROM oauth_codes
      """

  Scenario: Two refreshes with one token at once rotate one, refuse the other and leave nothing to spend
    When the MCP client exchanges its code
    And I keep the answer's "refresh_token" as "refresh"
    And the MCP client refreshes with the token kept as "refresh" twice at once
    Then the answers kept are "200 400"
    And the database answers "true, 0" for:
      """
      SELECT bool_and(revoked_at IS NOT NULL), count(*) FILTER (WHERE type = 'refresh' AND revoked_at IS NULL AND expires_at > now()) FROM oauth_tokens
      """

  Scenario: A revoke that lands during a code exchange leaves no live token
    When the owner revokes the MCP client while it exchanges its code
    Then the database answers "0" for:
      """
      SELECT count(*) FROM oauth_tokens WHERE revoked_at IS NULL
      """

  Scenario: A revoke that lands during a refresh leaves no live token
    When the MCP client exchanges its code
    And I keep the answer's "refresh_token" as "refresh"
    And the owner revokes the MCP client while it refreshes with the token kept as "refresh"
    Then the database answers "0" for:
      """
      SELECT count(*) FROM oauth_tokens WHERE revoked_at IS NULL
      """

  Scenario: A client the owner revoked connects again once the owner approves it
    When the MCP client exchanges its code
    And the owner revokes the MCP client
    And the MCP client asks the owner again and is approved
    And the MCP client exchanges its code
    Then the answer is 200

  Scenario: The token endpoint refuses a grant it does not run, a request with no grant, and anything but POST
    When a stranger posts to the token endpoint with:
      | grant_type | client_credentials |
    Then the OAuth error is "unsupported_grant_type"
    When a stranger posts nothing to the token endpoint
    Then the answer is 400
    When I send GET "/oauth/token"
    Then the answer is 405

  Scenario: The verifier from RFC 7636 matches the challenge the RFC hashes it to
    Given the MCP client uses the verifier and challenge from RFC 7636
    When the MCP client exchanges its code
    Then the answer is 200

  Scenario: A code asked for without a redirect URI takes an exchange that leaves it out or names the fallback, and no other
    Given an MCP client approved for "read" without a redirect URI
    When the MCP client exchanges its code with:
      | redirect_uri | (none) |
    Then the answer is 200

  Scenario: A code asked for without a redirect URI takes an exchange that names the URI it fell back to
    Given an MCP client approved for "read" without a redirect URI
    When the MCP client exchanges its code
    Then the answer is 200

  Scenario: A code asked for without a redirect URI refuses another one and issues no token
    Given an MCP client approved for "read" without a redirect URI
    When the MCP client exchanges its code with:
      | redirect_uri | https://elsewhere.example/callback |
    Then the OAuth error is "invalid_grant"
    And the table oauth_tokens holds 0 rows
