Feature: Robots
  robots.txt keeps every crawler off the private paths, allows the rest and names the sitemap.

  Scenario Outline: robots.txt answers as plain text to <accept>
    Given my requests send <accept>
    When I request "/robots.txt"
    Then the "Content-Type" header starts with "text/plain"

    Examples:
      | accept                         |
      | no "Accept" header             |
      | the header "Accept" as "*/*"   |

  Scenario: robots.txt keeps crawlers off the private paths and names the sitemap
    When I request "/robots.txt"
    Then the body starts with:
      """
      User-agent: *
      Disallow: /admin
      Disallow: /api
      Disallow: /mcp
      Disallow: /oauth
      Disallow: /pulse
      Disallow: /search
      Disallow: /webmention
      Allow: /
      """
    And the body includes "Sitemap: {site}/sitemap.xml"
