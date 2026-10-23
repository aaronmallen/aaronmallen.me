Feature: The analytics screen
  The owner reads the site's traffic over the last 7, 14 or 30 days: a chart of
  views a day, the top pages, referrers and countries, readers by hour, feed
  subscribers, webmentions and scroll depth.

  Background:
    Given I am signed in to the admin

  Scenario: The analytics screen sums the rolled up days of the range
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today   | 10    | 5        | 300          |
      | today-1 | 30    | 20       | 600          |
      | today-8 | 100   | 40       | 800          |
    When I visit "/admin/analytics?range=7" in the admin
    Then the page title is "Analytics | Admin | Aaron Allen"
    And the screen part ".page-head-sub" mentions "40 views from 25 visitors"
    And the screen part ".page-head-sub" mentions "in the last 7 days"
    And the screen part ".page-head-sub" mentions "on this server, with no outside scripts."
    And the screen part ".page-head-sub" mentions "0:22 average read"
    And the screen part ".page-head-sub" mentions "1.6 pages per visit"
    And the screen part ".page-head-sub" mentions "down 60% on the previous 7 days"
    And the screen holds "form[action='/admin/analytics'] [role=radiogroup][aria-label=Range]"
    And the screen holds "input[name='range'][value='7']:checked"
    And the screen holds no ".stat"
    And the screen parts ".chart-bar" are styled:
      | height: 0%   |
      | height: 0%   |
      | height: 0%   |
      | height: 0%   |
      | height: 0%   |
      | height: 100% |
      | height: 33%  |
    And the screen holds ".card-note:text-is('peak 30')"
    And the screen part ".chart-tip >> nth=-1" reads "{today short} · 10 views · 5 visitors"
    And the screen parts ".chart-dates span" read:
      | {today-6 short} |
      | {today-3 short} |
      | {today short}   |
    And the page has no axe breaches in light or dark

  Scenario: The analytics screen offers the 7, 14 and 30 day ranges
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today   | 10    | 5        | 300          |
      | today-8 | 100   | 40       | 800          |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen parts "form[action='/admin/analytics'] .seg-option" read:
      | 7d  |
      | 14d |
      | 30d |
    When I visit "/admin/analytics?range=14" in the admin
    Then the screen part ".page-head-sub" mentions "110 views"
    When I visit "/admin/analytics?range=30" in the admin
    Then the screen holds 30 of ".chart-bar"
    And the screen holds ".seg input[name='range'][value='30'][checked]"
    When I visit "/admin/analytics?range=90" in the admin
    Then the screen holds ".seg input[name='range'][value='30'][checked]"

  Scenario: The analytics screen compares against the previous range's raw views
    Given these analytics_rollups rows:
      | day   | views | visitors | read_seconds |
      | today | 10    | 5        | 300          |
    And these analytics_events rows:
      | occurred_at   | times |
      | today-8 12:00 | 2     |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen part ".page-head-sub" mentions "up 400% on the previous 7 days"

  Scenario: The analytics screen says the previous range had no views
    Given these analytics_rollups rows:
      | day   | views | visitors | read_seconds |
      | today | 10    | 5        | 300          |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen part ".page-head-sub" mentions "and none in the previous 7 days"
    And the screen part ".page-head-sub" does not mention "% on the previous"

  Scenario: The analytics screen counts today's raw visits
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today-1 | 4     | 2        | 40           |
    And these analytics_events rows:
      | path           | title | read_seconds |
      | /writing/hello | Hello | 60           |
      | /writing/hello | Hello | 30           |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen part ".page-head-sub" mentions "6 views"
    And the screen part ".chart-tip >> nth=-1" reads "{today short} · 2 views · 2 visitors"
    And the screen part ".tbl-title" mentions "Hello"

  Scenario: The analytics screen reads days not rolled up yet from the raw visits
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today-3 | 4     | 2        | 40           |
    And these analytics_events rows:
      | path            | title | read_seconds | occurred_at   | times |
      | /writing/rolled | none  | 42           | today-3 12:00 | 1     |
      | /writing/hello  | Hello | 60           | today-2 12:00 | 1     |
      | /writing/late   | none  | 42           | today-1 12:00 | 2     |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen part ".page-head-sub" mentions "7 views"
    And the screen parts ".chart-tip" read:
      | {today-6 short} · 0 views · 0 visitors |
      | {today-5 short} · 0 views · 0 visitors |
      | {today-4 short} · 0 views · 0 visitors |
      | {today-3 short} · 4 views · 2 visitors |
      | {today-2 short} · 1 view · 1 visitor   |
      | {today-1 short} · 2 views · 2 visitors |
      | {today short} · 0 views · 0 visitors   |
    And the screen holds ".tbl-title:has-text('Hello')"
    And the screen holds no ".tbl-path:has-text('/writing/rolled')"

  Scenario: The analytics screen ranks the pages, referrers and countries
    Given these analytics_rollups rows:
      | day   | views | visitors | read_seconds |
      | today | 12    | 8        | 600          |
    And these analytics_rollup_paths rows:
      | day   | path           | title | views | visitors | read_seconds | bounces |
      | today | /writing/hello | Hello | 8     | 6        | 480          | 3       |
    And these analytics_rollup_referrers rows:
      | day   | host         | views | visitors |
      | today | news.example | 7     | 2        |
      | today | none         | 5     | 5        |
    And these analytics_rollup_countries rows:
      | day   | country_code | country_name  | views | visitors |
      | today | US           | United States | 9     | 3        |
      | today | none         | none          | 3     | 3        |
      | today | DE           | none          | 1     | 1        |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen part ".page-head-sub" mentions "12 views"
    And the screen part ".tbl-page" mentions "Hello"
    And the screen part ".tbl-path" reads "/writing/hello"
    And the screen parts "tbody .tbl-c.num" read:
      | 8    |
      | 1:00 |
      | 50%  |
    And the screen parts ".card:has(:text-is('Referrers')) .meter-name" read:
      | direct       |
      | news.example |
    And the screen parts ".card:has(:text-is('Referrers')) .meter-count" read:
      | 5 |
      | 2 |
    And the screen parts ".card:has(:text-is('Referrers')) .meter-fill" are styled:
      | width: 100% |
      | width: 40%  |
    And the screen parts ".card:has(:text-is('Geography')) .meter-name" read:
      | United States |
      | unknown       |
      | DE            |
    And the screen parts ".card:has(:text-is('Geography')) .meter-count" read:
      | 3 |
      | 3 |
      | 1 |
    And the screen holds ".card:has(:text-is('Referrers')) .meter.blue"
    And the screen holds ".card:has(:text-is('Geography')) .meter.violet"

  Scenario: The analytics screen lists the top 10 of each list
    Given these analytics_rollups rows:
      | day   | views | visitors | read_seconds |
      | today | 500   | 300      | 0            |
    And these analytics_rollup_paths rows:
      | day   | path            | views | visitors | bounces |
      | today | /writing/post-0 | 1     | 1        | 0       |
      | today | /writing/post-1 | 2     | 1        | 0       |
      | today | /writing/post-2 | 3     | 1        | 0       |
      | today | /writing/post-3 | 4     | 1        | 0       |
      | today | /writing/post-4 | 5     | 1        | 0       |
      | today | /writing/post-5 | 6     | 1        | 0       |
      | today | /writing/post-6 | 7     | 1        | 0       |
      | today | /writing/post-7 | 8     | 1        | 0       |
      | today | /writing/post-8 | 9     | 1        | 0       |
      | today | /writing/post-9 | 10    | 1        | 0       |
      | today | /writing/post-10| 11    | 1        | 0       |
    And these analytics_rollup_referrers rows:
      | day   | host            | views | visitors |
      | today | site-0.example  | 30    | 1        |
      | today | site-1.example  | 29    | 2        |
      | today | site-2.example  | 28    | 3        |
      | today | site-3.example  | 27    | 4        |
      | today | site-4.example  | 26    | 5        |
      | today | site-5.example  | 25    | 6        |
      | today | site-6.example  | 24    | 7        |
      | today | site-7.example  | 23    | 8        |
      | today | site-8.example  | 22    | 9        |
      | today | site-9.example  | 21    | 10       |
      | today | site-10.example | 20    | 11       |
    And these analytics_rollup_countries rows:
      | day   | country_code | views | visitors |
      | today | AU           | 30    | 1        |
      | today | BR           | 29    | 2        |
      | today | CA           | 28    | 3        |
      | today | DE           | 27    | 4        |
      | today | ES           | 26    | 5        |
      | today | FR           | 25    | 6        |
      | today | GB           | 24    | 7        |
      | today | IN           | 23    | 8        |
      | today | JP           | 22    | 9        |
      | today | MX           | 21    | 10       |
      | today | US           | 20    | 11       |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen parts ".tbl-path" read:
      | /writing/post-10 |
      | /writing/post-9  |
      | /writing/post-8  |
      | /writing/post-7  |
      | /writing/post-6  |
      | /writing/post-5  |
      | /writing/post-4  |
      | /writing/post-3  |
      | /writing/post-2  |
      | /writing/post-1  |
    And the screen parts ".card:has(:text-is('Referrers')) .meter-name" read:
      | site-10.example |
      | site-9.example  |
      | site-8.example  |
      | site-7.example  |
      | site-6.example  |
      | site-5.example  |
      | site-4.example  |
      | site-3.example  |
      | site-2.example  |
      | site-1.example  |
    And the screen parts ".card:has(:text-is('Geography')) .meter-name" read:
      | US |
      | MX |
      | JP |
      | IN |
      | GB |
      | FR |
      | ES |
      | DE |
      | CA |
      | BR |

  Scenario: The analytics screen ranks a referrer with no counted day last
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today-5 | 20    | 10       | 0            |
      | today-1 | 20    | 10       | 0            |
    And these analytics_rollup_referrers rows:
      | day     | host         | views | visitors |
      | today-5 | news.example | 6     | none     |
      | today-1 | news.example | 2     | 1        |
      | today-5 | old.example  | 9     | none     |
    And these analytics_rollup_countries rows:
      | day     | country_code | views | visitors |
      | today-5 | DE           | 4     | none     |
    And these analytics_events rows:
      | referrer_host | country_code |
      | news.example  | US           |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen parts ".card:has(:text-is('Referrers')) .meter-name" read:
      | news.example |
      | old.example  |
    And the screen parts ".card:has(:text-is('Referrers')) .meter-count" read:
      | 2 |
      |   |
    And the screen parts ".card:has(:text-is('Geography')) .meter-fill" are styled:
      | width: 100% |
      | width: 0%   |

  Scenario: The analytics screen counts readers by weekday and hour in Chicago time
    Given these analytics_events rows:
      | occurred_at     | times |
      | sunday 23:30    | 2     |
      | sunday+1 09:00  | 1     |
      | today-95 09:00  | 1     |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen holds 7 of "table.heat tbody tr"
    And the screen holds 168 of "table.heat tbody .heat-cell"
    And the screen parts "table.heat tbody .heat-day" read:
      | Mon |
      | Tue |
      | Wed |
      | Thu |
      | Fri |
      | Sat |
      | Sun |
    And the screen holds 24 of "table.heat thead .heat-hour"
    And the screen part "table.heat thead .heat-hour >> nth=0" reads "00"
    And the screen part "table.heat thead .heat-hour >> nth=23" reads "23"
    And the screen holds ".card:has(:text-is('Readers by hour')) .card-note:text-is('last 90 days · Chicago time')"
    And the screen part "table.heat tbody tr >> nth=6 >> .heat-cell >> nth=23 >> .sr-only" reads "2 readers"
    And the screen part "table.heat tbody tr >> nth=0 >> .heat-cell >> nth=9 >> .sr-only" reads "1 reader"
    And the screen part "table.heat tbody tr >> nth=0 >> .heat-cell >> nth=0 >> .sr-only" reads "0 readers"
    And the screen parts "table.heat .heat-cell .sr-only" add up to 3
    And the screen part "table.heat tbody tr >> nth=6 >> .heat-cell >> nth=23" has "style" set to "--heat: 100%"
    And the screen part "table.heat tbody tr >> nth=0 >> .heat-cell >> nth=9" has "style" set to "--heat: 50%"
    And the screen part "table.heat tbody tr >> nth=0 >> .heat-cell >> nth=0" has "style" set to "--heat: 0%"

  Scenario: The analytics screen adds up the feed subscribers each day
    Given these feed_subscribers rows:
      | day     | path                    | aggregator | subscribers |
      | today   | /writing.atom           | feedly     | 40          |
      | today   | /writing/tags/ruby.atom | feedly     | 2           |
      | today-1 | /writing.atom           | inoreader  | 9           |
      | today-1 | /writing.atom           | feedly     | 30          |
      | today-1 | /writing/tags/ruby.atom | feedly     | 2           |
      | today-2 | /writing.atom           | feedly     | 38          |
      | today-2 | /writing.atom           | newsblur   | 5           |
    And these feed_readers rows:
      | day     | path                    | readers |
      | today   | /writing.atom           | 3       |
      | today   | /writing/tags/ruby.atom | 1       |
      | today-1 | /writing.atom           | 5       |
      | today-2 | /writing.atom           | 2       |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen rows ".card:has(:text-is('Feed subscribers')) tbody tr" read:
      | {today-6 short} | 0  |
      | {today-5 short} | 0  |
      | {today-4 short} | 0  |
      | {today-3 short} | 0  |
      | {today-2 short} | 45 |
      | {today-1 short} | 46 |
      | {today short}   | 46 |
    And the screen holds ".card:has(:text-is('Feed subscribers')) .card-note:text-is('latest 46')"
    And the screen part ".card:has(:text-is('Feed subscribers')) polyline" draws 7 points
    And the screen parts ".card:has(:text-is('Feed subscribers')) .feed-aggregators .meter-name" read:
      | feedly         |
      | inoreader      |
      | direct readers |
    And the screen parts ".card:has(:text-is('Feed subscribers')) .feed-aggregators .meter-count" read:
      | 32 |
      | 9  |
      | 5  |

  Scenario: The analytics screen reads yesterday's feed count before today's fetch
    Given these feed_subscribers rows:
      | day     | aggregator | subscribers |
      | today-1 | feedly     | 40          |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen holds ".card:has(:text-is('Feed subscribers')) .card-note:text-is('latest 40')"
    And the screen parts ".card:has(:text-is('Feed subscribers')) .meter-name" read:
      | feedly |

  Scenario: The analytics screen counts the webmentions per post
    Given these analytics posts:
      | title | published |
      | Hello | today-30  |
      | Other | today-30  |
      | Older | today-30  |
    And these webmentions rows:
      | post  | received_at   | status   | times |
      | Hello | today 00:00   | pending  | 3     |
      | Other | today-1 00:00 | approved | 1     |
      | Older | today-8 00:00 | approved | 1     |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen holds ".card:has(:text-is('Webmentions per post')) .card-note:text-is('4 received · 3 pending')"
    And the screen parts ".card:has(:text-is('Webmentions per post')) .meter-name" read:
      | Hello |
      | Other |
    And the screen parts ".card:has(:text-is('Webmentions per post')) .meter-count" read:
      | 3 |
      | 1 |
    And the screen holds ".card:has(:text-is('Webmentions per post')) .meter.pink"

  Scenario: The analytics screen counts one pending mention in the singular
    Given these analytics posts:
      | title | published |
      | Hello | today-30  |
    And these webmentions rows:
      | post  | received_at |
      | Hello | now         |
    When I visit "/admin/analytics" in the admin
    Then the screen holds ".card:has(:text-is('Webmentions per post')) .card-note:text-is('1 received · 1 pending')"

  Scenario: The analytics screen counts an ignored webmention as received
    Given these analytics posts:
      | title | published |
      | Hello | today-30  |
    And these webmentions rows:
      | post  | received_at | status   |
      | Hello | today 00:00 | approved |
      | Hello | today 00:00 | ignored  |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen part ".card:has(:text-is('Webmentions per post')) .card-note" mentions "2 received"
    And the screen parts ".card:has(:text-is('Webmentions per post')) .meter-count" read:
      | 2 |

  Scenario: The analytics screen lists as many mentioned posts as the other side cards
    Given these analytics posts:
      | title   | published |
      | Post 0  | today-30  |
      | Post 1  | today-30  |
      | Post 2  | today-30  |
      | Post 3  | today-30  |
      | Post 4  | today-30  |
      | Post 5  | today-30  |
      | Post 6  | today-30  |
      | Post 7  | today-30  |
      | Post 8  | today-30  |
      | Post 9  | today-30  |
      | Post 10 | today-30  |
    And these webmentions rows:
      | post    | received_at |
      | Post 0  | now         |
      | Post 1  | now         |
      | Post 2  | now         |
      | Post 3  | now         |
      | Post 4  | now         |
      | Post 5  | now         |
      | Post 6  | now         |
      | Post 7  | now         |
      | Post 8  | now         |
      | Post 9  | now         |
      | Post 10 | now         |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen holds 10 of ".card:has(:text-is('Webmentions per post')) .meter-name"

  Scenario: The analytics screen links a top page that is a post to its analytics
    Given these analytics posts:
      | title | slug  | published |
      | Hello | hello | today-30  |
    And these analytics_rollups rows:
      | day   | views | visitors |
      | today | 12    | 6        |
    And these analytics_rollup_paths rows:
      | day   | path           | title | views | visitors | bounces |
      | today | /writing/hello | Hello | 6     | 3        | 0       |
      | today | /about         | About | 6     | 3        | 0       |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen holds "a[href='/admin/posts/1/analytics']:has-text('Hello')"
    And the screen holds no "a:text-is('About')"

  Scenario: The analytics screen shares out how far the views reached
    Given these analytics_rollups rows:
      | day   | views | visitors |
      | today | 4     | 4        |
    And these analytics_rollup_scroll_depths rows:
      | day   | path           | scroll_depth | views | visitors |
      | today | /writing/hello | 100          | 1     | 1        |
      | today | /writing/other | 25           | 3     | 3        |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen parts ".card:has(:text-is('Scroll depth')) .meter-count" read:
      | 100% |
      | 25%  |
      | 25%  |
      | 25%  |

  Scenario: The analytics screen counts today's scroll depths from the visits
    Given these analytics_events rows:
      | path           | scroll_depth |
      | /writing/hello | 75           |
      | /writing/other | 25           |
    When I visit "/admin/analytics?range=7" in the admin
    Then the screen parts ".card:has(:text-is('Scroll depth')) .meter-count" read:
      | 100% |
      | 50%  |
      | 50%  |
      | 0%   |

  Scenario: The analytics screen with no data draws zeros and empty cards
    When I visit "/admin/analytics" in the admin
    Then the screen part ".page-head-sub" mentions "0 views from 0 visitors"
    And the screen part ".page-head-sub" mentions "0:00 average read"
    And the screen holds 30 of ".chart-bar"
    And the screen holds 30 of ".chart-bar[style='height: 0%']"
    And the screen holds ".card:has(:text-is('Feed subscribers')) .card-note:text-is('latest 0')"
    And the screen holds ".empty:text-is('No page views yet.')"
    And the screen holds ".empty:text-is('No referrers yet.')"
    And the screen holds ".empty:text-is('No countries yet.')"
    And the screen holds ".empty:text-is('No mentions yet.')"
    And the screen holds ".empty:text-is('No aggregator counts yet.')"
    And the screen holds ".empty:text-is('No scroll depth yet.')"
