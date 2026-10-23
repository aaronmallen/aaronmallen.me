Feature: OAuth authorization
  The owner approves or cancels each MCP client's request on a page that says what the client gets.

  Background:
    Given "owner@example.com" is an owner
    And the MCP clients:
      | name   | tokens |
      | Claude | none   |

  Scenario: Signed out, the request sends me to sign in, issues no code, and comes back once I sign in
    When the client "Claude" asks to be authorized
    Then the answer sends me to "/admin/sign-in"
    And no code is issued
    When I start a GitHub sign-in from "/admin/sign-in"
    And GitHub calls back to the last sign-in
    Then the answer sends me to the authorization the client "Claude" asks for
    When the client "Claude" asks to be authorized
    Then the answer is 200
    And the answer shows "action=\"/oauth/authorize\""

  Scenario: An approval it never showed me issues no code
    When a stranger posts an approval for the client "Claude" that was never shown
    Then no code is issued

  Scenario: A session cookie copied before signing out is sent to sign in
    Given I am signed in to the admin
    And I signed out but keep a copy of my session cookie
    When the client "Claude" asks to be authorized
    Then the answer sends me to "/admin/sign-in"

  Scenario: Another account that signs in is refused and asked to sign in again, with no code
    When the client "Claude" asks to be authorized
    And GitHub says the account's email is "stranger@example.com"
    And I sign in with GitHub from "/admin/sign-in"
    Then the answer is 403
    When the client "Claude" asks to be authorized
    Then the answer sends me to "/admin/sign-in"
    And no code is issued

  Scenario: Signed in, the request answers with a page that names the host, the client and what it gets
    Given I am signed in to the admin
    When the client "Claude" asks to be authorized
    Then the answer is 200
    And the answer has no header "Location"
    And the answer has the header "X-Robots-Tag" set to "noindex, nofollow"
    And no code is issued
    When I open the authorization the client "Claude" asks for
    Then the text of "h1" is "Connect the app at claude.ai?"
    And the text of ".page-head-sub" is "It calls itself Claude. Any app can pick that name."
    And the page has no ".connect-warn"
    And the page says "Read everything the site keeps"
    And the page says "Send you suggested edits to accept or reject"
    And the page does not say "Make any change the admin makes"
    And "form input[name='scope']" has the "value" "read suggest"
    And the text of "p.hint" holds "https://claude.ai/api/mcp/auth_callback"
    And the page has "button.bt.pri[type='submit'][name='decision'][value='approve']:has-text('Approve')"
    And the page has "button.bt:not(.pri)[type='submit'][name='decision'][value='cancel']:has-text('Cancel')"
    And the page has "form input[name='_csrf_token']"
    And the page's content security policy holds directives starting:
      | frame-ancestors 'none'         |
      | default-src 'none'             |
      | script-src 'self' 'sha256-     |
      | object-src 'none'              |
      | form-action 'self' https: http: |
    And the page has no axe breaches in light or dark

  Scenario: A read request says the journal and every commit cross, private repositories too
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | scope | read |
    Then the page says "your journal"
    And the page says "whole message and all, private and work repositories included"

  Scenario: A write request keeps publishing, sending and deleting out and warns of nothing
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | scope | read write |
    Then the text of "li:has-text('Make any change the admin makes')" holds "short of publishing, sending and deleting"
    And the page has no ".connect-warn"

  Scenario: A publish and delete request shows both lines and warns on publishing
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | scope | read write publish delete |
    Then the page has "li:has-text('Publish posts, send social posts and make any change that shows in public') .connect-warn"
    And the page has "li:has-text('Delete posts, social posts and any other record for good')"
    And the text of ".connect-warn" is "You cannot take back a published post or a sent social post."

  Scenario Outline: A <scope> request shows its line and what read leaves out
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | scope | read <scope> |
    Then the page has "li:has-text('<line>')"
    And the page has "li:has-text(\"<read>\")"

    Examples:
      | scope    | line                                     | read                                                                          |
      | health   | Read your health data                    | Read everything the site keeps but your health data                          |
      | mail     | Read, mark, tag, snooze and delete your mail | Read everything the site keeps but your health data, mail                 |
      | agents   | Read and change agent memory             | Read everything the site keeps but your health data, mail, agent memory, notes |
      | notes    | Read, write, rename, move, tag and pin your private notes | Read everything the site keeps                                |
      | contacts | Read and change the private fields of your contacts | notes and contacts' private fields: posts                         |

  Scenario: A client that has never held a token is new, and says when it registered
    Given I am signed in to the admin
    And the MCP clients:
      | name  | tokens | connected                                |
      | Fresh | none   | (TIMESTAMPTZ '2026-09-03 15:04:00+00')   |
    When I open the authorization the client "Fresh" asks for
    Then the text of ".connect-notice" is "This app has never connected before. It registered on Sep 3, 2026, 10:04."
    And ".connect-notice time" has the "datetime" "2026-09-03T10:04:00-05:00"

  Scenario: A client that holds a token, or used one it no longer holds, is not new
    Given I am signed in to the admin
    And the MCP clients:
      | name  | tokens | last used  |
      | Held  | access |            |
      | Spent | none   | 1 day ago  |
    When I open the authorization the client "Held" asks for
    Then the page has no ".connect-notice"
    When I open the authorization the client "Spent" asks for
    Then the page has no ".connect-notice"

  Scenario: A client with no name still leads with its host and says it gave no name
    Given I am signed in to the admin
    And the MCP clients:
      | name | tokens |
      |      | none   |
    When I open the authorization the client "" asks for
    Then the text of "h1" is "Connect the app at claude.ai?"
    And the text of ".page-head-sub" is "It gave no name."

  Scenario: A client whose redirect URI does not parse is still asked about as an app
    Given I am signed in to the admin
    And the MCP clients:
      | name | tokens | redirect  |
      |      | none   | not a uri |
    When the client "" asks to be authorized
    Then the answer is 200
    When I open the authorization the client "" asks for
    Then the text of "h1" is "Approve this app?"
    And the text of ".page-head-sub" is "It gave no name."

  Scenario: A client registered with a padded redirect URI is stored, refused and approved in the validated form
    Given I am signed in to the admin
    And the database runs "DELETE FROM oauth_clients"
    When a client registers with:
      """
      { "client_name": "Claude", "redirect_uris": [" https://claude.ai/api/mcp/auth_callback"] }
      """
    Then the database answers "https://claude.ai/api/mcp/auth_callback" for:
      """
      SELECT array_to_string(redirect_uris, ' ') FROM oauth_clients
      """
    When I open the authorization the client "Claude" asks for with:
      | response_type | token |
    Then the page links back to "https://claude.ai/api/mcp/auth_callback" carrying:
      | error | unsupported_response_type |
    And the page has "section.card a.bt:has-text('Go back to claude.ai')"
    And the page has "section.card p.hint"
    And no code is issued
    When the client "Claude" asks to be authorized with:
      | redirect_uri | (space)https://claude.ai/api/mcp/auth_callback |
    Then the answer is 400
    When I approve the authorization the client "Claude" asks for
    Then the callback goes to the client's redirect URI "https://claude.ai/api/mcp/auth_callback"
    And the code is tied to the redirect URI "https://claude.ai/api/mcp/auth_callback"

  Scenario: Approving sends me back with a code, the state and the issuer, and stores the code hashed and tied
    Given I am signed in to the admin
    When I approve the authorization the client "Claude" asks for
    Then the callback goes to the client's redirect URI "https://claude.ai/api/mcp/auth_callback"
    And the callback carries:
      | code  | (a code)          |
      | state | state-from-claude |
      | iss   | SITE              |
    And the code is stored hashed and tied to the client, the redirect URI, the challenge, the resource and "read suggest"

  Scenario Outline: Asking for <asked> grants <granted>
    Given I am signed in to the admin
    When I approve the authorization the client "Claude" asks for with:
      | scope | <asked> |
    Then the code grants "<granted>"

    Examples:
      | asked                                                         | granted                                                       |
      | (none)                                                        | read                                                          |
      | read suggest write publish delete health mail agents notes contacts | read suggest write publish delete health mail agents notes contacts |
      | read erase                                                    | read                                                          |
      |                                                               | read                                                          |
      | write write                                                   | write                                                         |
      | write read                                                    | read write                                                    |
      | suggest                                                       | suggest                                                       |

  Scenario: The page shows reading alone for no scope, every admin write for write, and nothing it would not grant
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | scope | (none) |
    Then the page says "Read everything the site keeps"
    When I open the authorization the client "Claude" asks for with:
      | scope | read write |
    Then the page says "Make any change the admin makes"
    When I open the authorization the client "Claude" asks for with:
      | scope | read erase |
    Then the page does not say "erase"

  Scenario: A request that names no resource sends me back and ties the code to this server anyway
    Given I am signed in to the admin
    When I approve the authorization the client "Claude" asks for with:
      | resource | (none) |
    Then the callback goes to the client's redirect URI "https://claude.ai/api/mcp/auth_callback"
    And the code is tied to the resource "SITE/mcp"

  Scenario: Cancelling sends me back saying no, with the state and the issuer, and issues no code
    Given I am signed in to the admin
    When I cancel the authorization the client "Claude" asks for
    Then the callback goes to the client's redirect URI "https://claude.ai/api/mcp/auth_callback"
    And the callback carries:
      | error | access_denied     |
      | state | state-from-claude |
      | iss   | SITE              |
      | code  | (none)            |
    And no code is issued

  Scenario Outline: An approval with <what> is refused as the form expired and issues no code
    Given I am signed in to the admin
    When I approve the authorization the client "Claude" asks for, swapping in:
      | _csrf_token | <token> |
    Then the answer is 403
    And the answer shows "Form expired"
    And no code is issued

    Examples:
      | what            | token  |
      | a forged token  | forged |
      | no token        | (none) |

  Scenario: An approval that swaps in a bad response_type answers with a page and issues no code
    Given I am signed in to the admin
    When I approve the authorization the client "Claude" asks for, swapping in:
      | response_type | token |
    Then the answer shows "Go back to claude.ai"
    And no code is issued

  Scenario Outline: When <what> and I am signed out, the request sends me to sign in and issues no code
    When the client "Claude" asks to be authorized with:
      | <field> | <value> |
    Then the answer sends me to "/admin/sign-in"
    And no code is issued

    Examples:
      | what                              | field                 | value                   |
      | response_type is not code         | response_type         | token                   |
      | the PKCE challenge is missing     | code_challenge        | (none)                  |
      | the PKCE challenge is too short   | code_challenge        | short                   |
      | the PKCE method is not S256       | code_challenge_method | plain                   |
      | the PKCE method is missing        | code_challenge_method | (none)                  |
      | the resource names another server | resource              | https://example.com/mcp |

  Scenario Outline: When <what> and I am signed in, the page refuses it, names the error and links back with the state
    Given I am signed in to the admin
    When the client "Claude" asks to be authorized with:
      | <field> | <value> |
    Then the answer is 400
    And the answer has no header "Location"
    And no code is issued
    When I open the authorization the client "Claude" asks for with:
      | <field> | <value> |
    Then the page names the error its link carries
    And the page says "The app at claude.ai sent a request"
    And the page links back to "https://claude.ai/api/mcp/auth_callback" carrying:
      | error | (words)           |
      | state | state-from-claude |
    And the page's content security policy holds directives starting:
      | frame-ancestors 'none' |

    Examples:
      | what                              | field                 | value                   |
      | response_type is not code         | response_type         | token                   |
      | the PKCE challenge is missing     | code_challenge        | (none)                  |
      | the PKCE challenge is too short   | code_challenge        | short                   |
      | the PKCE method is not S256       | code_challenge_method | plain                   |
      | the PKCE method is missing        | code_challenge_method | (none)                  |
      | the resource names another server | resource              | https://example.com/mcp |

  Scenario: An unknown client is refused as invalid_client, and a redirect URI it never registered as invalid_request
    Given I am signed in to the admin
    When the client "Claude" asks to be authorized with:
      | client_id | 11111111-0000-4000-8000-999999999999 |
    Then the answer is 400
    And the OAuth error is "invalid_client"
    When the client "Claude" asks to be authorized with:
      | redirect_uri | https://elsewhere.example/callback |
    Then the OAuth error is "invalid_request"
    And no code is issued

  Scenario: A client that sends no redirect URI gets its only one, but not when it registered two
    Given I am signed in to the admin
    And the MCP clients:
      | name | tokens | redirect                                                    |
      | Two  | none   | https://claude.ai/one                                       |
    And the database runs "UPDATE oauth_clients SET redirect_uris = '{https://claude.ai/one,https://claude.ai/two}' WHERE client_name = 'Two'"
    When I approve the authorization the client "Claude" asks for with:
      | redirect_uri | (none) |
    Then the callback goes to the client's redirect URI "https://claude.ai/api/mcp/auth_callback"
    When the client "Two" asks to be authorized with:
      | redirect_uri | (none) |
    Then the answer is 400

  Scenario Outline: A client_id <what> is refused as invalid_client signed out, signed in and swapped into an approval
    When the client "Claude" asks to be authorized with:
      | client_id | <id> |
    Then the answer is 400
    And the OAuth error is "invalid_client"
    Given I am signed in to the admin
    When the client "Claude" asks to be authorized with:
      | client_id | <id> |
    Then the answer is 400
    And the OAuth error is "invalid_client"
    When I approve the authorization the client "Claude" asks for, swapping in:
      | client_id | <id> |
    Then the answer is 400
    And the OAuth error is "invalid_client"
    And no code is issued

    Examples:
      | what                       | id                                     |
      | that is a NUL              | \0                                     |
      | that is not a UUID         | not-a-uuid                             |
      | with a line break after it | 3198302d-9a26-4284-8a65-69a01897c10e\n |

  Scenario Outline: A request carrying <what> is refused as <error>
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | <field> | <value> |
    Then the page's link back names the error "<error>"

    Examples:
      | what                                        | field                 | value                                        | error                     |
      | a scope with a double space                 | scope                 | read  suggest                                | invalid_scope             |
      | a scope that opens with a space             | scope                 | (space)read                            | invalid_scope             |
      | a scope holding a NUL                       | scope                 | read\0                                       | invalid_scope             |
      | a scope holding a quote                     | scope                 | read"suggest                                 | invalid_scope             |
      | a PKCE challenge one character too long     | code_challenge        | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | invalid_request |
      | a PKCE challenge holding a slash            | code_challenge        | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/  | invalid_request           |
      | an empty PKCE challenge                     | code_challenge        |                                              | invalid_request           |
      | an empty PKCE method                        | code_challenge_method |                                              | invalid_request           |
      | a missing PKCE method                       | code_challenge_method | (none)                                       | invalid_request           |
      | an empty response_type                      | response_type         |                                              | unsupported_response_type |
      | a resource on another path of this server   | resource              | SITE/admin                                   | invalid_target            |
      | a resource on a host that only starts the same | resource           | SITE.evil.example/mcp                        | invalid_target            |
      | an empty resource                           | resource              |                                              | invalid_target            |

  Scenario: A wrong response_type and no PKCE challenge is refused as unsupported_response_type
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | response_type  | token  |
      | code_challenge | (none) |
    Then the page's link back names the error "unsupported_response_type"

  Scenario Outline: A <field> sent as a list is refused as <error>
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | <field>   | (none)  |
      | <field>[] | one,two |
    Then the page's link back names the error "<error>"

    Examples:
      | field          | error           |
      | scope          | invalid_scope   |
      | state          | invalid_request |
      | code_challenge | invalid_request |

  Scenario Outline: A state of <what> is named as the problem and kept out of the link
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | state | <state> |
    Then the page's link back describes the error as "state must hold only printable ASCII characters"
    And the page links back to "https://claude.ai/api/mcp/auth_callback" carrying:
      | state | (none) |

    Examples:
      | what            | state        |
      | a NUL           | state\0      |
      | a line break    | state\n      |
      | a letter é      | staéte  |

  Scenario: A refusal of another field gives back the state, and the client is checked first
    Given I am signed in to the admin
    When I open the authorization the client "Claude" asks for with:
      | response_type | token |
    Then the page links back to "https://claude.ai/api/mcp/auth_callback" carrying:
      | state | state-from-claude |
    When the client "Claude" asks to be authorized with:
      | client_id     | (none) |
      | response_type | token  |
    Then the OAuth error is "invalid_client"

  Scenario Outline: A request with <what> is taken and issues a code
    Given I am signed in to the admin
    When I approve the authorization the client "Claude" asks for with:
      | <field> | <value> |
    Then the callback carries:
      | code | (a code) |

    Examples:
      | what                              | field    | value     |
      | a resource with a trailing slash  | resource | SITE/mcp/ |
      | the issuer itself as the resource | resource | SITE      |
      | an empty state                    | state    |           |

  Scenario: A request with no state, resource or scope is taken, and no state comes back
    Given I am signed in to the admin
    When I approve the authorization the client "Claude" asks for with:
      | state    | (none) |
      | resource | (none) |
      | scope    | (none) |
    Then the callback carries:
      | code  | (a code) |
      | state | (none)   |

  Scenario: A redirect URI that carries a query keeps it and sends back the request's state
    Given I am signed in to the admin
    And the MCP clients:
      | name  | tokens | redirect                                        |
      | Query | none   | https://claude.ai/callback?next=1&state=theirs  |
    When I approve the authorization the client "Query" asks for
    Then the callback goes to the client's redirect URI "https://claude.ai/callback"
    And the callback carries:
      | next  | 1                 |
      | state | state-from-claude |
