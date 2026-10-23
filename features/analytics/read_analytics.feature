Feature: Reading analytics through MCP
  An agent reads the site's traffic with read_analytics: rolled up days, the raw
  visits since the last roll up, and one page alone when it names a path. Days
  run on Chicago time.

  Background:
    Given an MCP client connected with the scopes "read"

  Scenario: read_analytics adds up the days in the range and names a quiet day zero
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today-1 | 10    | 4        | 100          |
      | today-2 | 5     | 2        | 50           |
      | today-9 | 99    | 9        | 990          |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {
        "time_zone": "America/Chicago",
        "totals": {"views": 15, "visitors": 6, "read_seconds": 150, "read_throughs": 0, "reach": 0}
      }
      """
    And the answer at "days" is:
      """
      [
        {"day": "{today-6}", "views": 0, "visitors": 0},
        {"day": "{today-5}", "views": 0, "visitors": 0},
        {"day": "{today-4}", "views": 0, "visitors": 0},
        {"day": "{today-3}", "views": 0, "visitors": 0},
        {"day": "{today-2}", "views": 5, "visitors": 2},
        {"day": "{today-1}", "views": 10, "visitors": 4},
        {"day": "{today}", "views": 0, "visitors": 0}
      ]
      """

  Scenario: read_analytics ranks and sums the paths, referrers and countries
    Given these analytics_rollups rows:
      | day     | views | visitors |
      | today-2 | 10    | 5        |
      | today-1 | 50    | 30       |
    And these analytics_rollup_paths rows:
      | day     | path          | views | visitors | bounces |
      | today-2 | /writing/loud | 3     | 2        | 0       |
      | today-1 | /writing/loud | 40    | 20       | 0       |
      | today-1 | /writing/quiet| 5     | 5        | 0       |
    And these analytics_rollup_referrers rows:
      | day     | host         | views | visitors |
      | today-1 | busy.example | 9     | 2        |
      | today-1 | wide.example | 5     | 4        |
      | today-1 | tie.example  | 3     | 1        |
      | today-1 | none         | 3     | 1        |
      | today-1 | odd.example  | 4     | none     |
    And these analytics_rollup_countries rows:
      | day     | country_code | country_name  | views | visitors |
      | today-1 | DE           | none          | 9     | 2        |
      | today-1 | US           | United States | 5     | 4        |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {
        "paths": [
          {"path": {"untrusted": true, "text": "/writing/loud"}, "views": 43, "visitors": 22},
          {"path": {"untrusted": true, "text": "/writing/quiet"}, "views": 5, "visitors": 5}
        ],
        "referrers": [
          {"host": {"untrusted": true, "text": "wide.example"}, "views": 5, "visitors": 4},
          {"host": {"untrusted": true, "text": "busy.example"}, "views": 9, "visitors": 2},
          {"host": null, "views": 3, "visitors": 1},
          {"host": {"untrusted": true, "text": "tie.example"}, "views": 3, "visitors": 1},
          {"host": {"untrusted": true, "text": "odd.example"}, "views": 4, "visitors": null}
        ],
        "countries": [
          {"country_code": "US", "country_name": "United States", "views": 5, "visitors": 4},
          {"country_code": "DE", "country_name": null, "views": 9, "visitors": 2}
        ]
      }
      """

  Scenario: read_analytics sums visitors only over the days that counted them
    Given these analytics_rollups rows:
      | day     | views | visitors |
      | today-5 | 20    | 10       |
      | today-1 | 20    | 10       |
    And these analytics_rollup_referrers rows:
      | day     | host         | views | visitors |
      | today-5 | news.example | 6     | none     |
      | today-1 | news.example | 2     | 1        |
      | today-5 | old.example  | 9     | none     |
    And these analytics_rollup_countries rows:
      | day     | country_code | views | visitors |
      | today-5 | US           | 6     | none     |
    And these analytics_events rows:
      | referrer_host | country_code | country_name  |
      | news.example  | US           | United States |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {
        "referrers": [
          {"host": {"untrusted": true, "text": "news.example"}, "views": 9, "visitors": 2},
          {"host": {"untrusted": true, "text": "old.example"}, "views": 9, "visitors": null}
        ],
        "countries": [{"country_code": "US", "country_name": "United States", "views": 7, "visitors": 1}]
      }
      """

  Scenario: read_analytics counts today's visits before they roll up
    Given these analytics_events rows:
      | path           | visitor | referrer_host | country_code | times |
      | /writing/today | ann     | news.example  | US           | 2     |
      | /writing/today | ann     | blog.example  | US           | 1     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {
        "paths": [{"path": {"untrusted": true, "text": "/writing/today"}, "views": 3, "visitors": 1}],
        "referrers": [
          {"host": {"untrusted": true, "text": "news.example"}, "views": 2, "visitors": 1},
          {"host": {"untrusted": true, "text": "blog.example"}, "views": 1, "visitors": 1}
        ],
        "countries": [{"country_code": "US", "views": 3, "visitors": 1}]
      }
      """
    And the answer at "days.-1" is:
      """
      {"day": "{today}", "views": 3, "visitors": 1}
      """

  Scenario: read_analytics reads days not rolled up yet from the raw visits
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today-3 | 4     | 2        | 40           |
    And these analytics_events rows:
      | path           | occurred_at   | referrer_host | country_code | times |
      | /writing/rolled| today-3 12:00 | news.example  | US           | 1     |
      | /writing/early | today-2 12:00 | old.example   | US           | 1     |
      | /writing/late  | today-1 12:00 | news.example  | DE           | 2     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {
        "totals": {"views": 7, "visitors": 5, "read_seconds": 166, "read_throughs": 0, "reach": 0},
        "paths": [
          {"path": {"untrusted": true, "text": "/writing/late"}, "views": 2},
          {"path": {"untrusted": true, "text": "/writing/early"}, "views": 1}
        ],
        "referrers": [
          {"host": {"untrusted": true, "text": "news.example"}, "views": 2},
          {"host": {"untrusted": true, "text": "old.example"}, "views": 1}
        ],
        "countries": [{"country_code": "DE", "views": 2}, {"country_code": "US", "views": 1}]
      }
      """
    And the answer at "days" is:
      """
      [
        {"day": "{today-6}", "views": 0, "visitors": 0},
        {"day": "{today-5}", "views": 0, "visitors": 0},
        {"day": "{today-4}", "views": 0, "visitors": 0},
        {"day": "{today-3}", "views": 4, "visitors": 2},
        {"day": "{today-2}", "views": 1, "visitors": 1},
        {"day": "{today-1}", "views": 2, "visitors": 2},
        {"day": "{today}", "views": 0, "visitors": 0}
      ]
      """

  Scenario: read_analytics sends the top 25 paths and referrers
    Given 26 rolled up paths and referrers on "today-1", each bigger than the last
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer at "paths" counts 25 items
    And the answer at "referrers" counts 25 items
    And the answer at "paths.24.path.text" is:
      """
      "/writing/rolled-1"
      """
    And the answer at "referrers.24.host.text" is:
      """
      "rolled-1.example"
      """

  Scenario: read_analytics ranks today's path and referrer among the rolled up ones
    Given 26 rolled up paths and referrers on "today-1", each bigger than the last
    And these analytics_events rows:
      | path           | referrer_host | times |
      | /writing/fresh | fresh.example | 28    |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer at "paths" counts 25 items
    And the answer at "paths.0.path.text" is:
      """
      "/writing/fresh"
      """
    And the answer at "referrers.0.host.text" is:
      """
      "fresh.example"
      """
    And the answer at "referrers" counts 25 items

  Scenario Outline: read_analytics refuses a range it cannot read
    When I read the analytics through MCP with:
      """
      <range>
      """
    Then the answer says "<refusal>"

    Examples:
      | range                                                     | refusal                                    |
      | {"from": "last week", "to": "{today}"}                    | give from and to as days, such as 2026-01-01 |
      | {"from": "{today}", "to": "{today-1}"}                    | from comes after to                        |
      | {"from": "{today-366}", "to": "{today}"}                  | give a range of 366 days or fewer          |
      | {"from": "{today-366}", "to": "{today}", "path": "/"}     | give a range of 366 days or fewer          |
      | {"from": "{today-1}", "to": "{today-1}", "since": "this morning"} | give since as an ISO 8601 time, such as 2026-10-01T09:00:00-05:00 |

  Scenario: read_analytics reads a range of 366 days
    When I read the analytics through MCP with:
      """
      {"from": "{today-365}", "to": "{today}"}
      """
    Then the answer at "days" counts 366 items

  Scenario: read_analytics counts the read-throughs of the site and of each page
    Given these analytics_rollups rows:
      | day     | views | visitors |
      | today-2 | 20    | 10       |
      | today-9 | 20    | 10       |
    And these analytics_rollup_paths rows:
      | day     | path           | views | visitors | bounces | read_throughs |
      | today-2 | /writing/hello | 9     | 5        | 0       | 3             |
      | today-9 | /writing/hello | 9     | 5        | 0       | 4             |
    And these analytics_events rows:
      | path           | scroll_depth | read_seconds | times |
      | /writing/hello | 75           | 30           | 2     |
      | /writing/other | 75           | 30           | 1     |
      | /writing/other | 100          | 10           | 1     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {
        "totals": {"read_throughs": 6},
        "paths": [
          {"path": {"untrusted": true, "text": "/writing/hello"}, "read_throughs": 5},
          {"path": {"untrusted": true, "text": "/writing/other"}, "read_throughs": 1}
        ]
      }
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer holds:
      """
      {"totals": {"read_throughs": 5}}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/quiet"}
      """
    Then the answer holds:
      """
      {"totals": {"read_throughs": 0}}
      """
    And the read_analytics tool describes "scrolled at least 75% down a page and read it for at least 30 seconds"
    And the read_analytics tool describes "capped at 20 minutes a view"
    And the read_analytics tool describes "in the 12 months after it went out"

  Scenario: read_analytics counts a reader's read-through once a day and again the next
    Given these analytics_events rows:
      | path           | visitor | scroll_depth | read_seconds | occurred_at   |
      | /writing/hello | ann     | 75           | 30           | today-1 12:00 |
    And the job "Analytics::Jobs::RollUpAnalytics" runs
    And these analytics_events rows:
      | path           | visitor | scroll_depth | read_seconds | times |
      | /writing/hello | ann     | 75           | 30           | 2     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"totals": {"read_throughs": 2}, "paths": [{"path": {"untrusted": true, "text": "/writing/hello"}, "read_throughs": 2}]}
      """

  Scenario: read_analytics counts no read-throughs for a day rolled up before the site counted them
    Given these analytics_rollup_paths rows:
      | day     | path           | views | visitors | bounces | read_throughs |
      | today-1 | /writing/hello | 9     | 5        | 0       | none          |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}"}
      """
    Then the answer holds:
      """
      {"totals": {"read_throughs": 0}}
      """

  Scenario: read_analytics counts readers by weekday and hour over the last 90 days
    Given these analytics_events rows:
      | occurred_at      | times |
      | monday-14 09:00  | 2     |
      | monday-15 21:00  | 1     |
      | today-120 09:00  | 1     |
    And these analytics_rollup_hours rows:
      | day       | hour | visitors |
      | monday-7  | 9    | 3        |
      | today-90  | 9    | 5        |
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"weekday_hours": {"from": "{today-89}", "to": "{today}", "time_zone": "America/Chicago"}}
      """
    And the answer at "weekday_hours.hours" counts 24 items
    And the weekday grid counts 5 at hour 9 on Monday
    And the weekday grid counts 1 at hour 21 on Sunday
    And the weekday grid counts 6 readers in all

  Scenario: read_analytics gives the same weekday grid once the days roll up
    Given these analytics_events rows:
      | occurred_at     |
      | monday-14 09:00 |
      | today-1 23:00   |
      | today 00:00     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    And I keep the answer
    And the job "Analytics::Jobs::RollUpAnalytics" runs
    And I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer at "weekday_hours" is the kept one
    And the weekday grid counts 3 readers in all

  Scenario: read_analytics keeps the site's lists out of a page's answer
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer has the keys "from, to, time_zone, path, totals, days, referrers, countries, sources, devices, clicks, scroll, hours, read_spread, internal_referrers"

  Scenario: read_analytics keeps the site's cards out of a page's answer
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}", "path": "/about"}
      """
    Then the answer leaves out "weekday_hours, change, feed, webmentions, entry_pages, exit_pages, since_publish, first_days, unique_readers"
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}"}
      """
    Then the answer leaves out "scroll, since"

  Scenario: read_analytics counts a reader's reach once a month
    Given these analytics_events rows:
      | path           | visitor | occurred_at   |
      | /writing/hello | reader  | first-3 12:00 |
      | /writing/hello | reader  | first-2 12:00 |
    When I read the analytics through MCP with:
      """
      {"from": "{first-3}", "to": "{first-2}"}
      """
    Then the answer holds:
      """
      {"totals": {"visitors": 2, "reach": 1}}
      """

  Scenario: read_analytics counts a reader in two months as two reach
    Given these analytics_events rows:
      | path           | visitor | occurred_at   |
      | /writing/hello | reader  | first-1 12:00 |
      | /writing/hello | reader  | first 12:00   |
    When I read the analytics through MCP with:
      """
      {"from": "{first-1}", "to": "{first}"}
      """
    Then the answer holds:
      """
      {"totals": {"visitors": 2, "reach": 2}}
      """

  Scenario: read_analytics counts the reach of the site and of one page
    Given these analytics_events rows:
      | path           | visitor | occurred_at |
      | /writing/hello | reader  | first 12:00 |
      | /writing/other | reader  | first 12:00 |
      | /writing/other | other   | first 12:00 |
    When I read the analytics through MCP with:
      """
      {"from": "{first}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"totals": {"views": 3, "reach": 2}}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{first}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer holds:
      """
      {"totals": {"reach": 1}}
      """

  Scenario: read_analytics reads the reach of a month past the raw visits from its rollup
    Given these analytics_rollup_reach rows:
      | month           | path           | reach |
      | today-150 first | none           | 7     |
      | today-150 first | /writing/hello | 3     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-150 first}", "to": "{today-150 last}"}
      """
    Then the answer holds:
      """
      {"totals": {"reach": 7}}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-150 first}", "to": "{today-150 last}", "path": "/writing/hello"}
      """
    Then the answer holds:
      """
      {"totals": {"reach": 3}}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-150 first}", "to": "{today-150 last}", "path": "/nowhere"}
      """
    Then the answer holds:
      """
      {"totals": {"reach": 0}}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-150 first+1}", "to": "{today-150 last}"}
      """
    Then the answer holds:
      """
      {"totals": {"reach": null}}
      """

  Scenario: read_analytics adds the rolled up months to the months the raw visits hold
    Given every month from "today-150" to "today-89" rolled up a reach of 7
    And these analytics_events rows:
      | visitor | occurred_at |
      | reader  | first 12:00 |
    When I read the analytics through MCP with:
      """
      {"from": "{today-150 first}", "to": "{today}"}
      """
    Then the answer reach is 7 for each of those months plus 1

  Scenario: read_analytics ranks the site's sources apart from each page's
    Given these analytics_rollup_sources rows:
      | day      | path           | source  | views | visitors |
      | today-2  | none           | feed    | 9     | 2        |
      | today-1  | none           | reddit  | 4     | 3        |
      | today-1  | none           | feed    | 1     | 1        |
      | today-1  | /writing/hello | reddit  | 4     | 2        |
      | today-1  | /writing/other | feed    | 5     | 3        |
      | today-200| /writing/hello | bluesky | 5     | 3        |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"sources": [
        {"source": {"untrusted": true, "text": "feed"}, "views": 10, "visitors": 3},
        {"source": {"untrusted": true, "text": "reddit"}, "views": 4, "visitors": 3}
      ]}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer holds:
      """
      {"sources": [{"source": {"untrusted": true, "text": "reddit"}, "views": 4, "visitors": 2}]}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-200}", "to": "{today-200}", "path": "/writing/hello"}
      """
    Then the answer holds:
      """
      {"sources": [{"source": {"untrusted": true, "text": "bluesky"}, "views": 5, "visitors": 3}]}
      """

  Scenario: read_analytics counts today's sources from the visits
    Given these analytics_events rows:
      | path           | source   | visitor | times |
      | /writing/hello | mastodon | reader  | 2     |
      | /writing/other | mastodon |         | 1     |
      | /writing/other |          |         | 1     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"sources": [{"source": {"untrusted": true, "text": "mastodon"}, "views": 3, "visitors": 2}]}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer holds:
      """
      {"sources": [{"source": {"untrusted": true, "text": "mastodon"}, "views": 2, "visitors": 1}]}
      """

  Scenario: read_analytics gives no sources when no visit carried a ref
    Given these analytics_events rows:
      | path           |
      | /writing/hello |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer at "sources" is:
      """
      []
      """

  Scenario: read_analytics ranks the site's device classes apart from each page's
    Given these analytics_rollup_devices rows:
      | day       | path           | device_class | views | visitors |
      | today-2   | none           | mobile       | 9     | 2        |
      | today-1   | none           | in-app       | 4     | 3        |
      | today-1   | none           | mobile       | 1     | 1        |
      | today-1   | /writing/hello | tablet       | 4     | 2        |
      | today-1   | /writing/other | desktop      | 5     | 3        |
      | today-200 | /writing/hello | mobile       | 5     | 3        |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer at "devices" is:
      """
      [
        {"device_class": "mobile", "views": 10, "visitors": 3},
        {"device_class": "in-app", "views": 4, "visitors": 3}
      ]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer at "devices" is:
      """
      [{"device_class": "tablet", "views": 4, "visitors": 2}]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-200}", "to": "{today-200}", "path": "/writing/hello"}
      """
    Then the answer at "devices" is:
      """
      [{"device_class": "mobile", "views": 5, "visitors": 3}]
      """

  Scenario: read_analytics counts today's device classes from the visits
    Given these analytics_events rows:
      | path           | device_class | visitor | times |
      | /writing/hello | in-app       | reader  | 2     |
      | /writing/other | in-app       |         | 1     |
      | /writing/other |              |         | 1     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer at "devices" is:
      """
      [{"device_class": "in-app", "views": 3, "visitors": 2}]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer at "devices" is:
      """
      [{"device_class": "in-app", "views": 2, "visitors": 1}]
      """

  Scenario: read_analytics gives the share of a page's views that reached each depth
    Given these analytics_rollup_scroll_depths rows:
      | day       | path           | scroll_depth | views | visitors |
      | today-2   | /writing/hello | 0            | 5     | 5        |
      | today-2   | /writing/hello | 50           | 5     | 5        |
      | today-2   | /writing/hello | 100          | 4     | 4        |
      | today-1   | /writing/hello | 0            | 5     | 5        |
      | today-1   | /writing/hello | 25           | 10    | 10       |
      | today-1   | /writing/hello | 75           | 6     | 6        |
      | today-1   | /writing/hello | 100          | 5     | 5        |
      | today-1   | /writing/other | 100          | 90    | 90       |
      | today-200 | /writing/hello | 0            | 1     | 1        |
      | today-200 | /writing/hello | 50           | 2     | 2        |
      | today-200 | /writing/hello | 100          | 1     | 1        |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer at "scroll" is:
      """
      {"views": 40, "reached": [
        {"depth": 25, "views": 30, "share": 0.75},
        {"depth": 50, "views": 20, "share": 0.5},
        {"depth": 75, "views": 15, "share": 0.375},
        {"depth": 100, "views": 9, "share": 0.225}
      ]}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-200}", "to": "{today-200}", "path": "/writing/hello"}
      """
    Then the answer at "scroll.reached" is:
      """
      [
        {"depth": 25, "views": 3, "share": 0.75},
        {"depth": 50, "views": 3, "share": 0.75},
        {"depth": 75, "views": 1, "share": 0.25},
        {"depth": 100, "views": 1, "share": 0.25}
      ]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/quiet"}
      """
    Then the answer at "scroll" is:
      """
      {"views": 0, "reached": [
        {"depth": 25, "views": 0, "share": null},
        {"depth": 50, "views": 0, "share": null},
        {"depth": 75, "views": 0, "share": null},
        {"depth": 100, "views": 0, "share": null}
      ]}
      """

  Scenario: read_analytics counts today's scroll depths from the visits
    Given these analytics_events rows:
      | path           | scroll_depth |
      | /writing/hello | 0            |
      | /writing/hello | 25           |
      | /writing/hello | 100          |
      | /writing/hello | 100          |
      | /writing/hello | none         |
      | /writing/other | 100          |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer at "scroll.reached" is:
      """
      [
        {"depth": 25, "views": 3, "share": 0.75},
        {"depth": 50, "views": 2, "share": 0.5},
        {"depth": 75, "views": 2, "share": 0.5},
        {"depth": 100, "views": 2, "share": 0.5}
      ]
      """

  Scenario: read_analytics gives one page's totals and days
    Given these analytics_rollups rows:
      | day     | views | visitors |
      | today-2 | 50    | 20       |
      | today-1 | 50    | 20       |
    And these analytics_rollup_paths rows:
      | day     | path           | views | visitors | read_seconds | bounces |
      | today-2 | /writing/hello | 4     | 3        | 40           | 2       |
      | today-2 | /writing/other | 9     | 9        | 90           | 9       |
      | today-1 | /writing/hello | 6     | 5        | 60           | 0       |
    And these analytics_events rows:
      | path           | read_seconds | times |
      | /writing/hello | 30           | 2     |
      | /writing/other | 30           | 1     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer at "totals" is:
      """
      {"views": 12, "visitors": 10, "read_seconds": 160, "read_throughs": 0, "bounces": 4, "reach": 0}
      """
    And the answer at "days.-1" is:
      """
      {"day": "{today}", "views": 2, "visitors": 2, "read_seconds": 60}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-3}", "to": "{today-1}", "path": "/writing/hello"}
      """
    Then the answer at "days" is:
      """
      [
        {"day": "{today-3}", "views": 0, "visitors": 0, "read_seconds": 0},
        {"day": "{today-2}", "views": 4, "visitors": 3, "read_seconds": 40},
        {"day": "{today-1}", "views": 6, "visitors": 5, "read_seconds": 60}
      ]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/nowhere"}
      """
    Then the answer at "totals" is:
      """
      {"views": 0, "visitors": 0, "read_seconds": 0, "read_throughs": 0, "bounces": 0, "reach": 0}
      """

  Scenario: read_analytics ranks one page's referrers and countries
    Given these analytics_rollup_page_referrers rows:
      | day       | path           | host         | views | visitors |
      | today-2   | /writing/hello | news.example | 3     | 2        |
      | today-1   | /writing/hello | news.example | 2     | 2        |
      | today-1   | /writing/hello | none         | 9     | 3        |
      | today-1   | /writing/other | else.example | 9     | 9        |
      | today-200 | /writing/hello | old.example  | 5     | 3        |
    And these analytics_rollup_page_countries rows:
      | day       | path           | country_code | country_name | views | visitors |
      | today-1   | /writing/hello | JP           | Japan        | 2     | 1        |
      | today-1   | /writing/hello | US           | none         | 6     | 4        |
      | today-1   | /writing/other | DE           | none         | 9     | 9        |
      | today-200 | /writing/hello | JP           | none         | 5     | 3        |
    And these analytics_rollup_referrers rows:
      | day     | host         | views | visitors |
      | today-1 | site.example | 5     | 5        |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer holds:
      """
      {
        "referrers": [
          {"host": {"untrusted": true, "text": "news.example"}, "views": 5, "visitors": 4},
          {"host": null, "views": 9, "visitors": 3}
        ],
        "countries": [
          {"country_code": "US", "views": 6, "visitors": 4},
          {"country_code": "JP", "country_name": "Japan", "views": 2, "visitors": 1}
        ]
      }
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-200}", "to": "{today-200}", "path": "/writing/hello"}
      """
    Then the answer holds:
      """
      {
        "referrers": [{"host": {"untrusted": true, "text": "old.example"}, "views": 5, "visitors": 3}],
        "countries": [{"country_code": "JP", "views": 5, "visitors": 3}]
      }
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/nobody"}
      """
    Then the answer holds:
      """
      {"referrers": [], "countries": []}
      """

  Scenario: read_analytics counts one page's referrers and countries before they roll up
    Given these analytics_rollup_page_countries rows:
      | day     | path           | country_code | country_name | views | visitors |
      | today-1 | /writing/hello | JP           | Japan        | 2     | 1        |
    And these analytics_events rows:
      | path           | country_code | country_name  | visitor | times |
      | /writing/hello | US           | United States | reader  | 2     |
      | /writing/other | US           | United States |         | 1     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer holds:
      """
      {
        "referrers": [{"host": {"untrusted": true, "text": "news.example"}, "views": 2, "visitors": 1}],
        "countries": [
          {"country_code": "JP", "country_name": "Japan", "views": 2, "visitors": 1},
          {"country_code": "US", "country_name": "United States", "views": 2, "visitors": 1}
        ]
      }
      """

  Scenario: read_analytics ranks the links followed off a page
    Given these analytics_rollup_clicks rows:
      | day     | path           | link_host    | link_path | clicks |
      | today-2 | /writing/hello | docs.example | /a        | 2      |
      | today-2 | /writing/hello | code.example | /b        | 5      |
      | today-2 | /writing/other | else.example | /c        | 9      |
    And these analytics_events rows:
      | path           | view_token |
      | /writing/hello | hello      |
    And these analytics_clicks rows:
      | view  | link_host    | link_path |
      | hello | docs.example | /a        |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer at "clicks" is:
      """
      [
        {"link_host": {"untrusted": true, "text": "code.example"}, "link_path": {"untrusted": true, "text": "/b"}, "clicks": 5},
        {"link_host": {"untrusted": true, "text": "docs.example"}, "link_path": {"untrusted": true, "text": "/a"}, "clicks": 3}
      ]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer at "clicks" is:
      """
      [{"link_host": {"untrusted": true, "text": "docs.example"}, "link_path": {"untrusted": true, "text": "/a"}, "clicks": 1}]
      """

  Scenario: read_analytics numbers a post's days from the Chicago day it went out
    Given these analytics posts:
      | slug     | published     |
      | part-two | today-3 23:30 |
    And these analytics_rollups rows:
      | day     | views | visitors |
      | today-3 | 50    | 20       |
      | today-2 | 50    | 20       |
    And these analytics_rollup_paths rows:
      | day     | path              | views | visitors | read_seconds | bounces |
      | today-3 | /writing/part-two | 4     | 3        | 40           | 0       |
      | today-2 | /writing/part-two | 8     | 7        | 80           | 0       |
    When I read the analytics through MCP with:
      """
      {"from": "{today-5}", "to": "{today-2}", "path": "/writing/part-two"}
      """
    Then the answer at "since_publish" is:
      """
      [
        {"day": 1, "date": "{today-3}", "views": 4, "visitors": 3, "read_seconds": 40},
        {"day": 2, "date": "{today-2}", "views": 8, "visitors": 7, "read_seconds": 80}
      ]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-2}", "to": "{today-2}", "path": "/writing/part-two"}
      """
    Then the answer holds:
      """
      {"since_publish": [{"day": 2, "date": "{today-2}"}]}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}", "path": "/writing/part-two"}
      """
    Then the answer at "first_days" is:
      """
      {"span": 30, "days": [3, 7, 0, 0], "median": [3, 7, 0, 0]}
      """
    And the answer at "unique_readers" is:
      """
      {"readers": 0, "final": false}
      """

  Scenario: read_analytics counts a young post's unique readers
    Given these analytics posts:
      | slug     | published     |
      | part-two | today-3 12:00 |
    And these post_reader_hashes rows:
      | path              | times |
      | /writing/part-two | 2     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/part-two"}
      """
    Then the answer at "unique_readers" is:
      """
      {"readers": 2, "final": false}
      """

  Scenario: read_analytics gives an old post's saved unique readers as final
    Given these analytics posts:
      | slug | published |
      | old  | today-400 |
      | lost | today-400 |
    And these post_reader_counts rows:
      | path         | readers |
      | /writing/old | 1234    |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/old"}
      """
    Then the answer at "unique_readers" is:
      """
      {"readers": 1234, "final": true}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/lost"}
      """
    Then the answer at "unique_readers" is:
      """
      {"readers": null, "final": true}
      """

  Scenario: read_analytics gives no post figures for a draft or a page that is not a post
    Given these analytics posts:
      | slug   | status |
      | unsent | draft  |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/writing/unsent"}
      """
    Then the answer leaves out "since_publish"
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}", "path": "/about"}
      """
    Then the answer leaves out "since_publish, first_days, unique_readers"

  Scenario: read_analytics takes the median post of each first day
    Given these analytics posts:
      | slug  | published     | status    |
      | one   | today-3 12:00 | published |
      | two   | today-2 12:00 | published |
      | three | today-1 12:00 | published |
      | draft | today-3 12:00 | draft     |
      | older | today-20 12:00| published |
    And these analytics_rollup_paths rows:
      | day     | path           | views | visitors | bounces |
      | today-3 | /writing/one   | 2     | 2        | 0       |
      | today-2 | /writing/one   | 8     | 8        | 0       |
      | today-1 | /writing/one   | 1     | 1        | 0       |
      | today   | /writing/one   | 4     | 4        | 0       |
      | today-2 | /writing/two   | 6     | 6        | 0       |
      | today-1 | /writing/two   | 2     | 2        | 0       |
      | today-1 | /writing/three | 4     | 4        | 0       |
      | today   | /writing/three | 5     | 5        | 0       |
      | today-3 | /writing/draft | 100   | 100      | 0       |
    And these analytics_events rows:
      | occurred_at    |
      | today-19 12:00 |
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}", "path": "/writing/one"}
      """
    Then the answer at "first_days.median" is:
      """
      [4, 5, 0.5, 4]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}", "path": "/writing/three"}
      """
    Then the answer at "first_days.median" counts 4 items

  Scenario: read_analytics counts a newer post nobody read as zeros in the median
    Given these analytics posts:
      | slug   | published     |
      | one    | today-3 12:00 |
      | two    | today-2 12:00 |
      | three  | today-1 12:00 |
      | unread | today-3 12:00 |
    And these analytics_rollup_paths rows:
      | day     | path           | views | visitors | bounces |
      | today-3 | /writing/one   | 2     | 2        | 0       |
      | today-2 | /writing/one   | 8     | 8        | 0       |
      | today-1 | /writing/one   | 1     | 1        | 0       |
      | today   | /writing/one   | 4     | 4        | 0       |
      | today-2 | /writing/two   | 6     | 6        | 0       |
      | today-1 | /writing/two   | 2     | 2        | 0       |
      | today-1 | /writing/three | 4     | 4        | 0       |
      | today   | /writing/three | 5     | 5        | 0       |
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}", "path": "/writing/one"}
      """
    Then the answer at "first_days.median" is:
      """
      [3, 3.5, 0, 2]
      """

  Scenario: read_analytics counts the publish day as day one in Chicago time
    Given these analytics posts:
      | slug  | published     |
      | hello | today-2 23:59 |
    And these analytics_rollup_paths rows:
      | day     | path           | views | visitors | bounces |
      | today-1 | /writing/hello | 3     | 3        | 0       |
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}", "path": "/writing/hello"}
      """
    Then the answer at "first_days.days" is:
      """
      [0, 3, 0]
      """

  Scenario: read_analytics sets the views against the range before
    Given these analytics_rollups rows:
      | day      | views | visitors |
      | today-1  | 15    | 4        |
      | today-7  | 10    | 4        |
      | today-13 | 10    | 4        |
      | today-14 | 99    | 9        |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer at "change" is:
      """
      {"from": "{today-13}", "to": "{today-7}", "views": 20, "percent": -25}
      """

  Scenario: read_analytics adds the live views of days before the range not yet rolled up
    Given these analytics_rollups rows:
      | day      | views | visitors |
      | today-1  | 15    | 4        |
      | today-13 | 10    | 4        |
    And these analytics_events rows:
      | occurred_at   | times |
      | today-8 01:00 | 2     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"change": {"views": 12, "percent": 25}}
      """

  Scenario: read_analytics gives no percent when the range before had no views
    Given these analytics_rollups rows:
      | day     | views | visitors |
      | today-1 | 15    | 4        |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"change": {"views": 0, "percent": null}}
      """

  Scenario: read_analytics counts the feed subscribers and other readers
    Given these feed_subscribers rows:
      | day     | path                     | aggregator | subscribers |
      | today   | /writing.atom            | feedly     | 40          |
      | today   | /writing/tags/ruby.atom  | feedly     | 2           |
      | today-1 | /writing.atom            | inoreader  | 9           |
      | today-9 | /writing.atom            | newsblur   | 5           |
    And these feed_readers rows:
      | day     | readers |
      | today-1 | 3       |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"feed": {
        "latest": 12,
        "readers": 3,
        "aggregators": [{"aggregator": "inoreader", "subscribers": 9}]
      }}
      """
    And the answer at "feed.days" counts 7 items
    And the answer at "feed.days.-2" is:
      """
      {"day": "{today-1}", "subscribers": 12}
      """
    And the answer at "feed.days.-1" is:
      """
      {"day": "{today}", "subscribers": 42}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-15}", "to": "{today-9}"}
      """
    Then the answer at "feed.aggregators" is:
      """
      [{"aggregator": "newsblur", "subscribers": 5}]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"feed": {"latest": 12, "readers": 3, "aggregators": [{"aggregator": "inoreader", "subscribers": 9}]}}
      """

  Scenario: read_analytics counts the webmentions per post
    Given these analytics posts:
      | title | published |
      | Hello | today-30  |
      | Other | today-30  |
    And these webmentions rows:
      | post  | received_at   | status   | times |
      | Hello | today 00:00   | pending  | 2     |
      | Other | today-1 00:00 | approved | 1     |
      | Other | today-8 00:00 | pending  | 1     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-6}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"webmentions": {
        "pending": 3,
        "received": 3,
        "posts": [{"post_id": 1, "title": "Hello", "received": 2}, {"post_id": 2, "title": "Other", "received": 1}]
      }}
      """

  Scenario: read_analytics gives the views of each Chicago hour that had one
    Given these analytics_events rows:
      | path           | occurred_at   | visitor | read_seconds | times |
      | /writing/hello | today-1 09:15 | ann     | 10           | 2     |
      | /writing/hello | today-1 09:45 |         | 10           | 1     |
      | /writing/hello | today-1 14:05 |         | 10           | 1     |
      | /writing/other | today-1 10:00 |         | 10           | 1     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}"}
      """
    Then the answer at "hours" is:
      """
      [
        {"hour": "{today-1 09:00}", "views": 3, "visitors": 2},
        {"hour": "{today-1 10:00}", "views": 1, "visitors": 1},
        {"hour": "{today-1 14:00}", "views": 1, "visitors": 1}
      ]
      """
    And the answer leaves out "since"
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}", "path": "/writing/other"}
      """
    Then the answer at "hours" is:
      """
      [{"hour": "{today-1 10:00}", "views": 1, "visitors": 1}]
      """

  Scenario: read_analytics keeps apart the two hours a clock repeats when daylight saving ends
    Given these analytics_events rows:
      | occurred_at              |
      | {fallback}T06:30:00Z     |
      | {fallback}T07:30:00Z     |
    When I read the analytics through MCP with:
      """
      {"from": "{fallback}", "to": "{fallback}"}
      """
    Then the answer holds:
      """
      {"hours": [{"hour": "{fallback}T01:00:00-05:00"}, {"hour": "{fallback}T01:00:00-06:00"}]}
      """

  Scenario: read_analytics counts the views since a time
    Given these analytics_events rows:
      | path           | occurred_at   | read_seconds | times |
      | /writing/hello | today-1 09:00 | 10           | 1     |
      | /writing/late  | today-1 15:00 | 10           | 2     |
      | /writing/hello | today-1 16:00 | 10           | 1     |
      | /writing/hello | today 09:00   | 10           | 1     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}", "since": "{today-1 12:00}"}
      """
    Then the answer at "since" is:
      """
      {"at": "{today-1 12:00}", "views": 3, "visitors": 3, "read_seconds": 30, "paths": [
        {"path": {"untrusted": true, "text": "/writing/late"}, "views": 2, "visitors": 2},
        {"path": {"untrusted": true, "text": "/writing/hello"}, "views": 1, "visitors": 1}
      ]}
      """
    And the answer holds:
      """
      {"hours": [{"hour": "{today-1 15:00}"}, {"hour": "{today-1 16:00}"}]}
      """
    And the answer at "hours" counts 2 items
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}", "since": "{today-1}T15:30"}
      """
    Then the answer holds:
      """
      {"since": {"views": 1}}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}", "since": "{today-1 12:00}", "path": "/writing/hello"}
      """
    Then the answer at "since" is:
      """
      {"at": "{today-1 12:00}", "views": 1, "visitors": 1, "read_seconds": 10}
      """

  Scenario: read_analytics refuses the raw figures for a range older than the raw visits
    Given these analytics_rollups rows:
      | day       | views | visitors |
      | today-120 | 9     | 4        |
    And these analytics_events rows:
      | occurred_at   |
      | today-1 09:00 |
    When I read the analytics through MCP with:
      """
      {"from": "{today-120}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"totals": {"views": 10}}
      """
    And the answer at "refused" is:
      """
      "hours, since, read_spread and navigation read raw visits, which the site keeps for 90 days; start from or since inside them to get these. The daily counts still hold"
      """
    And the answer leaves out "hours, read_spread, entry_pages, exit_pages"
    When I read the analytics through MCP with:
      """
      {"from": "{today-120}", "to": "{today}", "since": "{today-120 00:00}"}
      """
    Then the answer leaves out "since"
    And the answer at "days.0" is:
      """
      {"day": "{today-120}", "views": 9, "visitors": 4}
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-120}", "to": "{today-1}", "since": "{today-1 08:00}"}
      """
    Then the answer at "hours" counts 1 items

  Scenario: read_analytics spreads the views by how long they read
    Given these analytics_events rows:
      | path           | occurred_at   | read_seconds |
      | /writing/hello | today-1 09:00 | 0            |
      | /writing/hello | today-1 09:00 | 0            |
      | /writing/hello | today-1 09:00 | 5            |
      | /writing/hello | today-1 09:00 | 9            |
      | /writing/hello | today-1 09:00 | 10           |
      | /writing/hello | today-1 09:00 | 45           |
      | /writing/hello | today-1 09:00 | 90           |
      | /writing/hello | today-1 09:00 | 200          |
      | /writing/hello | today-1 09:00 | 400          |
      | /writing/hello | today-1 15:00 | 1200         |
      | /writing/other | today-1 09:00 | 300          |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}", "path": "/writing/hello"}
      """
    Then the answer at "read_spread.buckets" is:
      """
      [
        {"from": 0, "to": 0, "views": 2},
        {"from": 1, "to": 9, "views": 2},
        {"from": 10, "to": 29, "views": 1},
        {"from": 30, "to": 59, "views": 1},
        {"from": 60, "to": 119, "views": 1},
        {"from": 120, "to": 299, "views": 1},
        {"from": 300, "to": 599, "views": 1},
        {"from": 600, "to": 1200, "views": 1}
      ]
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}", "since": "{today-1 12:00}"}
      """
    Then the answer at "read_spread.median" is:
      """
      1200.0
      """
    When I read the analytics through MCP with:
      """
      {"from": "{today}", "to": "{today}"}
      """
    Then the answer holds:
      """
      {"read_spread": {"median": null}}
      """

  Scenario: read_analytics leaves the views with no read out of the median
    Given these analytics_events rows:
      | occurred_at   | read_seconds |
      | today-1 09:00 | 0            |
      | today-1 09:00 | 0            |
      | today-1 09:00 | 0            |
      | today-1 09:00 | 10           |
      | today-1 09:00 | 20           |
      | today-1 09:00 | 90           |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}"}
      """
    Then the answer at "read_spread.median" is:
      """
      20.0
      """

  Scenario: read_analytics takes the middle of the two middle reads for an even count
    Given these analytics_events rows:
      | occurred_at   | read_seconds |
      | today-1 09:00 | 10           |
      | today-1 09:00 | 20           |
      | today-1 09:00 | 30           |
      | today-1 09:00 | 41           |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}"}
      """
    Then the answer at "read_spread.median" is:
      """
      25.0
      """

  Scenario: read_analytics gives no median when no view read
    Given these analytics_events rows:
      | occurred_at   | read_seconds | times |
      | today-1 09:00 | 0            | 2     |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}"}
      """
    Then the answer holds:
      """
      {"read_spread": {"median": null}}
      """
    And the answer at "read_spread.buckets.0" is:
      """
      {"from": 0, "to": 0, "views": 2}
      """

  Scenario: read_analytics ranks the pages on the site that sent readers to a page
    Given these analytics_events rows:
      | path           | visitor | occurred_at   | referrer_path |
      | /about         | a       | today-1 09:00 | /writing/new  |
      | /about         | b       | today-1 10:00 | /writing/new  |
      | /about         | c       | today-1 11:00 | /writing/old  |
      | /about         | c       | today-1 11:00 | /writing/old  |
      | /about         | d       | today-1 12:00 |               |
      | /writing/other | e       | today-1 12:00 | /writing/new  |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}", "path": "/about"}
      """
    Then the answer at "internal_referrers" is:
      """
      [
        {"path": {"untrusted": true, "text": "/writing/new"}, "views": 2, "visitors": 2},
        {"path": {"untrusted": true, "text": "/writing/old"}, "views": 2, "visitors": 1}
      ]
      """
    And the answer leaves out "entry_pages, exit_pages"
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}", "path": "/about", "since": "{today-1 11:00}"}
      """
    Then the answer at "internal_referrers" is:
      """
      [{"path": {"untrusted": true, "text": "/writing/old"}, "views": 2, "visitors": 1}]
      """

  Scenario: read_analytics ranks the pages visitors saw first and last
    Given these analytics_events rows:
      | path         | visitor | occurred_at   | referrer_path |
      | /writing/new | a       | today-1 09:00 |               |
      | /about       | a       | today-1 10:00 | /writing/new  |
      | /writing/new | b       | today-1 11:00 |               |
      | /writing/old | b       | today-1 12:00 |               |
      | /about       | c       | today-1 13:00 |               |
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}"}
      """
    Then the answer at "entry_pages" is:
      """
      [
        {"path": {"untrusted": true, "text": "/writing/new"}, "visitors": 2},
        {"path": {"untrusted": true, "text": "/about"}, "visitors": 1}
      ]
      """
    And the answer at "exit_pages" is:
      """
      [
        {"path": {"untrusted": true, "text": "/about"}, "visitors": 2},
        {"path": {"untrusted": true, "text": "/writing/old"}, "visitors": 1}
      ]
      """
    And the answer leaves out "internal_referrers"
    When I read the analytics through MCP with:
      """
      {"from": "{today-1}", "to": "{today-1}", "since": "{today-1 11:00}"}
      """
    Then the answer at "entry_pages" is:
      """
      [
        {"path": {"untrusted": true, "text": "/about"}, "visitors": 1},
        {"path": {"untrusted": true, "text": "/writing/new"}, "visitors": 1}
      ]
      """
