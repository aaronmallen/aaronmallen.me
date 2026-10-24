Feature: Webmentions
  Another site tells the post it links to by posting a source and target to /webmention. The site accepts an
  eligible target with a 202, verifies the source in the background and stores a pending mention. It refuses a
  bad pair with a 400, a repeat or a flood with a 429, and answers with nothing to read.

  Background:
    Given the posts:
      | title | webmentions |
      | Hello | yes         |

  Scenario: An eligible target is accepted with nothing to read, and the mention is stored pending once verified
    When "http://203.0.113.5/notes/1" sends a webmention for "{site}/writing/hello"
    Then it answers 202
    And the body is:
      """
      """
    And there is no "Set-Cookie" header
    And the database soon answers "pending Ada reply" for:
      """
      SELECT status, author_name, type FROM webmentions
      """

  Scenario Outline: A sender asking for <accept> is accepted
    Given my requests send the header "Accept" as "<accept>"
    When "http://203.0.113.5/notes/1" sends a webmention for "{site}/writing/hello"
    Then it answers 202

    Examples:
      | accept           |
      | application/json |
      | text/plain       |
      | text/html        |
      | */*              |

  Scenario: Another site's page may send one, and the target is accepted however the request arrived
    Given my requests send the header "Sec-Fetch-Site" as "cross-site"
    And my requests send the header "Origin" as "http://203.0.113.5"
    And my requests send the header "Host" as "pi.local"
    When "http://203.0.113.5/notes/1" sends a webmention for "{site}/writing/hello"
    Then it answers 202

  Scenario: One mention is stored however the source page is spelled
    When I send a webmention to the post "Hello" from each of:
      | http://203.0.113.5/notes/1/         |
      | http://203.0.113.5/notes/1#comment  |
      | HTTP://203.0.113.5/notes/1          |
      | http://203.0.113.5/notes/1          |
    Then the database soon answers "1" for:
      """
      SELECT count(*) FROM webmentions
      """

  Scenario Outline: <what> is rejected with nothing queued
    Given the posts:
      | title | status    | published | webmentions | slug  |
      | Draft | draft     |           | yes         | draft |
      | Later | scheduled | in 1 day  | yes         | later |
      | Quiet |           |           |             | quiet |
    And my requests send the header "Accept" as "application/json"
    When I post "/webmention" with the "application/x-www-form-urlencoded" body "<body>"
    Then it answers 400
    And the database answers "0" for:
      """
      SELECT count(*) FROM webmention_receipts
      """

    Examples:
      | what                       | body                                                                 |
      | A missing source           | target=http%3A%2F%2F127.0.0.1%2Fwriting%2Fhello                      |
      | A missing target           | source=http%3A%2F%2F203.0.113.5%2Fnotes%2F1                          |
      | A source that isn't a URL  | source=nope&target=TARGET                                            |
      | A mailto source            | source=mailto%3Aada%40ada.example&target=TARGET                      |
      | A javascript source        | source=javascript%3Aalert(1)&target=TARGET                           |
      | A tel source               | source=tel%3A%2B15550100&target=TARGET                               |
      | A urn source               | source=urn%3Aisbn%3A1&target=TARGET                                  |
      | A relative source          | source=%2Fnotes%2F1&target=TARGET                                    |
      | A source that names no host | source=https%3A%2F%2F%40%2Fnotes%2F1&target=TARGET                  |
      | A target on another site   | source=http%3A%2F%2F203.0.113.5%2Fnotes%2F1&target=https%3A%2F%2Felsewhere.example%2Fwriting%2Fhello |
      | A target naming the host that asked | source=http%3A%2F%2F203.0.113.5%2Fnotes%2F1&target=http%3A%2F%2Fpi.local%2Fwriting%2Fhello |
      | A slug not in slug format  | source=http%3A%2F%2F203.0.113.5%2Fnotes%2F1&target=SITE%2Fwriting%2FHello |
      | A draft                    | source=http%3A%2F%2F203.0.113.5%2Fnotes%2F1&target=SITE%2Fwriting%2Fdraft |
      | A scheduled post           | source=http%3A%2F%2F203.0.113.5%2Fnotes%2F1&target=SITE%2Fwriting%2Flater |
      | A post with webmentions off | source=http%3A%2F%2F203.0.113.5%2Fnotes%2F1&target=SITE%2Fwriting%2Fquiet |
      | A source of 3,000 bytes    | source=LONG&target=TARGET                                            |

  Scenario: Everything is rejected while receiving is off
    Given the database runs:
      """
      INSERT INTO webmention_settings (id, receive) VALUES (1, false) ON CONFLICT (id) DO UPDATE SET receive = false
      """
    When I post the form "/webmention" with:
      | source | http://203.0.113.5/notes/1 |
      | target | {site}/writing/hello       |
    Then it answers 400

  Scenario: The same pair sent again inside the window is refused with nothing to read, and queued once
    When "http://203.0.113.5/notes/1" sends a webmention for "{site}/writing/hello"
    And "http://203.0.113.5/notes/1" sends a webmention for "{site}/writing/hello"
    And "http://203.0.113.5/notes/1" sends a webmention for "{site}/writing/hello"
    Then it answers 429
    And the body is:
      """
      """
    And the database answers "1" for:
      """
      SELECT count(*) FROM webmention_receipts
      """
    And the database soon answers "1" for:
      """
      SELECT count(*) FROM webmentions
      """

  Scenario: A run of receipts past the limit is refused, even with a new browser on each
    When I send 31 webmentions to the post "Hello", each from a new browser
    Then it answers 429
    And the body is:
      """
      """
    And the database answers "30" for:
      """
      SELECT count(*) FROM webmention_receipts
      """
    And the database soon answers "30" for:
      """
      SELECT count(*) FROM webmentions
      """

  @timeout:180_000
  Scenario: In production a sender forging X-Forwarded-For, which is not the proxy's header, is refused past the limit
    Given the environment sets WEBMENTIONS_THROTTLE_LIMIT to "5"
    And the site runs in production
    And my requests send the header "X-Forwarded-For" as "203.0.113.9"
    When I send 6 webmentions to the post "Hello", each from a new browser
    Then it answers 429
    And the database answers "5" for:
      """
      SELECT count(*) FROM webmention_receipts
      """

  @timeout:180_000
  Scenario: In production a run past the limit from one IPv6 /64 is refused, while a second /64 goes through
    Given the environment sets WEBMENTIONS_THROTTLE_LIMIT to "5"
    And the site runs in production
    When I send 6 webmentions to the post "Hello" from the addresses "2001:db8:1:2::N" in production
    Then it answers 429
    And the database answers "5" for:
      """
      SELECT count(*) FROM webmention_receipts
      """
    Given my requests send the header "CF-Connecting-IP" as "2001:db8:1:3::1"
    When "http://203.0.113.5/notes/other" sends a webmention for "https://aaronmallen.me/writing/hello"
    Then it answers 202

  @timeout:180_000
  Scenario: In production a run from many addresses past the total limit is refused
    Given the environment sets WEBMENTIONS_TOTAL_THROTTLE_LIMIT to "3"
    And the site runs in production
    When I send 4 webmentions to the post "Hello" from the addresses "203.0.113.N" in production
    Then it answers 429
    And the database answers "3" for:
      """
      SELECT count(*) FROM webmention_receipts
      """

  Scenario: The endpoint answers only to POST
    When I request "/webmention"
    Then it answers 405
