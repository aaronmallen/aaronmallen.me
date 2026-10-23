Feature: The nightly timing roll up
  Each night the timing roll up writes p50, p95 and counts for every finished
  day and deletes raw timing rows older than 30 days.

  Scenario: The timing roll up writes the figures of each route and verb
    Given these performance_requests rows:
      | route    | verb | duration | query_count | query_time | occurred_at   |
      | /writing | GET  | 1.0      | 2           | 0.25       | today-1 12:00 |
      | /writing | GET  | 2.0      | 2           | 0.25       | today-1 12:00 |
      | /writing | GET  | 3.0      | 2           | 0.25       | today-1 12:00 |
      | /writing | GET  | 4.0      | 2           | 0.25       | today-1 12:00 |
      | /writing | POST | 9.0      | 2           | 0.25       | today-1 12:00 |
      | none     | GET  | 1.0      | 2           | 0.25       | today-1 12:00 |
    When the job "Performance::Jobs::RollUpTiming" runs
    Then the performance_rollup_requests rows where "day = '{today-1}'" are:
      | route    | verb | count | p50 | p95  | query_count | query_time |
      | /writing | GET  | 4     | 2.5 | 3.85 | 8           | 1          |
      | /writing | POST | 1     | 9   | 9    | 2           | 0.25       |
      | none     | GET  | 1     | 1   | 1    | 2           | 0.25       |

  Scenario: The timing roll up writes the figures of each job class
    Given these performance_jobs rows:
      | job       | duration | query_count | query_time | occurred_at   |
      | Spec::Job | 1.0      | 1           | 0.5        | today-1 12:00 |
      | Spec::Job | 3.0      | 1           | 0.5        | today-1 12:00 |
    When the job "Performance::Jobs::RollUpTiming" runs
    Then the performance_rollup_jobs rows where "day = '{today-1}'" are:
      | job       | count | p50 | p95 | query_count | query_time |
      | Spec::Job | 2     | 2   | 2.9 | 2           | 1          |

  Scenario: The timing roll up writes each browser metric and skips a missing LCP
    Given these performance_pages rows:
      | route | ttfb | dom_content_loaded | load | lcp  | occurred_at   |
      | /     | 0.1  | 0.2                | 1.0  | 0.5  | today-1 12:00 |
      | /     | 0.1  | 0.2                | 3.0  | none | today-1 12:00 |
    When the job "Performance::Jobs::RollUpTiming" runs
    Then the performance_rollup_pages rows where "day = '{today-1}'" are:
      | route | metric             | count | p50 | p95 |
      | /     | ttfb               | 2     | 0.1 | 0.1 |
      | /     | dom_content_loaded | 2     | 0.2 | 0.2 |
      | /     | load               | 2     | 2   | 2.9 |
      | /     | lcp                | 1     | 0.5 | 0.5 |

  Scenario: The timing roll up rolls up every finished day and leaves today alone
    Given these performance_requests rows:
      | route    | duration | query_time | occurred_at   |
      | /writing | 1.0      | 0.25       | today-3 12:00 |
    When the job "Performance::Jobs::RollUpTiming" runs
    Then the performance_rollups rows are:
      | day     |
      | today-3 |
      | today-2 |
      | today-1 |

  Scenario: The timing roll up leaves the same rollup when it runs twice for a day
    Given these performance_requests rows:
      | route    | duration | query_time | occurred_at   |
      | /writing | 1.0      | 0.25       | today-1 12:00 |
    And these performance_jobs rows:
      | duration | occurred_at   |
      | 1.0      | today-1 12:00 |
    And these performance_pages rows:
      | ttfb | dom_content_loaded | load | occurred_at   |
      | 0.1  | 0.2                | 1.0  | today-1 12:00 |
    When the job "Performance::Jobs::RollUpTiming" runs 2 times
    Then the performance_rollup_requests rows where "day = '{today-1}'" are:
      | route    | count | p50 |
      | /writing | 1     | 1   |
    And the performance_rollup_jobs rows where "day = '{today-1}'" are:
      | job       | count |
      | Spec::Job | 1     |
    And the performance_rollup_pages rows where "day = '{today-1}' AND metric = 'load'" are:
      | count | p50 |
      | 1     | 1   |

  Scenario: The timing roll up deletes raw rows older than 30 days and keeps their rollups
    Given these performance_requests rows:
      | route    | duration | query_time | occurred_at    |
      | /old     | 1.0      | 0.25       | today-30 12:00 |
      | /kept    | 2.0      | 0.25       | today-29 12:00 |
    And these performance_jobs rows:
      | duration | occurred_at    |
      | 1.0      | today-30 12:00 |
    And these performance_pages rows:
      | ttfb | dom_content_loaded | load | occurred_at    |
      | 0.1  | 0.2                | 1.0  | today-30 12:00 |
    When the job "Performance::Jobs::RollUpTiming" runs
    Then the performance_requests table holds 1 rows where "route LIKE '/%' AND occurred_at < now() - interval '1 day'"
    And the performance_jobs table holds 0 rows where "job = 'Spec::Job'"
    And the performance_pages table holds 0 rows
    And the performance_rollup_requests table holds 1 rows where "day = '{today-30}'"
    And the performance_rollup_jobs table holds 1 rows where "day = '{today-30}'"
    And the performance_rollup_pages table holds 3 rows where "day = '{today-30}'"
