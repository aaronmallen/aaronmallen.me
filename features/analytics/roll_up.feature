Feature: The nightly analytics roll up
  Each night the roll up sums each finished day's raw visits into rollup rows,
  counts each month's reach, saves the reader counts of posts past their first
  year and prunes raw visits older than 90 days once their day is summed.

  Scenario: The roll up stores yesterday's totals
    Given these analytics_events rows:
      | occurred_at   | visitor | read_seconds |
      | today-1 12:00 | ann     | 90           |
      | today-1 12:00 | ann     | 30           |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollups rows where "day = '{today-1}'" are:
      | views | visitors | read_seconds |
      | 2     | 1        | 120          |

  Scenario: The roll up stores each path with the title of its latest titled view
    Given these analytics_events rows:
      | path           | title | occurred_at   | read_seconds |
      | /writing/hello | Old   | today-1 12:00 | 90           |
      | /writing/hello | New   | today-1 12:01 | 42           |
      | /writing/hello | none  | today-1 12:02 | 42           |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_paths rows where "day = '{today-1}'" are:
      | path           | title | views | visitors | read_seconds | bounces |
      | /writing/hello | New   | 3     | 3        | 174          | 3       |

  Scenario: The roll up counts no bounce for a visitor who read a second page
    Given these analytics_events rows:
      | path           | visitor | occurred_at   |
      | /writing/hello | ann     | today-1 12:00 |
      | /writing/other | ann     | today-1 12:30 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_paths rows where "day = '{today-1}'" are:
      | path           | bounces |
      | /writing/hello | 0       |
      | /writing/other | 0       |

  Scenario: The roll up stores the referrers and countries with each one's distinct visitors
    Given these analytics_events rows:
      | visitor | referrer_host | country_code | occurred_at   | times |
      | ann     | news.example  | JP           | today-1 12:00 | 2     |
      |         | news.example  | JP           | today-1 12:00 | 1     |
      | ann     | none          | none         | today-1 12:00 | 1     |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_referrers rows where "day = '{today-1}'" are:
      | host         | views | visitors |
      | news.example | 3     | 2        |
      | none         | 1     | 1        |
    And the analytics_rollup_countries rows where "day = '{today-1}'" are:
      | country_code | views | visitors |
      | JP           | 3     | 2        |
      | none         | 1     | 1        |

  Scenario: The roll up counts a visitor who came from two hosts once under each
    Given these analytics_events rows:
      | visitor | referrer_host | occurred_at   | times |
      | ann     | news.example  | today-1 12:00 | 1     |
      | ann     | blog.example  | today-1 12:00 | 2     |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_referrers rows where "day = '{today-1}'" are:
      | host         | visitors |
      | blog.example | 1        |
      | news.example | 1        |

  Scenario: The roll up stores the sources of the site and of each page
    Given these analytics_events rows:
      | path           | source | visitor | occurred_at   |
      | /writing/hello | reddit | ann     | today-1 12:00 |
      | /writing/other | reddit | ann     | today-1 12:00 |
      | /writing/other | feed   |         | today-1 12:00 |
      | /writing/other |        |         | today-1 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_sources rows where "day = '{today-1}'" are:
      | path           | source | views | visitors |
      | none           | feed   | 1     | 1        |
      | none           | reddit | 2     | 1        |
      | /writing/hello | reddit | 1     | 1        |
      | /writing/other | feed   | 1     | 1        |
      | /writing/other | reddit | 1     | 1        |

  Scenario: The roll up stores each page's referrers and countries apart
    Given these analytics_events rows:
      | path           | referrer_host | country_code | visitor | occurred_at   | times |
      | /writing/hello | news.example  | JP           | ann     | today-1 12:00 | 2     |
      | /writing/hello | news.example  | US           |         | today-1 12:00 | 1     |
      | /writing/hello | none          | none         |         | today-1 12:00 | 1     |
      | /writing/other | news.example  | JP           | ann     | today-1 12:00 | 1     |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_page_referrers rows where "day = '{today-1}'" are:
      | path           | host         | views | visitors |
      | /writing/hello | news.example | 3     | 2        |
      | /writing/hello | none         | 1     | 1        |
      | /writing/other | news.example | 1     | 1        |
    And the analytics_rollup_page_countries rows where "day = '{today-1}'" are:
      | path           | country_code | views | visitors |
      | /writing/hello | JP           | 2     | 1        |
      | /writing/hello | US           | 1     | 1        |
      | /writing/hello | none         | 1     | 1        |
      | /writing/other | JP           | 1     | 1        |

  Scenario: The roll up stores each page's views at each deepest scroll depth
    Given these analytics_events rows:
      | path           | scroll_depth | visitor | occurred_at   |
      | /writing/hello | 0            | ann     | today-1 12:00 |
      | /writing/hello | 50           | ann     | today-1 12:00 |
      | /writing/hello | 100          | ann     | today-1 12:00 |
      | /writing/hello | 100          |         | today-1 12:00 |
      | /writing/other | 50           | ann     | today-1 12:00 |
      | /writing/old   | none         |         | today-1 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_scroll_depths rows where "day = '{today-1}'" are:
      | path           | scroll_depth | views | visitors |
      | /writing/hello | 0            | 1     | 1        |
      | /writing/hello | 50           | 1     | 1        |
      | /writing/hello | 100          | 2     | 2        |
      | /writing/other | 50           | 1     | 1        |

  Scenario: The roll up counts the readers who read a page through
    Given these analytics_events rows:
      | path | scroll_depth | read_seconds | visitor | occurred_at   | times |
      | /a   | 75           | 30           |         | today-1 12:00 | 1     |
      | /b   | 100          | 300          |         | today-1 12:00 | 1     |
      | /c   | 75           | 29           |         | today-1 12:00 | 1     |
      | /d   | 50           | 60           |         | today-1 12:00 | 1     |
      | /e   | 75           | 5            | eve     | today-1 12:00 | 1     |
      | /e   | 25           | 60           | eve     | today-1 12:00 | 1     |
      | /f   | 75           | 30           | fay     | today-1 12:00 | 2     |
      | /g   | 75           | 30           | gus     | today-1 12:00 | 1     |
      | /g   | 75           | 30           |         | today-1 12:00 | 1     |
      | /h   | 75           | 30           | gus     | today-1 12:00 | 1     |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_paths rows where "day = '{today-1}'" are:
      | path | read_throughs |
      | /a   | 1             |
      | /b   | 1             |
      | /c   | 0             |
      | /d   | 0             |
      | /e   | 0             |
      | /f   | 1             |
      | /g   | 2             |
      | /h   | 1             |

  Scenario: The roll up stores each post's clicks on each link under the day of its view
    Given these analytics_events rows:
      | path           | view_token | occurred_at   |
      | /writing/hello | one        | today-1 12:00 |
      | /writing/hello | two        | today-1 12:00 |
      | /writing/other | three      | today-1 12:00 |
    And these analytics_clicks rows:
      | view  | link_host    | link_path | occurred_at   |
      | one   | docs.example | /guide    | today-1 12:00 |
      | one   | docs.example | /guide    | today-1 12:00 |
      | two   | code.example | /repo     | today-1 12:00 |
      | three | docs.example | /guide    | today 00:01   |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_clicks rows where "day = '{today-1}'" are:
      | path           | link_host    | link_path | clicks |
      | /writing/hello | code.example | /repo     | 1      |
      | /writing/hello | docs.example | /guide    | 2      |
      | /writing/other | docs.example | /guide    | 1      |

  Scenario: The roll up stores the device classes of the site and of each page
    Given these analytics_events rows:
      | path           | device_class | visitor | occurred_at   |
      | /writing/hello | in-app       | ann     | today-1 12:00 |
      | /writing/other | in-app       | ann     | today-1 12:00 |
      | /writing/other | desktop      |         | today-1 12:00 |
      | /writing/other |              |         | today-1 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_devices rows where "day = '{today-1}'" are:
      | path           | device_class | views | visitors |
      | none           | desktop      | 1     | 1        |
      | none           | in-app       | 2     | 1        |
      | /writing/hello | in-app       | 1     | 1        |
      | /writing/other | desktop      | 1     | 1        |
      | /writing/other | in-app       | 1     | 1        |

  Scenario: The roll up counts the first moment of a day and leaves today for tomorrow
    Given these analytics_events rows:
      | occurred_at   |
      | today-1 00:00 |
      | today 00:00   |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollups rows where "day = '{today-1}'" are:
      | views |
      | 1     |

  Scenario: The roll up stores each hour's visitors, each reader once an hour
    Given these analytics_events rows:
      | visitor | occurred_at   |
      | ann     | today-1 09:00 |
      | ann     | today-1 09:10 |
      | bob     | today-1 09:20 |
      | cat     | today-1 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_hours rows where "day = '{today-1}'" are:
      | hour | visitors |
      | 9    | 2        |
      | 12   | 1        |

  Scenario: The roll up stores a day with no visits
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollups rows where "day = '{today-1}'" are:
      | views | visitors | read_seconds |
      | 0     | 0        | 0            |

  Scenario: The roll up counts each reader once for the month so far
    Given these analytics_events rows:
      | path           | visitor | occurred_at   |
      | /writing/hello | ann     | today-1 first |
      | /writing/other | ann     | today-1 12:00 |
      | /writing/other | bob     | today-1 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_reach rows where "month = '{today-1 first}'" are:
      | path           | reach |
      | none           | 2     |
      | /writing/hello | 1     |
      | /writing/other | 2     |

  Scenario: The roll up leaves a reader from the month before out of this month
    Given these analytics_events rows:
      | visitor | occurred_at     |
      | ann     | today-1 first-1 |
      | bob     | today-1 12:00   |
    When the job "Analytics::Jobs::RollUpAnalytics" runs 2 times
    Then the analytics_rollup_reach rows where "month = '{today-1 first}' AND path IS NULL" are:
      | reach |
      | 1     |

  Scenario: The roll up stores no reach for a month whose start the raw visits no longer hold
    Given these analytics_events rows:
      | occurred_at |
      | edge        |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollup_reach table holds 0 rows where "month = '{edge first}'"

  Scenario: The roll up stores the same rows when it runs twice
    Given these analytics_events rows:
      | path           | referrer_host | country_code | source | view_token | occurred_at   |
      | /writing/hello | news.example  | JP           | feed   | one        | today-1 12:00 |
    And these analytics_clicks rows:
      | view | link_host    | link_path | occurred_at   |
      | one  | docs.example | /guide    | today-1 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs 2 times
    Then the analytics_rollups rows where "day = '{today-1}'" are:
      | views | visitors |
      | 1     | 1        |
    And the analytics_rollup_paths rows where "day = '{today-1}'" are:
      | path           | views |
      | /writing/hello | 1     |
    And the analytics_rollup_referrers rows where "day = '{today-1}'" are:
      | host         | views |
      | news.example | 1     |
    And the analytics_rollup_countries rows where "day = '{today-1}'" are:
      | country_code | views |
      | JP           | 1     |
    And the analytics_rollup_sources rows where "day = '{today-1}' AND path IS NULL" are:
      | source | views |
      | feed   | 1     |
    And the analytics_rollup_page_referrers rows where "day = '{today-1}'" are:
      | host         | views |
      | news.example | 1     |
    And the analytics_rollup_page_countries rows where "day = '{today-1}'" are:
      | country_code | views |
      | JP           | 1     |
    And the analytics_rollup_clicks rows where "day = '{today-1}'" are:
      | link_path | clicks |
      | /guide    | 1      |

  Scenario: The roll up fills every day a run that skipped nights left behind
    Given these analytics_rollups rows:
      | day     | views | visitors |
      | today-4 | 0     | 0        |
    And these analytics_events rows:
      | occurred_at   |
      | today-3 12:00 |
      | today-1 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollups rows where "day >= '{today-3}'" are:
      | day     | views |
      | today-3 | 1     |
      | today-2 | 0     |
      | today-1 | 1     |

  Scenario: The roll up leaves a day it already rolled up alone
    Given these analytics_rollups rows:
      | day     | views | visitors |
      | today-3 | 5     | 3        |
      | today-2 | 1     | 1        |
    And these analytics_events rows:
      | occurred_at   |
      | today-3 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollups rows where "day = '{today-3}'" are:
      | views | visitors |
      | 5     | 3        |

  Scenario: The roll up starts at the oldest visit it still holds
    Given these analytics_rollups rows:
      | day       | views | visitors |
      | today-201 | 0     | 0        |
    And these analytics_events rows:
      | occurred_at   |
      | today-4 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollups table holds 0 rows where "day = '{today-101}'"

  Scenario: The roll up rolls up the day before yesterday again with its new reads and clicks
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today-2 | 1     | 1        | 0            |
    And these analytics_events rows:
      | path           | view_token | read_seconds | occurred_at   |
      | /writing/hello | one        | 42           | today-2 12:00 |
    And these analytics_clicks rows:
      | view | link_host    | link_path | occurred_at   |
      | one  | docs.example | /guide    | today-2 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollups rows where "day = '{today-2}'" are:
      | views | read_seconds |
      | 1     | 42           |
    And the analytics_rollup_clicks rows where "day = '{today-2}'" are:
      | path           | link_host    | link_path | clicks |
      | /writing/hello | docs.example | /guide    | 1      |

  Scenario: The roll up leaves the day before yesterday alone once the raw visits no longer hold it
    Given these analytics_rollups rows:
      | day     | views | visitors |
      | today-2 | 5     | 3        |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_rollups rows where "day = '{today-2}'" are:
      | views | visitors |
      | 5     | 3        |

  Scenario: The roll up sums a day before the prune deletes its visits
    Given these analytics_events rows:
      | path           | view_token | scroll_depth | read_seconds | occurred_at    |
      | /writing/hello | old        | 75           | 30           | today-91 12:00 |
    And these analytics_clicks rows:
      | view | link_host    | link_path | occurred_at    |
      | old  | docs.example | /guide    | today-91 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_events table holds 0 rows
    And the analytics_clicks table holds 0 rows
    And the analytics_rollups rows where "day = '{today-91}'" are:
      | views |
      | 1     |
    And the analytics_rollup_clicks rows where "day = '{today-91}'" are:
      | path           | link_host    | link_path | clicks |
      | /writing/hello | docs.example | /guide    | 1      |
    And the analytics_rollup_paths rows where "day = '{today-91}'" are:
      | path           | read_throughs |
      | /writing/hello | 1             |

  Scenario: The roll up keeps the rollups of the days it pruned
    Given these analytics_rollups rows:
      | day      | views | visitors |
      | today-91 | 9     | 5        |
    And these analytics_events rows:
      | occurred_at    |
      | today-91 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_events table holds 0 rows
    And the analytics_rollups rows where "day = '{today-91}'" are:
      | views |
      | 9     |

  Scenario: The prune takes the whole day that falls out of the window and keeps the edge
    Given these analytics_events rows:
      | path   | occurred_at    |
      | /gone  | today-90 23:59 |
      | /kept  | today-89 00:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_events rows are:
      | path  |
      | /kept |

  Scenario: The prune stops at the first day no run rolled up
    Given these analytics_rollups rows:
      | day      | views | visitors |
      | today-95 | 1     | 1        |
      | today-93 | 1     | 1        |
    And these analytics_events rows:
      | path | occurred_at    |
      | /95  | today-95 12:00 |
      | /94  | today-94 12:00 |
      | /93  | today-93 12:00 |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the analytics_events rows are:
      | path |
      | /93  |
      | /94  |

  Scenario: The prune deletes the feed reader hashes older than 90 days and keeps the counts
    Given these feed_reader_hashes rows:
      | day      |
      | today-90 |
      | today-89 |
    And these feed_readers rows:
      | day      | readers |
      | today-90 | 1       |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the feed_reader_hashes rows are:
      | day      |
      | today-89 |
    And the feed_readers rows are:
      | day      | readers |
      | today-90 | 1       |

  Scenario: The roll up saves the reader count of a post past its first 12 months
    Given these analytics posts:
      | slug | published |
      | old  | today-370 |
      | new  | today-360 |
      | gone | today-30  |
    And these post_reader_hashes rows:
      | path              | times |
      | /writing/old      | 3     |
      | /writing/new      | 2     |
      | /writing/vanished | 2     |
    When the job "Analytics::Jobs::RollUpAnalytics" runs 2 times
    Then the post_reader_counts rows are:
      | path         | readers |
      | /writing/old | 3       |
    And the post_reader_hashes table holds 0 rows where "path = '/writing/old'"
    And the post_reader_hashes table holds 2 rows where "path = '/writing/new'"
    And the post_reader_hashes table holds 0 rows where "path = '/writing/vanished'"

  Scenario: The roll up keeps the readers of a post's new slug and of a draft
    Given these analytics posts:
      | slug     | published | status    |
      | old-slug | today-30  | published |
      | draft    |           | draft     |
    And the post "old-slug" moved to the slug "new-slug"
    And these post_reader_hashes rows:
      | path              | times |
      | /writing/old-slug | 2     |
      | /writing/new-slug | 1     |
      | /writing/draft    | 1     |
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the post_reader_hashes table holds 0 rows where "path = '/writing/old-slug'"
    And the post_reader_hashes table holds 1 rows where "path = '/writing/new-slug'"
    And the post_reader_hashes table holds 1 rows where "path = '/writing/draft'"

  Scenario: The roll up keeps the hashes and saves no count when the delete breaks
    Given these analytics posts:
      | slug | published |
      | old  | today-370 |
    And these post_reader_hashes rows:
      | path         | times |
      | /writing/old | 3     |
    And the database refuses to delete post_reader_hashes rows
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the post_reader_hashes table holds 3 rows
    And the post_reader_counts table holds 0 rows
    And the sync failure of "analytics_rollup" is "readers_failed" with a message holding "features refused it"

  Scenario: The roll up clears an earlier failure once a run gets through
    Given the sync "analytics_rollup" failed with "rollup_failed"
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then no sync failure of "analytics_rollup" is left

  Scenario: A roll up that breaks leaves the failure for the owner and holds the prune back
    Given these analytics_events rows:
      | occurred_at    |
      | today-91 12:00 |
    And the database refuses to insert analytics_rollups rows
    When the job "Analytics::Jobs::RollUpAnalytics" runs 2 times
    Then the sync failure of "analytics_rollup" is "rollup_failed" with a message holding "features refused it"
    And the sync failure of "analytics_rollup" counts 2 runs
    And the analytics_events table holds 1 rows
    And the performance_jobs rows where "job = 'Analytics::Jobs::RollUpAnalytics'" are:
      | outcome |
      | failed  |
      | failed  |

  Scenario: A prune that breaks is told apart from a roll up that broke
    Given these analytics_events rows:
      | occurred_at    |
      | today-91 12:00 |
    And the database refuses to delete analytics_events rows
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the sync failure of "analytics_rollup" is "prune_failed"

  Scenario: The roll up tells the owner the reader counts failed
    Given these analytics posts:
      | slug | published |
      | old  | today-370 |
    And these post_reader_hashes rows:
      | path         | times |
      | /writing/old | 3     |
    And the database refuses to insert post_reader_counts rows
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the sync failure of "analytics_rollup" is "readers_failed" with a message holding "features refused it"
