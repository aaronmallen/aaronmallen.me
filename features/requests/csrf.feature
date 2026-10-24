Feature: CSRF protection
  Every admin and MCP form must carry the session's token. A form without one, or with one that is not a
  string, is refused with the "Form expired" page and changes nothing.

  Scenario: A signed-out admin form without a token is refused before it is sent to sign in, and saves nothing
    When I post the form "/admin/projects" with:
      | project[name] | sneaky |
    Then it answers 403
    And the database answers "0" for:
      """
      SELECT count(*) FROM projects
      """

  Scenario: A signed-out admin form with the session's token is sent to sign in
    When I post the form "/admin/projects" with the token from "/admin/sign-in" and:
      | project[name] | sneaky  |
      | _csrf_token   | {token} |
    Then it redirects to a path ending in "/admin/sign-in"

  Scenario Outline: Every POST form on <path> carries the session's token once
    Given I am signed in to the admin
    When I visit "<path>"
    Then every POST form on the page carries my admin token once

    Examples:
      | path                    |
      | /admin                  |
      | /admin/journal          |
      | /admin/notes            |
      | /admin/contacts/new     |
      | /admin/posts/new        |
      | /admin/projects/new     |
      | /admin/settings/tagging |
      | /admin/tasks            |

  Scenario: The owner signs out through the form the avatar menu draws
    Given I am signed in to the admin
    When I visit "/admin"
    And I submit the form "#avatar-menu form[action='/admin/sign-out']"
    Then I am on "/"

  Scenario: An admin form without a token is refused, out of every cache and index, and saves nothing
    Given I am signed in to the admin
    When I post the form "/admin/projects" with:
      | project[name] | sneaky |
    Then it answers 403
    And the "Cache-Control" header is "private, no-store"
    And the "X-Robots-Tag" header is "noindex, nofollow"
    And the database answers "0" for:
      """
      SELECT count(*) FROM projects
      """

  Scenario: An admin form with a token that is not a string gets the page a missing token gets, and saves nothing
    Given I am signed in to the admin
    When I post the form "/admin/projects" with the token from "/admin" and:
      | project[name]  | sneaky  |
      | _csrf_token[]  | {token} |
    Then it answers 403
    And the body matches "<h1[^>]*>Form expired</h1>"
    And the database answers "0" for:
      """
      SELECT count(*) FROM projects
      """

  Scenario: An MCP approval without a token is refused and issues no code
    Given I am signed in to the admin
    And an MCP client
    When I post the form "/oauth/authorize" with:
      | client_id     | 11111111-0000-4000-8000-000000000001   |
      | decision      | approve                                |
      | redirect_uri  | https://claude.ai/api/mcp/auth_callback |
      | response_type | code                                   |
    Then it answers 403
    And the database answers "0" for:
      """
      SELECT count(*) FROM oauth_codes
      """

  Scenario: An MCP approval with a token that is not a string gets the page a missing token gets, and issues no code
    Given I am signed in to the admin
    And an MCP client
    When I post the form "/oauth/authorize" with the token from "/admin" and:
      | _csrf_token[] | {token}                                |
      | client_id     | 11111111-0000-4000-8000-000000000001   |
      | decision      | approve                                |
      | redirect_uri  | https://claude.ai/api/mcp/auth_callback |
      | response_type | code                                   |
    Then it answers 403
    And the body matches "<h1[^>]*>Form expired</h1>"
    And the database answers "0" for:
      """
      SELECT count(*) FROM oauth_codes
      """
