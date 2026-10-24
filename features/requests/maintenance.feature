Feature: Maintenance mode
  While the maintenance flag file exists, every request gets a 503 that no cache keeps: a page for a browser,
  JSON for the API and MCP. The owner's cookie adds a button that takes the flag down.

  Scenario Outline: <what> gets the maintenance page while the flag is up
    Given the maintenance flag is up
    And my requests send the header "Host" as "<host>"
    When I request "<path>"
    Then it answers 503
    And the "Cache-Control" header is "no-store"
    And the "Retry-After" header is "300"
    And the "Content-Type" header starts with "text/html"
    And the body matches "<h1>Down for maintenance</h1>"
    And the body does not include "<a "
    And the request leaves no timing row

    Examples:
      | what                | host             | path             |
      | A public page       | 127.0.0.1        | /                |
      | An admin page       | 127.0.0.1        | /admin           |
      | The share host      | shares.localhost | /abc             |
      | The MCP sign-in page | 127.0.0.1       | /oauth/authorize |

  Scenario Outline: <what> gets the maintenance JSON while the flag is up
    Given the maintenance flag is up
    When I <verb> "<path>" with the "application/json" body "{}"
    Then it answers 503
    And the "Cache-Control" header is "no-store"
    And the "Retry-After" header is "300"
    And the JSON answer holds "error" as "temporarily_unavailable"
    And the request leaves no timing row

    Examples:
      | what                  | verb | path                                    |
      | An API request        | get  | /api/v1/posts                           |
      | An MCP request        | post | /mcp                                    |
      | The MCP token endpoint | post | /oauth/token                           |
      | The MCP metadata      | get  | /.well-known/oauth-authorization-server |

  Scenario: The owner's cookie gets the maintenance page with the Deactivate button
    Given the maintenance flag is up
    And my requests carry the owner's maintenance cookie
    When I request "/"
    Then it answers 503
    And the "Cache-Control" header is "no-store"
    And the "Retry-After" header is "300"
    And the body matches "<h1>Down for maintenance</h1>"
    And the body does not include "<a "
    And the body matches "<form method=\"post\" action=\"/maintenance/deactivate\">\s*<button type=\"submit\">Deactivate maintenance mode</button>"
    And the request leaves no timing row

  Scenario: The owner's cookie keeps the JSON reply for an API request
    Given the maintenance flag is up
    And my requests carry the owner's maintenance cookie
    When I request "/api/v1/posts"
    Then the body is:
      """
      {"error":"temporarily_unavailable","message":"the site is down for maintenance"}
      """

  Scenario Outline: A visitor whose cookie is <cookie> gets today's page
    Given the maintenance flag is up
    And my requests carry <cookie>
    When I request "/"
    Then the body is the file "public/503.html"

    Examples:
      | cookie                                                       |
      | no maintenance cookie                                        |
      | a forged maintenance cookie                                  |
      | the cookie "maintenance.owner=nonsense"                      |
      | an owner's maintenance cookie from before the flag went up   |

  Scenario: The owner deactivating takes the flag down, clears the cookie and lands on Settings
    Given the maintenance flag is up
    And my requests carry the owner's maintenance cookie
    When I post the form "/maintenance/deactivate"
    Then it answers 303
    And the "Location" header is "/admin/settings/security"
    And the "Set-Cookie" header starts with "maintenance.owner=; path=/; max-age=0"
    And the maintenance flag file is gone
    And the request leaves no timing row

  Scenario Outline: Deactivating with <cookie> gets the maintenance page and leaves the flag up
    Given the maintenance flag is up
    And my requests carry <cookie>
    When I post the form "/maintenance/deactivate"
    Then it answers 503
    And the body matches "<h1>Down for maintenance</h1>"
    And the maintenance flag file is there
    And the request leaves no timing row

    Examples:
      | cookie                                                     |
      | no maintenance cookie                                      |
      | an owner's maintenance cookie from before the flag went up |

  Scenario: Maintenance ends once the flag file is gone
    Given the maintenance flag is up
    When I request "/"
    Then it answers 503
    When the maintenance flag comes down
    And I request "/"
    Then it answers 200

  Scenario: With no flag file the page is served, read from the database, and timed
    Given the posts:
      | title |
      | Hello |
    When I request "/"
    Then it answers 200
    And the body includes "Hello"
    And the database soon answers "/" for:
      """
      SELECT DISTINCT route FROM performance_requests
      """
