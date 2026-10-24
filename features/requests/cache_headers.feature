Feature: Cache headers
  Cloudflare may keep a public page a visitor asked for for five minutes. Anything the owner asks for, the
  contact page, the admin and the MCP screens stay out of every cache, and a miss or a redirect stays out of a
  shared cache.

  Scenario: A public page the owner asked for carries the admin token and stays out of every cache
    Given I am signed in to the admin
    When I request "/"
    Then the body carries my admin token
    And the "Cache-Control" header is "private, no-store"
    And the "Vary" header is "Cookie"

  Scenario: A feed the owner asked for stays out of every cache, 304 too
    Given the posts:
      | title |
      | Hello |
    And I am signed in to the admin
    When I request "/writing.atom"
    Then the "Cache-Control" header is "private, no-store"
    When I request "/writing.atom" again with the ETag it gave
    Then it answers 304
    And the "Cache-Control" header is "private, no-store"

  Scenario: A feed a visitor asked for stays out of a shared cache, 304 and tag feeds too
    Given the posts:
      | title | tags |
      | Hello | ruby |
    When I request "/writing.atom"
    Then the "Cache-Control" header is "private, no-cache"
    When I request "/writing.atom" again with the ETag it gave
    Then it answers 304
    And the "Cache-Control" header is "private, no-cache"
    When I request "/writing/tags/ruby.atom"
    Then the "Cache-Control" header is "private, no-cache"

  Scenario: A public page a visitor asked for carries no admin token and caches for five minutes
    When I request "/"
    Then the body does not include "action=\"/admin/sign-out\""
    And the "Cache-Control" header is "public, max-age=0, s-maxage=300"
    And the "Vary" header is "Cookie"

  Scenario: A public page a forged session cookie asked for carries no admin token and stays out of a shared cache
    Given my requests send the cookie "admin.session=forged"
    When I request "/"
    Then the body does not include "action=\"/admin/sign-out\""
    And there is no "Cache-Control" header

  Scenario: A public page the owner signed out of may sit in a shared cache
    Given I am signed in to the admin
    When I post the form "/admin/sign-out" with my token
    And I request "/"
    Then the "Cache-Control" header is "public, max-age=0, s-maxage=300"

  Scenario: A public page a visitor with a saved theme asked for matches the page with no cookie
    When I request "/"
    And I keep the body
    And my requests send the cookie "site_theme=dark"
    And I request "/"
    Then the "Cache-Control" header is "public, max-age=0, s-maxage=300"
    And the body matches the one I kept

  Scenario: Each public page a visitor asked for may sit in a shared cache
    Given the posts:
      | title | tags |
      | Hello | ruby |
    Then each of these paths answers 200 with the "Cache-Control" header "public, max-age=0, s-maxage=300":
      | /                    |
      | /about               |
      | /privacy             |
      | /projects            |
      | /writing             |
      | /writing/hello       |
      | /writing/tags/ruby   |

  Scenario: An edit to a post shows on the next request
    Given the posts:
      | title |
      | Hello |
    When I request "/writing/hello"
    And the database runs "UPDATE posts SET title = 'Edited'"
    And I visit "/writing/hello"
    Then "h1" reads "Edited"
    When I request "/writing/hello"
    Then the "Cache-Control" header is "public, max-age=0, s-maxage=300"

  Scenario: Every public page the owner asked for stays out of every cache
    Given the posts:
      | title | tags |
      | Hello | ruby |
    And I am signed in to the admin
    Then each of these paths answers 200 with the "Cache-Control" header "private, no-store":
      | /                    |
      | /about               |
      | /privacy             |
      | /projects            |
      | /writing             |
      | /writing/hello       |
      | /writing/tags/ruby   |
      | /contact             |

  Scenario: The contact page a visitor asked for stays out of every cache
    When I request "/contact"
    Then the "Cache-Control" header is "private, no-store"

  Scenario Outline: A missing <what> stays out of a shared cache
    When I request "<path>"
    Then it answers 404
    And there is no "Cache-Control" header

    Examples:
      | what | path                   |
      | post | /writing/no-such-post  |
      | tag  | /writing/tags/nothing  |

  Scenario: A tag page at another spelling redirects, out of a shared cache
    Given the posts:
      | title | tags |
      | Hello | ruby |
    When I request "/writing/tags/Ruby"
    Then it answers 301
    And there is no "Cache-Control" header

  Scenario: An admin page stays out of every cache
    Given I am signed in to the admin
    When I request "/admin"
    Then the "Cache-Control" header is "private, no-store"

  Scenario: The admin sign-in page stays out of every cache
    When I request "/admin/sign-in"
    Then the "Cache-Control" header is "private, no-store"

  Scenario: The refusal of an admin form sent without a token stays out of every cache
    Given I am signed in to the admin
    When I post the form "/admin/projects" with:
      | project[name] | sneaky |
    Then it answers 403
    And the "Cache-Control" header is "private, no-store"

  Scenario: The MCP approval page carries the approval token and stays out of every cache
    Given I am signed in to the admin
    And an MCP client
    When I request the MCP approval page
    Then the body matches "<form[^>]*action=\"/oauth/authorize\"[\s\S]*name=\"_csrf_token\""
    And the "Cache-Control" header is "private, no-store"
