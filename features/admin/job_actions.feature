Feature: Admin job actions
  The jobs tab runs, pauses and enables cron entries, and runs, retries, kills, deletes and discards set jobs.

  Background:
    Given I am signed in to the admin

  Scenario: Running a cron entry now queues its class with its args
    When I post to "/admin/settings/jobs/cron/sync_issues/run"
    And I follow the answer
    Then the page's toast reads "Queued to run now"
    And the database soon answers "Tasks::Jobs::SyncIssues sync_issues_github" for:
      """
      SELECT job, schedule_key FROM performance_jobs
      """

  Scenario: Running a cron entry lands back on the cron section it was pressed on
    When I post to "/admin/settings/jobs/cron/publish_due_posts/run" with:
      | return_to | /admin/settings/jobs?cron=failed |
    Then the answer sends me to "/admin/settings/jobs?cron=failed#jobs-cron"

  Scenario Outline: An action on a cron entry the schedule lacks is not found
    When I post to "/admin/settings/jobs/cron/nothing/<act>"
    Then the answer is 404

    Examples:
      | act   |
      | run   |
      | pause |

  Scenario: The menu of a cron entry the schedule lacks is not found
    When I send GET "/admin/settings/jobs/cron/nothing/menu"
    Then the answer is 404

  Scenario: Running a cron entry says so when the queue is down
    Given Redis is down
    When I post to "/admin/settings/jobs/cron/sync_issues/run"
    And I follow the answer
    Then the page's toast reads "Not queued · the job queue is down, so try again soon"

  Scenario: Pausing an entry sets the scheduler's own enabled state
    When I visit "/admin/settings/jobs"
    And I press "Pause sync_gmail" on the cron entry "sync_gmail"
    Then the page toasts "Paused · it won't run until you enable it"
    And the cron entry "sync_gmail" shows the pill "paused"
    And the cron entry "sync_gmail" offers "Enable sync_gmail"
    And Redis holds the state "{\"enabled\":false}" for the cron entry "sync_gmail"

  Scenario: Enabling a paused entry clears the pill
    Given the cron entry "sync_gmail" is paused
    When I visit "/admin/settings/jobs"
    And I press "Enable sync_gmail" on the cron entry "sync_gmail"
    Then the page toasts "Enabled · it runs on its next tick"
    And the cron entry "sync_gmail" shows no pill
    And the cron entry "sync_gmail" offers "Pause sync_gmail"
    And Redis holds the state "{\"enabled\":true}" for the cron entry "sync_gmail"

  Scenario: Pausing changes nothing and says so when Redis is down
    Given Redis is down
    When I post to "/admin/settings/jobs/cron/sync_gmail/pause"
    And I follow the answer
    Then the page's toast starts with "Nothing changed"

  Scenario: A cron row carries its menu and its buttons, which land back on the view they were pressed on
    Given the cron entry "sync_gmail" is paused
    When I visit "/admin/settings/jobs"
    Then the cron entry "sync_gmail" opens its menu from "/admin/settings/jobs/cron/sync_gmail/menu"
    And the cron entry "publish_due_posts" offers "Run publish_due_posts now"
    And the cron entry "publish_due_posts" offers "Pause publish_due_posts"
    And every button of the cron entry "sync_gmail" returns to "/admin/settings/jobs"
    When I visit "/admin/settings/jobs?cron=paused"
    And I press "Enable sync_gmail" on the cron entry "sync_gmail"
    Then I am on "/admin/settings/jobs?cron=paused#jobs-cron"

  Scenario: With Redis down a cron row keeps only its More button and its menu turns its actions off
    Given Redis is down
    When I visit "/admin/settings/jobs"
    Then the buttons of the cron entry "sync_gmail" are "More actions for sync_gmail"
    When I visit "/admin/settings/jobs/cron/sync_gmail/menu?return_to=/admin/settings/jobs"
    Then every button of the menu is off

  Scenario: A cron entry's menu runs, pauses and opens Performance, coming back where it opened
    Given the table performance_jobs holds:
      | job                   | schedule_key | outcome   | duration | query_count | query_time | occurred_at  |
      | Mail::Jobs::SyncGmail | sync_gmail   | succeeded | 10       | 0           | 0          | 1 minute ago |
    When I visit "/admin/settings/jobs/cron/sync_gmail/menu?return_to=/admin/settings/jobs%3Fcron%3Dpaused"
    Then the menu reads "Run now, Pause, Open in Performance"
    And the page has a link to "/admin/performance?range=7#job-mail-jobs-syncgmail"
    And every return_to on the page is "/admin/settings/jobs?cron=paused"

  Scenario: A paused entry's menu offers Enable and no Performance link with no run on record
    Given the cron entry "sync_gmail" is paused
    When I visit "/admin/settings/jobs/cron/sync_gmail/menu?return_to=/admin/settings/jobs"
    Then the menu reads "Run now, Enable"

  Scenario: Running a scheduled job now moves it to its queue
    Given the scheduled set holds:
      | class                   | args | at  | jid          |
      | Social::Jobs::CrossPost | [42] | 600 | abc123def456 |
    When I post to "/admin/settings/jobs/scheduled/abc123def456/run"
    And I follow the answer
    Then the page's toast reads "Queued to run now"
    And the scheduled set holds no job
    And the queue "parked" holds the job "abc123def456"

  Scenario: Deleting a scheduled job drops it without running it
    Given the scheduled set holds:
      | class                   | args | at  | jid          |
      | Social::Jobs::CrossPost | [42] | 600 | abc123def456 |
    When I post to "/admin/settings/jobs/scheduled/abc123def456/delete"
    And I follow the answer
    Then the page's toast starts with "Job deleted"
    And the scheduled set holds no job
    And the queue "parked" holds no job

  Scenario: A scheduled job has no kill
    Given the scheduled set holds:
      | class                   | args | at  | jid          |
      | Social::Jobs::CrossPost | [42] | 600 | abc123def456 |
    When I post to "/admin/settings/jobs/scheduled/abc123def456/kill"
    Then the answer is 404

  Scenario: Retrying a retry now gives one try back
    Given the retries set holds:
      | class                   | args | at | jid          |
      | Social::Jobs::CrossPost | [42] | 60 | abc123def456 |
    When I post to "/admin/settings/jobs/retries/abc123def456/retry"
    And I follow the answer
    Then the page's toast reads "Job queued again"
    And the retries set holds no job
    And the queue "parked" holds the job "abc123def456" with 1 retry

  Scenario: Killing a retry sends it to the dead set
    Given the retries set holds:
      | class                   | args | at | jid          |
      | Social::Jobs::CrossPost | [42] | 60 | abc123def456 |
    When I post to "/admin/settings/jobs/retries/abc123def456/kill"
    And I follow the answer
    Then the page's toast starts with "Sent to dead jobs"
    And the retries set holds no job
    And the dead set holds the job "abc123def456"
    And the queue "parked" holds no job

  Scenario: Deleting a retry drops it
    Given the retries set holds:
      | class                   | args | at | jid          |
      | Social::Jobs::CrossPost | [42] | 60 | abc123def456 |
    When I post to "/admin/settings/jobs/retries/abc123def456/delete"
    Then the retries set holds no job
    And the queue "parked" holds no job

  Scenario: Retrying a dead job queues it again
    Given the dead set holds:
      | class                   | args | at  | jid          |
      | Social::Jobs::CrossPost | [42] | -60 | abc123def456 |
    When I post to "/admin/settings/jobs/dead/abc123def456/retry"
    And I follow the answer
    Then the page's toast reads "Job queued again"
    And the dead set holds no job
    And the queue "parked" holds the job "abc123def456"

  Scenario: Discarding a dead job drops it for good
    Given the dead set holds:
      | class                   | args | at  | jid          |
      | Social::Jobs::CrossPost | [42] | -60 | abc123def456 |
    When I post to "/admin/settings/jobs/dead/abc123def456/discard"
    And I follow the answer
    Then the page's toast reads "Job discarded"
    And the dead set holds no job
    And the queue "parked" holds no job

  Scenario: A set action keeps the set, page and drawer it was pressed on, or lands on the set's card
    Given the retries set holds:
      | class                   | args | at | jid          |
      | Social::Jobs::CrossPost | [42] | 60 | abc123def456 |
      | Social::Jobs::CrossPost | [43] | 90 | def456abc123 |
    When I post to "/admin/settings/jobs/retries/abc123def456/retry" with:
      | return_to | /admin/settings/jobs?set=retries&page=2&open=retries&jid=abc123def456 |
    Then the answer sends me to "/admin/settings/jobs?set=retries&page=2&open=retries&jid=abc123def456#jobs-retries"
    When I post to "/admin/settings/jobs/retries/def456abc123/retry"
    Then the answer sends me to "/admin/settings/jobs#jobs-retries"

  Scenario: Acting on a job that already left its set changes nothing and says so
    When I post to "/admin/settings/jobs/retries/abc123def456/kill"
    And I follow the answer
    Then the page's toast reads "That job already left its list · nothing changed"
    And the dead set holds no job

  Scenario: A set action changes nothing and says so when Redis is down
    Given Redis is down
    When I post to "/admin/settings/jobs/retries/abc123def456/delete"
    And I follow the answer
    Then the page's toast starts with "Nothing changed"

  Scenario: A dead row carries its menu and retries from a button on hover
    Given the dead set holds:
      | class                   | args | at  | jid          |
      | Social::Jobs::CrossPost | [42] | -60 | abc123def456 |
    When I visit "/admin/settings/jobs"
    Then the first row of the dead card opens its menu from "/admin/settings/jobs/dead/abc123def456/menu"
    And the first row of the dead card offers "Retry Social::Jobs::CrossPost now"
    When I post the hover form of the first row of the dead card
    Then the answer sends me to "/admin/settings/jobs#jobs-dead"
    And the dead set holds no job
    And the queue "parked" holds the job "abc123def456"

  Scenario: A scheduled row runs from a button on hover
    Given the scheduled set holds:
      | class                   | args | at  | jid          |
      | Social::Jobs::CrossPost | [42] | 600 | abc123def456 |
    When I visit "/admin/settings/jobs"
    Then the first row of the scheduled card offers "Run Social::Jobs::CrossPost now"

  Scenario: With Redis down the set rows and their buttons go
    Given Redis is down
    When I visit "/admin/settings/jobs"
    Then the page has no "#jobs-dead"

  Scenario Outline: A <set> job's menu offers <items>
    Given the <key> set holds:
      | class                   | args | at     | jid          | error   |
      | Social::Jobs::CrossPost | [42] | <at>   | abc123def456 | <error> |
    When I visit "/admin/settings/jobs/<set>/abc123def456/menu?return_to=/admin/settings/jobs%3Fset%3D<set>"
    Then the menu reads "<items>"
    And the menu asks "<asks>" before "<asked>"
    And every return_to on the page is "/admin/settings/jobs?set=<set>"

    Examples:
      | set       | key       | at  | error                | items                                   | asked   | asks                                       |
      | scheduled | scheduled | 600 |                      | Run now, Delete                         | delete  | Click again · it won't run                 |
      | retries   | retries   | 60  |                      | Retry now, Kill, Delete                 | kill    | Click again · moves to dead, no more tries |
      | dead      | dead      | -60 |                      | Retry now, Discard                      | discard | Click again · gone for good                |
      | retries   | retries   | 60  | RuntimeError: boom   | Retry now, Kill, Copy error, Delete     | kill    | Click again · moves to dead, no more tries |
      | dead      | dead      | -60 | RuntimeError: boom   | Retry now, Copy error, Discard          | discard | Click again · gone for good                |

  Scenario: A failed job's menu copies its error
    Given the dead set holds:
      | class                   | args | at  | jid          | error              |
      | Social::Jobs::CrossPost | [42] | -60 | abc123def456 | RuntimeError: boom |
    When I visit "/admin/settings/jobs/dead/abc123def456/menu?return_to=/admin/settings/jobs"
    Then the menu copies "RuntimeError: boom"

  Scenario: A retry's menu asks nothing before retrying
    Given the retries set holds:
      | class                   | args | at | jid          |
      | Social::Jobs::CrossPost | [42] | 60 | abc123def456 |
    When I visit "/admin/settings/jobs/retries/abc123def456/menu?return_to=/admin/settings/jobs"
    Then the menu asks nothing before "retry"

  Scenario: The menu of a job that left its set is not found
    When I send GET "/admin/settings/jobs/dead/abc123def456/menu"
    Then the answer is 404

  Scenario: The job drawer acts on a retry, asking before kill and delete, and comes back to itself
    Given the retries set holds:
      | class                   | args | at | jid          |
      | Social::Jobs::CrossPost | [42] | 60 | abc123def456 |
    When I visit "/admin/settings/jobs?open=retries&jid=abc123def456"
    Then the job drawer's buttons are "Retry now, Kill, Delete"
    And the job drawer asks "Kill Social::Jobs::CrossPost? It moves to dead with no more tries." before "kill"
    And the job drawer asks nothing before "retry"
    And every return_to in the job drawer is "/admin/settings/jobs?open=retries&jid=abc123def456"

  Scenario: The job drawer acts on a scheduled job and a dead job
    Given the scheduled set holds:
      | class                   | args | at  | jid          |
      | Social::Jobs::CrossPost | [42] | 600 | abc123def456 |
    And the dead set holds:
      | class                   | args | at  | jid    |
      | Social::Jobs::CrossPost | [42] | -60 | abc000 |
    When I visit "/admin/settings/jobs?open=scheduled&jid=abc123def456"
    Then the job drawer's buttons are "Run now, Delete"
    When I visit "/admin/settings/jobs?open=dead&jid=abc000"
    Then the job drawer's buttons are "Retry now, Discard"
