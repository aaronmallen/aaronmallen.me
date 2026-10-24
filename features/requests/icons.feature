Feature: Icons
  Every page links the SVG icon, the ICO fallback, the apple-touch-icon and the web manifest.

  Scenario Outline: A page in <place> links every icon and the manifest
    Given I am signed in to the admin
    When I visit "<path>"
    Then the page has "head link[rel='icon'][type='image/svg+xml'][href='{asset:favicon.svg}']"
    And the page has "head link[rel='icon'][href='{asset:favicon.ico}']"
    And the page has "head link[rel='apple-touch-icon'][href='{asset:apple-touch-icon.png}']"
    And the page has "head link[rel='manifest'][href='/site.webmanifest']"

    Examples:
      | place           | path                                   |
      | the public site | /                                      |
      | the admin       | /admin                                 |

  Scenario: The admin sign-in page links every icon and the manifest
    When I visit "/admin/sign-in"
    Then the page has "head link[rel='icon'][type='image/svg+xml'][href='{asset:favicon.svg}']"
    And the page has "head link[rel='icon'][href='{asset:favicon.ico}']"
    And the page has "head link[rel='apple-touch-icon'][href='{asset:apple-touch-icon.png}']"
    And the page has "head link[rel='manifest'][href='/site.webmanifest']"

  Scenario: The site serves the rendered ICO
    When I request "/favicon.ico"
    Then it answers 200
    And the body is the file "app/assets/images/favicon.ico"

  Scenario: The MCP approval page links every icon and the manifest
    Given I am signed in to the admin
    And an MCP client
    When I visit the MCP approval page
    Then the page has "head link[rel='icon'][type='image/svg+xml'][href='{asset:favicon.svg}']"
    And the page has "head link[rel='icon'][href='{asset:favicon.ico}']"
    And the page has "head link[rel='apple-touch-icon'][href='{asset:apple-touch-icon.png}']"
    And the page has "head link[rel='manifest'][href='/site.webmanifest']"
