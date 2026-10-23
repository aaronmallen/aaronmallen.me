Feature: A post's analytics
  Each post has a screen of its readers over 7, 14 or 30 days, with where they came from and its first 30 days.

  Background:
    Given I am signed in to the admin
    And I wrote a published post "Hello"

  Scenario: The screen sums up the post over the last 7 days
    Given the post analytics rolled up "1 day ago" for "/writing/hello":
      | views | visitors | bounces | read_throughs |
      | 8     | 5        | 2       | 3             |
    And the post analytics rolled up "8 days ago" for "/writing/hello":
      | views | visitors | bounces | read_throughs |
      | 100   | 40       | 10      | 20            |
    And the post analytics rolled up "1 day ago" for "/writing/other":
      | views | visitors | bounces |
      | 50    | 30       | 0       |
    And the post "Hello" has rolled up breakdowns from 1 day ago
    And the post "Hello" had outbound clicks 1 and 8 days ago
    When I open the analytics for "Hello" over 7 days
    Then the post admin page is titled "Hello"
    And the editor sub-line reads "0 readers and 3 read-throughs in the last 7 days. It lives at /writing/hello."
    And the post analytics range is "7"
    And the stat "Page views" reads "8"
    And the stat "Visitors" reads "5"
    And the stat "Visitors" notes "40% bounce rate"
    And the stat "Read-throughs" reads "3"
    And the card "Scroll depth" lists "25%, 50%, 75%, 100%"
    And the card "Scroll depth" counts "80%, 60%, 40%, 30%"
    And the card "Scroll depth" fills its meters to "80%, 60%, 40%, 30%"
    And the card "Referrers" lists "direct, news.example"
    And the card "Referrers" counts "3, 2"
    And the card "Geography" lists "United States, unknown, JP"
    And the card "Geography" counts "4, 1, 1"
    And the card "Devices" lists "mobile, desktop"
    And the card "Sources" lists "mastodon"
    And the card "Outbound clicks" lists "code.example/guide, docs.example/guide"
    And the card "Outbound clicks" counts "5, 2"
    And the post editor offers "Edit"
    And the page has no axe breaches in light or dark

  Scenario: A longer range counts the days it covers
    Given the post analytics rolled up "1 day ago" for "/writing/hello":
      | views | visitors | bounces | read_throughs |
      | 8     | 5        | 2       | 3             |
    And the post analytics rolled up "8 days ago" for "/writing/hello":
      | views | visitors | bounces | read_throughs |
      | 100   | 40       | 10      | 20            |
    And the post "Hello" had outbound clicks 1 and 8 days ago
    When I open the analytics for "Hello"
    And I pick the 14 day range
    Then I am on "/admin/posts/1/analytics?range=14"
    And the post analytics range is "14"
    And the post analytics ranges read "7d, 14d, 30d"
    And the stat "Page views" reads "108"
    And the stat "Read-throughs" reads "23"
    And the card "Outbound clicks" counts "10, 4"

  Scenario: Today's views count before they are rolled up
    Given the post analytics table analytics_events holds:
      | path           | visitor_hash | address_hash | month_visitor_hash | scroll_depth | read_seconds |
      | /writing/hello | one          | one          | month-one          | 75           | 30           |
      | /writing/hello | one          | one          | month-one          | 75           | 30           |
      | /writing/hello | two          | two          | month-two          | 75           | 30           |
      | /writing/other | three        | three        | month-three        | 0            | 0            |
    And the post analytics table analytics_clicks holds:
      | event_id | link_host    | link_path |
      | 3        | docs.example | /guide    |
    When I open the analytics for "Hello" over 7 days
    Then the stat "Page views" reads "3"
    And the card "Outbound clicks" lists "docs.example/guide"
    And the stat "Readers" reads "2"
    And the stat "Readers" notes "counted once a month"
    And the stat "Read-throughs" reads "2"

  Scenario: Only a read of 75% for 30 seconds counts as a read-through
    Given the post analytics table analytics_events holds:
      | path           | visitor_hash | address_hash | scroll_depth | read_seconds |
      | /writing/hello | full         | full         | 75           | 30           |
      | /writing/hello | short        | short        | 75           | 29           |
      | /writing/hello | shallow      | shallow      | 50           | 30           |
    When I open the analytics for "Hello" over 7 days
    Then the stat "Read-throughs" reads "1"
    And the stat "Read-throughs" notes "read 75% for 30 seconds or more"

  Scenario: A reader from before the range is left out
    Given the post analytics table analytics_events holds:
      | path           | visitor_hash | address_hash | month_visitor_hash | occurred_at |
      | /writing/hello | early        | early        | early              | 10 days ago |
    When I open the analytics for "Hello" over 7 days
    Then the stat "Readers" reads "0"

  Scenario: A post with no data shows zeroes and empty cards
    When I open the analytics for "Hello"
    Then the stats read "0, 0, 0, 0, 0"
    And the stat "Visitors" notes "0% bounce rate"
    And the card "Scroll depth" says "No scroll depth yet."
    And the card "Devices" says "No devices yet."
    And the card "Sources" says "No sources yet."
    And the card "Referrers" says "No referrers yet."
    And the card "Geography" says "No countries yet."
    And the card "Outbound clicks" says "No outbound clicks yet."

  Scenario: Unique readers count in the first 12 months, then as a final count or none
    Given I wrote a published post "Old" with:
      | published_at | 400 days ago |
    And I wrote a published post "Older" with:
      | published_at | 401 days ago |
    And the post analytics table post_reader_hashes holds:
      | path           | reader_hash |
      | /writing/hello | ada         |
      | /writing/hello | bob         |
    And the post analytics table post_reader_counts holds:
      | path         | readers |
      | /writing/old | 1234    |
    When I open the analytics for "Hello" over 7 days
    Then the stat "Unique readers" reads "2"
    And the stat "Unique readers" notes "in its first 12 months"
    When I open the analytics for "Old"
    Then the stat "Unique readers" reads "1,234"
    And the stat "Unique readers" notes "final count"
    When I open the analytics for "Older"
    Then the stat "Unique readers" reads "None"
    And the stat "Unique readers" notes "no count kept"

  Scenario: The first 30 days draw each day a young post has had, with zero for a day nobody read
    Given I wrote a published post "Young" with:
      | published_at | 2 days ago |
    And the post analytics rolled up "2 days ago" for "/writing/young":
      | views | visitors | bounces |
      | 7     | 7        | 0       |
    When I open the analytics for "Young"
    Then the first 30 days read:
      | 1 | 7 |
      | 2 | 0 |
      | 3 | 0 |
    And the first 30 days draw 3 points for the post

  Scenario: The first 30 days draw the median post as far as the oldest one
    Given the post "Hello" is a draft again
    And I wrote a published post "Old" with:
      | published_at | 3 days ago |
    And I wrote a published post "Young" with:
      | published_at | 1 day ago |
    And the post analytics rolled up "3 days ago" for "/writing/old":
      | views | visitors | bounces |
      | 4     | 4        | 0       |
    And the post analytics rolled up "1 day ago" for "/writing/young":
      | views | visitors | bounces |
      | 8     | 8        | 0       |
    When I open the analytics for "Old"
    Then the post admin shows "Median post"
    And the median of the first 30 days reads "6, 0, 0, 0"
    And the first 30 days draw 4 points for the median

  Scenario: The first 30 days read today's readers live and stop at day 30
    Given I wrote a published post "Young" with:
      | published_at | 1 day ago |
    And I wrote a published post "Nine" with:
      | published_at | 9 days ago |
    And I wrote a published post "Old" with:
      | published_at | 60 days ago |
    And the post analytics rolled up "1 day ago" for "/writing/young":
      | views | visitors | bounces |
      | 6     | 6        | 0       |
    And the post analytics table analytics_events holds:
      | path           | visitor_hash | address_hash |
      | /writing/young | one          | one          |
      | /writing/young | two          | two          |
    When I open the analytics for "Young"
    Then the first 30 days read:
      | 1 | 6 |
      | 2 | 2 |
    When I open the analytics for "Nine"
    Then the first 30 days draw 10 points for the post
    When I open the analytics for "Old"
    Then the first 30 days draw 30 points for the post

  Scenario: A draft has no first 30 days
    Given I wrote a draft post "Draft"
    When I open the analytics for "Draft"
    Then the card "First 30 days" says "Not published yet."

  Scenario: A post that is not there is not found
    When I visit "/admin/posts/999/analytics"
    Then the server answers 404
