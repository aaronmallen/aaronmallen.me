Feature: Settings menu
  A visitor gets a theme toggle. The signed-in owner gets a gear that opens a menu with the theme options, a link
  to the admin and a sign-out button that returns to the page, or home when the page is not safe to return to.

  Scenario Outline: A signed-out visitor sees no link into the admin on <path>
    When I visit "<path>"
    Then the page has no "a[href^='/admin'], form[action^='/admin']"

    Examples:
      | path      |
      | /         |
      | /about    |
      | /contact  |
      | /projects |
      | /writing  |

  Scenario: A signed-out visitor gets a theme toggle that knows its cookie, not the menu
    When I visit "/"
    Then the page has "button[aria-label='Toggle dark mode']"
    And the page has no "#settings-menu"
    And the page has "html[data-theme-cookie='site_theme']"

  Scenario: A forged session cookie gets the theme toggle
    Given my requests send the cookie "admin.session=forged"
    When I request "/"
    Then it answers 200
    And the body does not include "id=\"settings-menu\""

  Scenario: The signed-in owner gets a gear that opens the menu with Admin and Sign out below the theme options
    Given I am signed in to the admin
    When I visit "/about"
    Then the page has "button.settings-menu-toggle[popovertarget='settings-menu'] + #settings-menu[popover]"
    And the page has "#settings-menu [role='group'] + hr.settings-menu-separator + a.settings-menu-option[href='/admin'] + form[action='/admin/sign-out'][method='post'] button.settings-menu-option[type='submit']"
    And "#settings-menu a[href='/admin']" reads "Admin"
    And "#settings-menu form[action='/admin/sign-out'] button" reads "Sign out"

  Scenario: A public page sets no cookie for the signed-in owner
    Given I am signed in to the admin
    When I request "/about"
    Then there is no "Set-Cookie" header

  Scenario: Signing out from the menu returns to the page I was on
    Given I am signed in to the admin
    When I sign out from the menu on "/about?ref=menu"
    Then it redirects to "/about?ref=menu"

  Scenario: Signing out from the menu ends the session
    Given I am signed in to the admin
    When I sign out from the menu on "/about"
    And I request "/about"
    Then the body does not include "id=\"settings-menu\""
    When I request "/admin"
    Then it redirects to a path ending in "/admin/sign-in"

  Scenario Outline: Signing out from the menu sends me home instead of to <return to>
    Given I am signed in to the admin
    When I sign out from the menu on "/about" returning to "<return to>"
    Then it redirects to "/"

    Examples:
      | return to                                  |
      | /admin                                     |
      | //evil.example                             |
      | /\\evil.example                            |
      | https://evil.example/about                 |
      | about                                      |
      | /about\r\nLocation: https://evil.example   |
      | /admin/posts                               |
