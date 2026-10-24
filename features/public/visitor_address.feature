Feature: Visitor address
  Analytics hash the address the site trusts. Outside production that is the connection's address. In
  production it is the address Cloudflare writes in CF-Connecting-IP, but only when the connection comes from a
  trusted proxy. Two beacons from one address and browser share one visitor hash.

  Background:
    Given my requests send the header "User-Agent" as "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36"

  @timeout:180_000
  Scenario: Outside production the site takes the connection's address and ignores one the client names
    Given the site runs in development
    When I send a beacon with the header "X-Forwarded-For" as "203.0.113.7":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    And I send a beacon with the header "X-Forwarded-For" as "203.0.113.8":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    And I send a beacon:
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    Then the database answers "1" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM analytics_events
      """

  @timeout:180_000
  Scenario: In production the site takes the address the proxy wrote, the nearest one in a list
    Given the site runs in production
    When I send a beacon with the header "CF-Connecting-IP" as "203.0.113.7":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    And I send a beacon with the header "CF-Connecting-IP" as "198.51.100.4, 203.0.113.7":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    And I send a beacon with the header "CF-Connecting-IP" as "203.0.113.8":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    Then the database answers "2" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM analytics_events
      """
    And the database answers "2" for:
      """
      SELECT count(*) FROM analytics_events GROUP BY visitor_hash ORDER BY count(*) DESC LIMIT 1
      """

  @timeout:180_000
  Scenario: In production the site ignores the other headers a client sets and falls back to the connection
    Given the site runs in production
    When I send a beacon:
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    And I send a beacon with the header "X-Forwarded-For" as "198.51.100.4":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    And I send a beacon with the header "X-Real-IP" as "198.51.100.5":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    And I send a beacon with the header "CF-Connecting-IP" as "  ":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    And I send a beacon with the header "CF-Connecting-IP" as "127.0.0.1":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    Then the database answers "1" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM analytics_events
      """

  @timeout:180_000
  Scenario Outline: In production with <trusted> trusted, the site ignores the header a sender forged
    Given the environment sets PROXY_TRUSTED_PROXIES to "<ranges>"
    And the site runs in production
    When I send a beacon with the header "CF-Connecting-IP" as "203.0.113.7":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    And I send a beacon with the header "CF-Connecting-IP" as "203.0.113.8":
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    Then the database answers "1" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM analytics_events
      """

    Examples:
      | trusted                         | ranges     |
      | only a range that misses it     | 10.0.0.0/8 |
      | no proxy                        |            |
