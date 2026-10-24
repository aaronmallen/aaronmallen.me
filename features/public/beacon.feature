Feature: Analytics beacon
  A public page's script sends a view when it loads, then a read with the time, the deepest scroll and the load
  timing when the reader leaves, and a click for each link to another site followed from a post. It sets no
  cookie, and sends nothing on the admin or while the owner is signed in.

  Scenario: A public page stores one view with its path and title when it loads, and sets no cookie
    When I visit "/writing"
    Then the database soon answers "/writing 0 Writing | Aaron Allen" for:
      """
      SELECT path, read_seconds, title FROM analytics_events
      """
    And the browser holds no cookie for the page

  Scenario: The ref of a tagged link is stored as the source, apart from the path, and a ref that is no plain token is not
    When I visit "/writing?ref=reddit"
    Then the database soon answers "/writing reddit" for:
      """
      SELECT path, source FROM analytics_events
      """
    When I visit "/about?ref=%20"
    Then the database soon answers "none" for:
      """
      SELECT coalesce(source, 'none') FROM analytics_events WHERE path = '/about'
      """

  Scenario Outline: A view reached from <referrer> stores <stored>
    When I visit "<path>" from the referrer "<referrer>"
    Then the database soon answers "<stored>" for:
      """
      SELECT coalesce(referrer_host, 'no host') || ' ' || coalesce(referrer_path, 'no path') FROM analytics_events
      """

    Examples:
      | referrer                         | path     | stored                |
      | https://news.example/item?id=1   | /about   | news.example no path  |
      | {site}/writing?ref=reddit        | /about   | no host /writing      |

  Scenario: A referrer too long to store is sent as its origin alone
    When I visit "/writing" from a referrer of 2100 characters on "news.example"
    Then the database soon answers "news.example" for:
      """
      SELECT referrer_host FROM analytics_events
      """

  Scenario: Leaving a page stores its read time, one event a page and no more
    When I visit "/writing"
    And the database soon answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """
    And I visit "/about"
    Then the database soon answers "/writing true, /about false" for:
      """
      SELECT string_agg(path || ' ' || (read_seconds >= 1)::text, ', ' ORDER BY id) FROM analytics_events
      """

  Scenario: A page restored from the cache sends a read again when left a second time
    When I visit "/writing"
    And the database soon answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """
    And I count the beacons the page sends
    And I leave the page
    And I come back to the page
    Then the page soon has sent 1 beacon
    When I leave the page
    Then the page soon has sent 2 beacons

  Scenario: A long page starts at no depth, and stores the deepest depth reached, sent once with the read
    Given a long post "Long" with the sections "One, Two, Three, Four, Five, Six, Seven, Eight"
    When I visit "/writing/long"
    Then the database soon answers "0" for:
      """
      SELECT scroll_depth FROM analytics_events
      """
    When I watch what the beacon sends
    And I scroll through "0.6, 1, 0, 0.6" of the page and leave it
    Then the beacons sent the kinds and depths "read 100"
    And the database soon answers "100" for:
      """
      SELECT scroll_depth FROM analytics_events
      """

  Scenario: A long page left unscrolled sends no depth with the read
    Given a long post "Long" with the sections "One, Two, Three, Four, Five, Six, Seven, Eight"
    When I visit "/writing/long"
    And the database soon answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """
    And I watch what the beacon sends
    And I scroll through "" of the page and leave it
    Then the beacons sent the kinds and depths "read"

  Scenario: A page that fits on screen starts at the full depth
    Given the posts:
      | title | body  |
      | Short | Short |
    And my window is 1280 by 1000
    When I visit "/writing/short"
    Then the database soon answers "100" for:
      """
      SELECT scroll_depth FROM analytics_events
      """

  Scenario: A link to another site sends its host and path and nothing more, stored against the view
    Given the posts:
      | title | body                                                                      |
      | Links | [the guide](https://docs.example/guide?token=secret#top) [about me](/about) |
    When I visit "/writing/links"
    And the database soon answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """
    And I watch what the beacon sends
    And I click the element "a:text-is('the guide')"
    Then the beacons sent the kinds and depths "click"
    And the database soon answers "docs.example /guide true" for:
      """
      SELECT link_host, link_path, event_id = (SELECT id FROM analytics_events) FROM analytics_clicks
      """

  Scenario: A link opened with the middle button sends a click
    Given the posts:
      | title | body                              |
      | Links | [the guide](https://docs.example) |
    When I visit "/writing/links"
    And the database soon answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """
    And I watch what the beacon sends
    And I click an injected link to another site with the middle button
    Then the beacons sent the kinds and depths "click"

  Scenario: A link within the site, or to another site from a page that is not a post, sends nothing
    Given the posts:
      | title | body                |
      | Links | [about me](/about)  |
    When I visit "/writing/links"
    And the database soon answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """
    And I watch what the beacon sends
    And I click the element "a:text-is('about me')"
    Then the beacon sent nothing
    When I visit "/about"
    And I watch what the beacon sends
    And I click an injected link to another site with the left button
    Then the beacon sent nothing

  Scenario: The read carries the load timing, stored once under the route even when the page is left twice
    When I visit "/writing"
    And the database soon answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """
    And I watch what the beacon sends
    And I count the beacons the page sends
    And I wait for the page loaded and painted, then leave it
    Then the beacon sent a read with the timing of the page
    And the database soon answers "/writing desktop" for:
      """
      SELECT route, device_class FROM performance_pages
      """
    When I come back to the page
    And I leave the page
    Then the page soon has sent 2 beacons
    And the database answers "1" for:
      """
      SELECT count(*) FROM performance_pages
      """

  Scenario: The beacon stays off the admin and records nothing while the owner is signed in
    Given I am signed in to the admin
    When I visit "/admin"
    Then the page has no "body[data-beacon]"
    When I count the beacons the page sends
    And I visit "/writing"
    Then the page soon has sent 1 beacon
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events
      """
