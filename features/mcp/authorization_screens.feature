Feature: MCP authorization screens
  The consent, refused and form expired screens work by mouse and keyboard and pass axe on a desk and a phone.

  Background:
    Given I am signed in to the admin
    And the MCP clients:
      | name   | tokens | redirect       |
      | Claude | none   | SITE/callback  |

  Scenario: Approving lands on the redirect URI with a code
    When I open the authorization the client "Claude" asks for
    And I press "Approve" on the authorization page
    Then the browser lands on the redirect URI with "code="

  Scenario Outline: <button> by keyboard alone, behind a focus ring, lands on the redirect URI with <param>
    When I open the authorization the client "Claude" asks for
    And I Tab to "<button>" on the authorization page and press Enter
    Then the browser lands on the redirect URI with "<param>"

    Examples:
      | button  | param               |
      | Approve | code=               |
      | Cancel  | error=access_denied |

  Scenario Outline: The <screen> screen passes axe, takes Tab in order behind a ring, and reads on a desk and a phone
    When I open the authorization the client "Claude" asks for with:
      | scope         | read write    |
      | response_type | <type>        |
    And <then>
    Then the page has no axe breaches in light or dark
    And the Tab key reaches every control on the page in order, each behind a ring
    And the page reads well on the window, with 44px tap targets
    When I use a phone
    Then the page reads well on the window, with 44px tap targets

    Examples:
      | screen       | type  | then                                                     |
      | consent      | code  | nothing more                                             |
      | refused      | token | nothing more                                             |
      | form expired | code  | I submit the authorization page with a forged CSRF token |
