Feature: Admin API tokens
  The connected services tab mints, lists and revokes the tokens the JSON API takes.

  Background:
    Given I am signed in to the admin

  Scenario: Minting a token shows its value once and stores only its digest
    When I mint a token named "  Terminal  " in the admin
    Then I am on "/admin/settings/services#tokens"
    And the page toasts "Token minted"
    And the page says "Copy it now. The site can't show it again."
    And the page shows the new token
    And the database answers "Terminal, read" for:
      """
      SELECT name, array_to_string(scopes, ',') FROM api_tokens
      """
    And the stored token is the SHA-256 digest of the value shown and never the value
    And the API answers GET "/api/v1/token" with the token shown
    And the page has no axe breaches in light or dark
    When I visit "/admin/settings/services"
    Then the page hides the token shown

  Scenario: Minting twice gives two values
    When I mint a token named "Terminal" in the admin
    And I mint a token named "Terminal" in the admin
    Then the two tokens shown differ

  Scenario: A fresh form checks only read and shows no value
    Given an API token "Laptop"
    When I visit "/admin/settings/services"
    Then the checked boxes are "token[scopes][read]"
    And the page hides the token shown

  Scenario Outline: Minting stores the scopes I check
    When I post to "/admin/tokens" with:
      | token[name]           | Terminal |
      | token[scopes][read]   | 1        |
      | token[scopes][<also>] | 1        |
    Then the database answers "<stored>" for:
      """
      SELECT array_to_string(scopes, ',') FROM api_tokens
      """

    Examples:
      | also   | stored      |
      | write  | read,write  |
      | health | read,health |
      | mail   | read,mail   |

  Scenario Outline: Minting refuses <what> and says why
    Given an API token "Laptop"
    When I post to "/admin/tokens" with:
      | token[name]          | <name>    |
      | token[scopes][<scope>] | 1       |
      | token[expires_on]    | <expires> |
    Then the answer is 422
    And the answer shows "<error>"
    And the answer lists the live tokens "Laptop"
    And the table api_tokens holds 1 row

    Examples:
      | what                       | name           | scope   | expires | error                                     |
      | a blank name               |                | read    |         | Give the token a name first.              |
      | a name of Unicode spaces   |  　   | read    |         | Give the token a name first.              |
      | a name with a control char | Term\u0007inal | read    |         | A name can&#39;t hold control characters. |
      | an expiry of today         | Terminal       | read    | today   | Pick a day after today.                   |
      | an expiry that is no day   | Terminal       | read    | soon    | Pick a day for the token to expire.       |

  Scenario: Minting refuses a name over 100 characters and keeps what I typed
    When I post to "/admin/tokens" with a name of 101 "a"s
    Then the answer is 422
    And the answer shows "Keep the name to 100 characters."
    And the answer shows "value=\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""

  Scenario: Minting refuses a token with no scope and keeps the boxes I checked when it refuses
    When I post to "/admin/tokens" with:
      | token[name]             | Terminal |
      | token[scopes][read]     | 0        |
      | token[scopes][suggest]  | 0        |
      | token[scopes][write]    | 0        |
      | token[scopes][publish]  | 0        |
      | token[scopes][delete]   | 0        |
      | token[scopes][health]   | 0        |
      | token[scopes][mail]     | 0        |
      | token[scopes][agents]   | 0        |
      | token[scopes][notes]    | 0        |
      | token[scopes][contacts] | 0        |
    Then the answer is 422
    And the answer shows "Pick at least one permission."
    When I post to "/admin/tokens" with:
      | token[name]            |   |
      | token[scopes][publish] | 1 |
    Then the answer checks only "token[scopes][publish]"

  Scenario: A token with no expiry never expires and says so
    When I post to "/admin/tokens" with:
      | token[name]         | Terminal |
      | token[scopes][read] | 1        |
      | token[expires_on]   |          |
    Then the database answers "true" for:
      """
      SELECT expires_at IS NULL FROM api_tokens
      """
    When I visit "/admin/settings/services"
    Then the "Terminal" row in "Live tokens" says "never expires"
    And the page says "The token stops working when that day starts. Leave it blank and it never expires."

  Scenario: A token expires when the day I pick starts
    When I post to "/admin/tokens" with:
      | token[name]         | Terminal       |
      | token[scopes][read] | 1              |
      | token[expires_on]   | in 7 days      |
    Then the database answers "true" for:
      """
      SELECT expires_at = ((now() AT TIME ZONE 'America/Chicago')::date + 7)::timestamp AT TIME ZONE 'America/Chicago'
      FROM api_tokens
      """
    When I visit "/admin/settings/services"
    Then the "Terminal" row in "Live tokens" says "expires"

  Scenario: The list says so when no token is live
    When I visit "/admin/settings/services"
    Then the page says "No live tokens. Mint one for a client that needs the API."

  Scenario: The list shows each live token newest first with its scopes, times and count
    Given the table api_tokens holds:
      | name   | token_digest | scopes         | created_at     | last_used_at | expires_at     |
      | Older  | sha256 of a  | {read}         | 10 minutes ago | 1 hour ago   |                |
      | Newer  | sha256 of b  | {read,publish} | now            |              |                |
      | Gone   | sha256 of c  | {read}         | now            |              | 1 second ago   |
    And the table api_tokens holds:
      | name    | token_digest | revoked_at |
      | Revoked | sha256 of d  | now        |
    And an API token "Hidden" with the value "hidden-value"
    When I visit "/admin/settings/services"
    Then the "Live tokens" card lists:
      | Hidden |
      | Newer  |
      | Older  |
    And the "Live tokens" card says "3 live tokens"
    And the "Newer" row in "Live tokens" says "read, publish"
    And the "Newer" row in "Live tokens" says "never used"
    And the "Newer" row in "Live tokens" says "minted"
    And the "Older" row in "Live tokens" says "last used"
    And the times in the "Newer" row of "Live tokens" begin with, in Chicago:
      """
      SELECT created_at FROM api_tokens WHERE name = 'Newer'
      """
    And the page never shows "hidden-value"

  Scenario: Revoking asks first and keeps the token when I decline
    Given an API token "Laptop"
    When I visit "/admin/settings/services"
    And I press "Revoke" in the "Laptop" row of "Live tokens"
    Then I am asked "Revoke Laptop? Any client using it loses the API at once."
    When I decline
    Then the "Live tokens" card lists:
      | Laptop |

  Scenario: Revoking cuts the token off, stamps it and says so
    Given an API token "Laptop" with the value "laptop-value"
    And an API token "Desktop"
    When I visit "/admin/settings/services"
    And I press "Revoke" in the "Laptop" row of "Live tokens"
    And I confirm
    Then the page toasts "Token revoked"
    And the "Live tokens" card lists:
      | Desktop |
    And the database answers "Desktop false, Laptop true" for:
      """
      SELECT string_agg(name || ' ' || (revoked_at IS NOT NULL), ', ' ORDER BY name) FROM api_tokens
      """
    And the API refuses GET "/api/v1/token" with "laptop-value"

  Scenario: Revoking comes back to the tokens section and refuses a token gone or unknown
    Given an API token "Laptop"
    When I post to "/admin/tokens/1/revoke"
    Then the answer sends me to "/admin/settings/services#tokens"
    When I post to "/admin/tokens/1/revoke"
    Then the answer is 404
    When I post to "/admin/tokens/0/revoke"
    Then the answer is 404

  Scenario: The old tokens address sends me to the connected services tab
    When I send GET "/admin/tokens"
    Then the answer is 302
    And the answer sends me to "/admin/settings/services#tokens"

  Scenario: The palette opens the tab that holds the tokens
    When I visit the admin
    Then the palette offers "/admin/settings/services"
