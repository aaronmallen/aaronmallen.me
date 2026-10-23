Feature: The performance screen
  The owner reads how long the site's routes and jobs take, over the last 7, 14
  or 30 days, from timings kept on this server.

  Background:
    Given I am signed in to the admin
    And the timing rows of the sign in are cleared

  Scenario: The performance screen sits under Insights as part of analytics
    When I visit "/admin/performance" in the admin
    Then the page title is "Performance | Admin | Aaron Allen"
    And the screen holds "a.pill-nav-link[aria-current='page']:has-text('Insights')"
    And the screen holds ".screen-tab[aria-current='page']:text-is('analytics')"
    And the screen parts "a.screen-tab" read:
      | analytics   |
      | activity    |
      | health      |
      | time report |
    And the screen holds ".card:has(:text-is('Routes')) .empty"
    And the screen holds ".card:has(:text-is('Jobs')) .empty"
    And the page has no axe breaches in light or dark

  Scenario: The analytics screen opens the performance screen from its tab row
    When I visit "/admin/analytics?range=14" in the admin
    Then the screen part ".perf-tabs-list a:text-is('Traffic')" has "aria-current" set to "page"
    And the screen part ".perf-tabs-list a:text-is('Performance')" has "href" set to "/admin/performance?range=14"

  Scenario: The command palette finds the performance screen through analytics
    When I visit "/admin" in the admin
    Then the screen holds no "[data-palette-href='/admin/performance']"
    And the screen part "#command-palette-analytics" has "data-palette-text" holding "performance"

  Scenario: The performance screen lists the routes by p95
    Given these performance_requests rows:
      | route          | duration | query_count | query_time | occurred_at |
      | /writing/:slug | 100      | 2           | 10         | today 12:00 |
      | /writing/:slug | 200      | 2           | 20         | today 12:00 |
      | /writing/:slug | 300      | 2           | 30         | today 12:00 |
      | /writing/:slug | 400      | 2           | 40         | today 12:00 |
      | /admin/tasks   | 1000     | 5           | 100        | today 12:00 |
    When I visit "/admin/performance" in the admin
    Then the screen rows ".card:has(:text-is('Routes')) tbody tr" start with:
      | GET /admin/tasks   |  | 1,000 ms | 1,000 ms | 1 | 5.0 | 100 ms |
      | GET /writing/:slug |  | 250 ms   | 385 ms   | 4 | 2.0 | 25 ms  |
    And the screen part ".card:has(:text-is('Routes')) .card-side" reads "2 routes · slowest p95 first"

  Scenario: The performance screen draws each route's spread to the slowest p95
    Given these performance_requests rows:
      | route          | duration | query_time | occurred_at |
      | /admin/tasks   | 1000     | 100        | today 12:00 |
      | /writing/:slug | 250      | 25         | today 12:00 |
    When I visit "/admin/performance" in the admin
    Then the screen parts ".card:has(:text-is('Routes')) tbody tr .perf-spread i" are styled:
      | width: 100% |
      | width: 100% |
      | width: 50%  |
      | width: 50%  |

  Scenario: The performance screen heads the page and groups the route columns
    Given these performance_requests rows:
      | duration | query_time | occurred_at |
      | 100      | 10         | today 12:00 |
    When I visit "/admin/performance?range=14" in the admin
    Then the screen part ".page-head-sub" reads "Routes and jobs over the last 14 days. Timings stay on this server."
    And the screen holds 1 of ".card:has(:text-is('Routes')) tbody tr"
    And the screen parts ".card:has(:text-is('Routes')) thead tr >> nth=0 >> th" read:
      | Server             |
      | Browser · GET only |
    And the screen part ".card:has(:text-is('Routes')) thead tr >> nth=0 >> th >> nth=0" has "colspan" set to "6"
    And the screen part ".card:has(:text-is('Routes')) thead tr >> nth=0 >> th >> nth=1" has "colspan" set to "4"
    And the screen holds ".card:has(:text-is('Routes')) th.perf-key-col:text-is('p95')"

  Scenario: The performance screen lists the jobs by p95
    Given these performance_jobs rows:
      | job        | duration | occurred_at |
      | Quick::Job | 50       | today 12:00 |
      | Spec::Job  | 100      | today 12:00 |
      | Spec::Job  | 300      | today 12:00 |
    When I visit "/admin/performance" in the admin
    Then the screen rows ".card:has(:text-is('Jobs')) tbody tr" read:
      | Spec::Job  |  | 200 ms | 290 ms | 2 | 3.0 | 2 ms |
      | Quick::Job |  | 50 ms  | 50 ms  | 1 | 3.0 | 2 ms |
    And the screen part ".card:has(:text-is('Jobs')) .card-side" reads "Sidekiq · 2 classes"

  Scenario: The performance screen anchors each job's row for the cron schedule
    Given these performance_jobs rows:
      | job                           | duration | occurred_at |
      | Backups::Jobs::BackUpDatabase | 100      | today 12:00 |
    When I visit "/admin/performance" in the admin
    Then the screen holds ".card:has(:text-is('Jobs')) tbody tr#job-backups-jobs-backupdatabase"

  Scenario: The performance screen shows a route's browser load and LCP
    Given these performance_requests rows:
      | duration | query_time | occurred_at |
      | 100      | 10         | today 12:00 |
    And these performance_pages rows:
      | route          | load | lcp | occurred_at |
      | /writing/:slug | 900  | 450 | today 12:00 |
      | /writing/:slug | 1100 | 550 | today 12:00 |
    When I visit "/admin/performance" in the admin
    Then the screen rows ".card:has(:text-is('Routes')) tbody tr" end with:
      | 1,000 ms | 1,090 ms | 500 ms | 545 ms |

  Scenario: The performance screen shows no browser figures for a route the browser never timed
    Given these performance_requests rows:
      | route     | duration | query_time | occurred_at |
      | /feed.xml | 100      | 10         | today 12:00 |
    And these performance_pages rows:
      | route          | load | occurred_at |
      | /writing/:slug | 900  | today 12:00 |
    When I visit "/admin/performance" in the admin
    Then the screen rows ".card:has(:text-is('Routes')) tbody tr" end with:
      | none | none | none | none |

  Scenario: The performance screen hatches the browser cells of a route that is not a GET
    Given these performance_requests rows:
      | verb | duration | query_time | occurred_at |
      | POST | 100      | 10         | today 12:00 |
    And these performance_pages rows:
      | route          | load | occurred_at |
      | /writing/:slug | 900  | today 12:00 |
    When I visit "/admin/performance" in the admin
    Then the screen part ".card:has(:text-is('Routes')) tbody tr td.perf-na[colspan='4']" reads "GET only"

  Scenario: The performance tab row keeps the range
    When I visit "/admin/performance?range=7" in the admin
    Then the screen part ".perf-tabs-list a:text-is('Traffic')" has "href" set to "/admin/analytics?range=7"
    And the screen part ".perf-tabs-list a:text-is('Performance')" has "aria-current" set to "page"
    And the screen holds ".perf-tabs input[name='range'][value='7'][checked]"

  Scenario: The performance tab row keeps the route on a route's requests
    When I visit "/admin/performance/requests?route=/writing/:slug&verb=GET&range=7" in the admin
    Then the screen part ".perf-tabs-list a:text-is('Performance')" has "aria-current" set to "true"
    And the screen part ".perf-tabs form" has "action" set to "/admin/performance/requests"
    And the screen part ".perf-tabs input[type='hidden'][name='route']" has "value" set to "/writing/:slug"
    And the screen part ".perf-tabs input[type='hidden'][name='verb']" has "value" set to "GET"
    And the screen holds ".screen-tab[aria-current='page']:text-is('analytics')"
    And the page has no axe breaches in light or dark

  Scenario: The performance screen charts the server time per day
    Given these performance_requests rows:
      | route          | duration | query_time | occurred_at   |
      | /writing/:slug | 100      | 10         | today 12:00   |
      | /writing/:slug | 300      | 30         | today 12:00   |
      | /admin/tasks   | 1000     | 100        | today-6 12:00 |
    When I visit "/admin/performance?range=7" in the admin
    Then the screen holds 7 of ".perf-col"
    And the screen holds 2 of ".perf-col .perf-bar"
    And the screen parts ".perf-col .perf-bar" are styled:
      | height: 100% |
      | height: 29%  |
    And the screen parts ".perf-col .perf-bar .perf-fill-50" are styled:
      | height: 100% |
      | height: 69%  |
    And the screen part ".perf-col .chart-tip >> nth=-1" reads "{today short} · p50 200 ms · p95 290 ms · 2 requests"
    And the screen part ".perf-col .chart-tip >> nth=1" reads "{today-5 short} · 0 requests"
    And the screen part ".perf-chart[role='img']" has "aria-label" set to "Server time per day: p95 peaked at 1,000 ms on {today-6 short}"
    And the screen part ".perf-median" reads "median day 1,000 ms"
    And the screen parts ".perf-chart-y span" read:
      | 1,000 ms |
      | 500      |
      | 0        |
    And the screen parts ".perf-chart-dates span" read:
      | {today-6 short} |
      | {today-3 short} |
      | {today short}   |

  Scenario: The performance screen weighs a rolled up day with today's raw rows
    Given these performance_requests rows:
      | route          | duration | query_time | occurred_at   |
      | /writing/:slug | 10       | 1          | today-1 12:00 |
      | /writing/:slug | 10       | 1          | today-1 12:00 |
      | /writing/:slug | 10       | 1          | today-1 12:00 |
    And these performance_jobs rows:
      | duration | occurred_at   |
      | 100      | today-1 12:00 |
    And these performance_pages rows:
      | route          | load | lcp | occurred_at   |
      | /writing/:slug | 900  | 400 | today-1 12:00 |
    And the job "Performance::Jobs::RollUpTiming" runs
    And the raw timing rows are deleted
    And these performance_requests rows:
      | route          | duration | query_time | occurred_at |
      | /writing/:slug | 50       | 5          | today 12:00 |
    When I visit "/admin/performance?range=7" in the admin
    Then the screen rows ".card:has(:text-is('Routes')) tbody tr" read:
      | GET /writing/:slug |  | 20 ms | 20 ms | 4 | 2.0 | 2 ms | 900 ms | 900 ms | 400 ms | 400 ms |
    And the screen rows ".card:has(:text-is('Jobs')) tbody tr" read:
      | Spec::Job |  | 100 ms | 100 ms | 1 | 3.0 | 2 ms |
    And the screen part ".perf-col .chart-tip >> nth=-2" reads "{today-1 short} · p50 10 ms · p95 10 ms · 3 requests"

  Scenario: The performance screen counts a rolled day once while its raw rows remain
    Given these performance_requests rows:
      | route          | duration | query_time | occurred_at   |
      | /writing/:slug | 100      | 10         | today-1 12:00 |
      | /writing/:slug | 200      | 20         | today-1 12:00 |
      | /writing/:slug | 300      | 30         | today-1 12:00 |
      | /writing/:slug | 400      | 40         | today-1 12:00 |
    And the job "Performance::Jobs::RollUpTiming" runs
    And these performance_requests rows:
      | route          | duration | query_time | occurred_at |
      | /writing/:slug | 1000     | 100        | today 12:00 |
      | /admin/tasks   | 1000     | 100        | today 12:00 |
    And an API token with the scopes "read"
    When I get "/performance?from={today-6}&to={today}" from the API
    And I visit "/admin/performance?range=7" in the admin
    Then the screen rows ".card:has(:text-is('Routes')) tbody tr >> nth=1" start with:
      | GET /writing/:slug |  | 400 ms | 508 ms | 5 |
    And the answer holds:
      """
      {"routes": [{"route": "/admin/tasks"}, {"route": "/writing/:slug", "verb": "GET", "count": 5, "p50": 400.0}]}
      """

  Scenario: The performance screen leaves out raw rows from days before the newest rollup
    Given these performance_requests rows:
      | route          | duration | query_time | occurred_at   |
      | /writing/:slug | 10       | 1          | today-1 12:00 |
    And the job "Performance::Jobs::RollUpTiming" runs
    And these performance_requests rows:
      | route        | duration | query_time | occurred_at   |
      | /admin/tasks | 5000     | 500        | today-3 12:00 |
    When I visit "/admin/performance?range=7" in the admin
    Then the screen rows ".card:has(:text-is('Routes')) tbody tr" start with:
      | GET /writing/:slug |

  Scenario: The performance screen keeps to the chosen range
    Given these performance_requests rows:
      | duration | query_time | occurred_at    |
      | 100      | 10         | today-10 12:00 |
    And these performance_jobs rows:
      | duration | occurred_at    |
      | 100      | today-10 12:00 |
    When I visit "/admin/performance?range=7" in the admin
    Then the screen holds "input[name='range'][value='7']:checked"
    And the screen holds 3 of ".card .empty"
    When I visit "/admin/performance?range=14" in the admin
    Then the screen holds 1 of ".card:has(:text-is('Routes')) tbody tr:has-text('/writing/:slug')"

  Scenario: The owner opens a route's slowest requests
    Given these performance_requests rows:
      | route          | duration | query_time | occurred_at    |
      | /writing/:slug | 100      | 10         | today 12:00    |
      | /writing/:slug | 700      | 70         | today 12:00    |
      | /writing/:slug | 300      | 30         | today 12:00    |
      | /admin/tasks   | 5000     | 500        | today 12:00    |
      | /writing/:slug | 9000     | 900        | today-10 12:00 |
    When I visit "/admin/performance?range=7" in the admin
    And I follow the link "GET /writing/:slug"
    Then the screen part ".page-head h1 .perf-verb" reads "GET"
    And the screen part ".page-head h1 .perf-path" reads "/writing/:slug"
    And the screen part ".page-head-sub" reads "The slowest requests in the last 7 days."
    And the screen part ".card:has(:text-is('This route per day')) .card-side" mentions "3 requests"
    And the screen holds 1 of ".perf-col .perf-bar"
    And the screen part ".card:has(:text-is('Slowest requests')) .card-side" reads "3 of 3"
    And the screen parts ".card:has(:text-is('Slowest requests')) tbody tr .perf-time-bar i" are styled:
      | width: 100% |
      | width: 43%  |
      | width: 14%  |
    And the screen rows ".card:has(:text-is('Slowest requests')) tbody tr" end with:
      | 200 | 700 ms | 2 | 70 ms |
      | 200 | 300 ms | 2 | 30 ms |
      | 200 | 100 ms | 2 | 10 ms |
    And the screen holds "a[href='/admin/performance?range=7']:has-text('All routes')"
    And the page has no axe breaches in light or dark

  Scenario: The owner opens the requests no route served
    Given these performance_requests rows:
      | route | status | duration | query_time | occurred_at |
      | none  | 404    | 40       | 4          | today 12:00 |
    When I visit "/admin/performance" in the admin
    And I follow the link "GET no route"
    Then the screen rows ".card:has(:text-is('Slowest requests')) tbody tr >> nth=0" end with:
      | 404 | 40 ms | 2 | 4 ms |

  Scenario: The slowest requests mark a server error
    Given these performance_requests rows:
      | status | duration | query_time | occurred_at |
      | 503    | 900      | 90         | today 12:00 |
      | 200    | 100      | 10         | today 12:00 |
    When I visit "/admin/performance/requests?route=/writing/:slug&verb=GET" in the admin
    Then the screen holds ".perf-status.bad:text-is('503')"
    And the screen holds ".perf-status:not(.bad):text-is('200')"
