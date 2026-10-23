Feature: Counting a post's readers
  A view of a post in its first 12 months stores a hash of the reader for that
  post, so the site can count unique readers without keeping who they are.

  Background:
    Given these analytics posts:
      | slug   | published |
      | hello  | today-30  |
      | other  | today-30  |
      | near   | today-360 |
      | old    | today-370 |

  Scenario: A view of a post stores the path and a hash of the reader
    When "Chrome" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the server answered 202
    And the post_reader_hashes table holds 1 rows where "path = '/writing/hello' AND reader_hash ~ '^[0-9a-f]{64}$'"
    And the post_reader_hashes table has the columns "path, reader_hash"

  Scenario: A reader on another browser stores another row
    When "Chrome" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And "Firefox" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the post_reader_hashes table holds 2 rows

  Scenario: One reader gets a different hash on each post
    When "Chrome" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And "Chrome" sends the beacon:
      """
      {"kind": "view", "path": "/writing/other"}
      """
    Then the post_reader_hashes table holds 2 rows
    And the post_reader_hashes table holds 0 rows where "reader_hash IN (SELECT reader_hash FROM post_reader_hashes GROUP BY reader_hash HAVING count(*) > 1)"

  Scenario: A view near the end of a post's first 12 months stores the reader
    When "Chrome" sends the beacon:
      """
      {"kind": "view", "path": "/writing/near"}
      """
    Then the post_reader_hashes table holds 1 rows

  Scenario: A view more than 12 months after a post went up counts the view and stores no reader
    When "Chrome" sends the beacon:
      """
      {"kind": "view", "path": "/writing/old"}
      """
    Then the analytics_events table holds 1 rows
    And the post_reader_hashes table holds 0 rows

  Scenario: A view of a page that is not a post stores no reader and no country from a private address
    When "Chrome" sends the beacon:
      """
      {"kind": "view", "path": "/about", "title": "About"}
      """
    Then the post_reader_hashes table holds 0 rows
    And the analytics_events rows are:
      | path   | country_code | country_name |
      | /about | none         | none         |

  Scenario: A known bot stores no reader
    When "Googlebot" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the post_reader_hashes table holds 0 rows

  Scenario: A view stores no reader while the owner is signed in
    Given I am signed in to the admin
    When "Chrome" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the post_reader_hashes table holds 0 rows

  Scenario: A view past the throttle stores no reader
    When "Chrome" sends 120 view beacons for "/about"
    And "Chrome" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the post_reader_hashes table holds 0 rows

  Scenario: A reader on another address stores another row
    When "Chrome" from "203.0.113.7" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And "Chrome" from "198.51.100.4" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the post_reader_hashes table holds 2 rows
