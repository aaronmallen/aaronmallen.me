Feature: Admin jobs tab
  The jobs tab reads Sidekiq's processes, queues, sets and the cron schedule out of Redis.
  This worker's own Sidekiq beats into Redis every ten seconds, so the steps that count processes open the tab with
  only the processes they made.

  Background:
    Given I am signed in to the admin

  Scenario: With workers running the tab says so and counts every figure
    Given a worker process "a" that is 3 busy of 10, beating 3 seconds ago
    And a worker process "b" that is 2 busy of 10, beating 9 seconds ago
    And the queue "parked" holds 3 "Shares::Jobs::FetchTitle" jobs waiting since 252 seconds ago
    And the scheduled set holds:
      | class     | args | at  |
      | Later::Job |      | 600 |
    And the retries set holds:
      | class      | args | at |
      | Retry::Job |      | 60 |
    And the dead set holds:
      | class     | args | at  |
      | Dead::Job |      | -60 |
      | Gone::Job |      | -90 |
    When I open the jobs tab
    Then the page heading is "Settings"
    And the settings tab "jobs" is current
    And the worker health reads "Working"
    And the worker health says "2 processes"
    And the worker health shows the heartbeat of 3 seconds ago
    And the jobs counts read:
      | busy      | 5 of 20                  |
      | enqueued  | 3                        |
      | latency   | 4m                       |
      | scheduled | 1                        |
      | retries   | 1                        |
      | dead      | 2                        |
    And the jobs tab reads "jobs 3"
    And the jobs page shows no warning
    And the page has no axe breaches in light or dark

  Scenario: With only idle processes the worker is quiet
    Given a worker process "a" that is 0 busy of 10, beating 3 seconds ago
    When I open the jobs tab
    Then the worker health reads "Quiet"

  Scenario: With every process told to stop the worker is stopping
    Given a stopping worker process "a" finishing "Posts::Jobs::RenderPost"
    When I open the jobs tab
    Then the worker health reads "Stopping"

  Scenario: With no worker process the tab says so, with the last finished job and the jobs waiting
    Given the queue "parked" holds 214 "Shares::Jobs::FetchTitle" jobs waiting since 60 seconds ago
    And the table performance_jobs holds:
      | job       | outcome   | duration | query_count | query_time | occurred_at    |
      | Spec::Job | succeeded | 1        | 0           | 0          | 2286 seconds ago |
      | Spec::Job | succeeded | 1        | 0           | 0          | 9000 seconds ago |
    When I open the jobs tab
    Then the worker health reads "Not seen"
    And the jobs page warns "The last job finished 38m ago."
    And the jobs page warns "214 jobs are waiting."
    And the "Running now" card says "No worker processes are running."

  Scenario: With no worker process and no finished job the tab says so
    When I open the jobs tab
    Then the jobs page warns "No finished job on record."

  Scenario: The last seven days show today's figures in UTC with a bar a day
    Given Sidekiq processed 1240 and failed 3 today and processed 900 yesterday
    When I visit "/admin/settings/jobs"
    Then the page says "today (UTC)"
    And the page says "1,240 processed"
    And the page says "3 failed"
    And the jobs bars draw 7 days, today last with its failures, labelled "Processed and failed, last 7 days in UTC:"

  Scenario: With Redis down the counts read unknown and the tabs still work
    Given Redis is down
    When I visit "/admin/settings/jobs"
    Then the jobs page warns "RedisClient::CannotConnectError"
    And the jobs counts read:
      | busy      | unknown |
      | enqueued  | unknown |
      | latency   | unknown |
      | scheduled | unknown |
      | retries   | unknown |
      | dead      | unknown |
    And the jobs tab reads "jobs !"
    And the cron entry "sync_gmail" says "next run unknown"
    And the cron filter reads "all 32, failed 0, paused"
    When I visit "/admin/settings/jobs?cron=paused"
    Then the cron schedule says "Redis isn't answering, so what is paused is unknown."
    When I visit "/admin/settings/security"
    Then the jobs tab reads "jobs !"

  Scenario: The cron schedule shows every entry with its description, cron string, class and args
    When I visit "/admin/settings/jobs"
    Then the cron schedule lists every entry of config/sidekiq.yml.erb
    And the cron entry "sync_issues" shows the code "6-59/15 * * * *", the class "Tasks::Jobs::SyncIssues [\"github\"]" and "every 15 minutes, from :06"
    And the cron entry "back_up_database" says "no run on record"
    And the cron entry "sync_gmail" links nowhere

  Scenario: An entry with runs on record shows its newest run and links to Performance
    Given the cron entry "publish_due_posts" runs next in 60 seconds
    And the table performance_jobs holds:
      | job                           | schedule_key      | outcome   | duration | query_count | query_time | occurred_at    |
      | Posts::Jobs::PublishDuePosts  | publish_due_posts | succeeded | 9000     | 0           | 0          | 2 minutes ago  |
      | Posts::Jobs::PublishDuePosts  | publish_due_posts | succeeded | 1500     | 0           | 0          | 1 minute ago   |
      | Mail::Jobs::SyncGmail         | sync_gmail        | succeeded | 10       | 0           | 0          | 10 days ago    |
    When I visit "/admin/settings/jobs"
    Then the cron entry "publish_due_posts" says "1.5 s"
    And the cron entry "sync_gmail" links to "/admin/performance?range=14#job-mail-jobs-syncgmail"

  Scenario: An entry's times are its last and next run
    Given the cron entry "publish_due_posts" runs next in 60 seconds
    And the table performance_jobs holds:
      | job                          | schedule_key      | outcome   | duration | query_count | query_time | occurred_at  |
      | Posts::Jobs::PublishDuePosts | publish_due_posts | succeeded | 1500     | 0           | 0          | 1 minute ago |
    When I visit "/admin/settings/jobs"
    Then the times of the cron entry "publish_due_posts" are the last run and the next run

  Scenario: A failed last run sorts first with its error, and the rest sort by next run
    Given the cron entry "sync_gmail" runs next in 30 seconds
    And the cron entry "publish_due_posts" runs next in 60 seconds
    And the table performance_jobs holds:
      | job                             | schedule_key     | outcome | duration | query_count | query_time | error_class | error_message |
      | Backups::Jobs::BackUpDatabase   | back_up_database | failed  | 1500     | 0           | 0          | PG::Error   | disk full     |
    When I visit "/admin/settings/jobs"
    Then the cron entries list in this order, first:
      | back_up_database  |
      | sync_gmail        |
      | publish_due_posts |
    And the cron entry "back_up_database" shows the pill "failed"
    And the cron entry "back_up_database" shows the error "PG::Error disk full"

  Scenario: An entry more than five minutes overdue is missed
    Given the cron entry "sync_gmail" runs next in -301 seconds
    And the cron entry "publish_due_posts" runs next in -299 seconds
    When I visit "/admin/settings/jobs"
    Then the cron entry "sync_gmail" shows the pill "missed"
    And the cron entry "publish_due_posts" shows no pill

  Scenario: A paused entry says so
    Given the cron entry "sync_gmail" is paused
    When I visit "/admin/settings/jobs"
    Then the cron entry "sync_gmail" shows the pill "paused"
    And the cron entry "sync_gmail" says "won't run while paused"

  Scenario: Two entries of one class each read their own last run, and failures count on the tab
    Given the retries set holds:
      | class      | args | at |
      | Retry::Job |      | 60 |
    And the dead set holds:
      | class     | args | at  |
      | Dead::Job |      | -60 |
    And the table performance_jobs holds:
      | job                      | schedule_key        | outcome   | duration | query_count | query_time | error_class   | error_message |
      | Tasks::Jobs::SyncIssues  | sync_issues_github  | failed    | 1500     | 0           | 0          | GitHub::Error | rate limited  |
      | Tasks::Jobs::SyncIssues  | sync_issues_linear  | succeeded | 1500     | 0           | 0          | null          | null          |
    When I visit "/admin/settings/jobs"
    Then the cron entry "sync_issues" shows the pill "failed"
    And the cron entry "sync_linear_issues" shows no pill
    And the jobs tab reads "jobs 3"

  Scenario: The cron filter counts and narrows to failed and paused entries
    Given the cron entry "sync_gmail" is paused
    And the table performance_jobs holds:
      | job                           | schedule_key     | outcome | duration | query_count | query_time |
      | Backups::Jobs::BackUpDatabase | back_up_database | failed  | 1500     | 0           | 0          |
    When I visit "/admin/settings/jobs"
    Then the cron filter reads "all 32, failed 1, paused 1"
    When I visit "/admin/settings/jobs?cron=failed"
    Then the cron entries are only "back_up_database"
    When I visit "/admin/settings/jobs?cron=paused"
    Then the cron entries are only "sync_gmail"

  Scenario: The cron filter says so when nothing failed or is paused
    When I visit "/admin/settings/jobs?cron=failed"
    Then the cron schedule says "Every entry succeeded its last run."
    When I visit "/admin/settings/jobs?cron=paused"
    Then the cron schedule says "Nothing is paused."

  Scenario: Running now lists each process and its jobs, and the idle one runs nothing
    Given a worker process "a" on "worker-a" running "Posts::Jobs::RenderPost" for 252 seconds with the args "[42]"
    And an idle worker process "b" on "worker-b"
    When I open the jobs tab
    Then the "Running now" card lists the processes and running jobs:
      | .jobs-host     | worker-a · pid 4120                     |
      | .jobs-capacity | 1 of 5                                  |
      | .jobs-meta     | queues default, mailers                 |
      | .li-title      | Posts::Jobs::RenderPost                 |
      | .jobs-args     | 42                                      |
      | .jobs-ran      | 4m                                      |
      | .jobs-process  | Idle. Nothing running on this process.  |

  Scenario: A stopping process says it is finishing its jobs
    Given a stopping worker process "a" finishing "Posts::Jobs::RenderPost"
    When I open the jobs tab
    Then the "Running now" card lists the processes and running jobs:
      | .jobs-stopping | finishing 1 job, taking no new work |

  Scenario: Queues list with their size and latency, and a queue opens in a drawer a hundred at a time
    Given the queue "parked" holds 250 "Shares::Jobs::FetchTitle" jobs waiting since 700 seconds ago
    When I visit "/admin/settings/jobs"
    Then the queue "parked" reads "250" with the class "jobs-bad" and says "oldest waited 11m"
    When I visit "/admin/settings/jobs?queue=parked"
    Then the queue drawer says "250 waiting"
    And the queue drawer lists the args 1 to 100
    And the queue drawer's page links read:
      | next | later | /admin/settings/jobs?queue=parked&page=2 |
    When I visit "/admin/settings/jobs?queue=parked&page=2"
    Then the queue drawer's page links read:
      | prev | earlier | /admin/settings/jobs?queue=parked        |
      | next | later   | /admin/settings/jobs?queue=parked&page=3 |
    When I visit "/admin/settings/jobs?queue=parked&page=3"
    Then the queue drawer lists the args 201 to 250

  Scenario: An empty queue says so and opens no drawer, nor does an unknown one
    Given the queue "parked" holds 1 "Shares::Jobs::FetchTitle" job waiting since 1 seconds ago
    And the queue "mailers" is empty
    When I visit "/admin/settings/jobs"
    Then the Queues card lists 2 queues
    And the queue "mailers" says "empty" and links nowhere
    When I visit "/admin/settings/jobs?queue=mailers"
    Then no queue drawer opens
    When I visit "/admin/settings/jobs?queue=nope"
    Then no queue drawer opens

  Scenario: Each job set says so when empty
    When I visit "/admin/settings/jobs"
    Then the retries card of the jobs page says "No retries waiting."
    And the dead card of the jobs page says "No dead jobs."
    And the scheduled card of the jobs page says "Nothing scheduled."

  Scenario: Retries list soonest first with their args, error, tries and next try
    Given the retries set holds:
      | class                   | args             | at  |
      | Later::Job              |                  | 600 |
      | Social::Jobs::CrossPost | [42, "mastodon"] | 60  |
    When I visit "/admin/settings/jobs"
    Then the retries card of the jobs page lists:
      | Social::Jobs::CrossPost |
      | Later::Job              |
    And the first row of the retries card shows "42,\"mastodon\"" in ".jobs-args"
    And the first row of the retries card shows "Faraday::TimeoutError execution expired" in ".jobs-error"
    And the first row of the retries card shows "retries 2 of 25" in ".jobs-retrying"
    And the first row of the retries card stamps 60 seconds from now

  Scenario: Dead jobs list newest first with their error and tries
    Given the dead set holds:
      | class      | args | at   | error                | retry count |
      | Older::Job |      | -600 |                      | 25          |
      | Newer::Job |      | -60  | PG::Error: disk full | 25          |
    When I visit "/admin/settings/jobs"
    Then the dead card of the jobs page lists:
      | Newer::Job |
      | Older::Job |
    And the first row of the dead card shows "PG::Error disk full" in ".jobs-error"
    And the dead card of the jobs page says "retries 25 of 25"

  Scenario: Scheduled jobs list soonest first with no error
    Given the scheduled set holds:
      | class      | args | at  |
      | Later::Job |      | 600 |
      | Soon::Job  | [1]  | 60  |
    When I visit "/admin/settings/jobs"
    Then the scheduled card of the jobs page lists:
      | Soon::Job  |
      | Later::Job |
    And the scheduled card of the jobs page shows no error

  Scenario: A long set shows five, then a hundred to a page
    Given the retries set holds 120 "Job" jobs, 1 second apart
    When I visit "/admin/settings/jobs"
    Then the retries card of the jobs page lists:
      | Job0 |
      | Job1 |
      | Job2 |
      | Job3 |
      | Job4 |
    And the retries card of the jobs page links "Show all 120" to "/admin/settings/jobs?set=retries#jobs-retries"
    When I visit "/admin/settings/jobs?set=retries"
    Then the retries card of the jobs page lists 100 jobs
    And the retries card of the jobs page links "later" to "/admin/settings/jobs?set=retries&page=2#jobs-retries"
    And the retries card of the jobs page links "Show fewer" to "/admin/settings/jobs#jobs-retries"
    When I visit "/admin/settings/jobs?set=retries&page=2"
    Then the retries card of the jobs page lists 20 jobs

  Scenario: Dead pages read newer and older
    Given the dead set holds 101 "Job" jobs, 1 second apart
    When I visit "/admin/settings/jobs?set=dead"
    Then the dead card's next page link reads "Older"

  Scenario: The job drawer shows a retry's facts, error, arguments and backtrace
    Given the retries set holds:
      | class                   | args                    | at | jid          | backtrace                                                                         |
      | Social::Jobs::CrossPost | [42, { "thread": true }] | 60 | abc123def456 | app/jobs/cross_post.rb:31:in 'perform' \| sidekiq/processor.rb:220:in 'execute_job' |
    When I visit "/admin/settings/jobs"
    And I follow "Social::Jobs::CrossPost" in the retries card
    Then the job drawer shows the name "Social::Jobs::CrossPost"
    When I visit "/admin/settings/jobs?open=retries&jid=abc123def456"
    Then the job drawer shows the facts:
      | jid      | abc123def456 |
      | queue    | parked       |
      | retries  | 2 of 25      |
      | created  |              |
      | enqueued |              |
      | failed   |              |
      | next try |              |
    And the job drawer shows the error "Faraday::TimeoutError execution expired", the args and a backtrace of "2 lines" ending "sidekiq/processor.rb:220:in 'execute_job'"
    When I visit "/admin/settings/jobs?open=dead&jid=abc123def456"
    Then no job drawer opens

  Scenario: The tab fits a phone, with the bars below today's figures
    Given a worker process "w" on "a-long-worker-host-name.example.internal" running "Social::Jobs::SendWebmention" for 90 seconds with the args "[\"https://example.org/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"]"
    And the queue "parked" holds 3 "Shares::Jobs::FetchTitle" jobs waiting since 90 seconds ago
    And the retries set holds:
      | class                        | args | at | error                                                                                                  |
      | Social::Jobs::SendWebmention | [1]  | 60 | Net::OpenTimeout: Failed to open TCP connection to bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb |
    And I use a phone
    When I open the jobs tab
    Then the page does not scroll sideways
    And ".jobs-bars" sits at or below ".jobs-big-small"
    And the page has no axe breaches in light or dark

  Scenario: On a wide screen the bars sit beside today's figures
    Given my window is 1180 by 800
    When I open the jobs tab
    Then ".jobs-bars" sits on the row of ".jobs-big-small"

  Scenario: A set job's More button opens its menu below it, marked expanded, and leaves the drawer shut
    Given the retries set holds:
      | class                   | args | at |
      | Social::Jobs::CrossPost | [42] | 60 |
    And my window is 1180 by 800
    When I visit "/admin/settings/jobs"
    Then the More button of the first row in "#jobs-retries" is named "More actions for Social::Jobs::CrossPost"
    When I click the More button of the first row in "#jobs-retries"
    Then the menu opens within 8 pixels below the More button
    And the More button is marked expanded
    And I am on "/admin/settings/jobs"
    And no dialog is open
    When I press Escape
    Then no menu is open
    And the More button is not marked expanded

  Scenario Outline: The More button puts focus on the first menu item when <key> opens it
    Given the retries set holds:
      | class                   | args | at |
      | Social::Jobs::CrossPost | [42] | 60 |
    When I visit "/admin/settings/jobs"
    And I focus the More button of the first row in "#jobs-retries" and press <key>
    Then the first menu item has focus

    Examples:
      | key   |
      | Enter |
      | Space |

  Scenario: A cron entry's More button opens its menu
    When I visit "/admin/settings/jobs"
    And I click the More button of the first row in ".jobs-cron-entry"
    Then a menu is open
