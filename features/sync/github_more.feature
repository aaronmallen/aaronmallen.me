Feature: The GitHub issue sync keeps comments, links and states in step
  The sync copies each issue's comments, links tasks as their issues relate, and settles a task as its issue closes,
  moves or goes.

  Background:
    Given GitHub holds a token for the issue sync

  Scenario: Comments arrive with author, body, time and link, and a second run changes nothing
    Given GitHub assigns me the issues:
      | number | comments    |
      | 7      | IC_1 IC_2   |
    And the GitHub issue "I_7" has the comments:
      | id   | author | at                   |
      | IC_1 | octocat | 2026-09-28T12:00:00Z |
      | IC_2 | sam     | 2026-09-28T12:01:00Z |
    When the GitHub issue sync runs twice
    Then the task from the issue "I_7" holds the comments:
      | id   | author  | body       | at                   | url                                                               |
      | IC_1 | octocat | Looks good | 2026-09-28T12:00:00Z | https://github.com/aaronmallen/aaronmallen.me/issues/7#issuecomment-1 |
      | IC_2 | sam     | Looks good | 2026-09-28T12:01:00Z | https://github.com/aaronmallen/aaronmallen.me/issues/7#issuecomment-2 |
    And 2 task comments are stored

  Scenario: Comments come to a task already tracked and leave my own alone
    Given the tasks tracking issues:
      | title   | number |
      | Tracked | 7      |
    And the task "Tracked" holds my comment "Mine"
    And GitHub assigns me the issues:
      | number | comments |
      | 7      | IC_1     |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" holds the comments:
      | id   |
      | IC_1 |
      | mine |

  Scenario: Comments follow edits and deletes on GitHub, skip empty ones and keep what a cut list leaves out
    Given GitHub assigns me the issues:
      | number | comments       |
      | 7      | IC_1 IC_2      |
      | 8      | IC_4 IC_5      |
      | 9      | IC_6 IC_7      |
    And the GitHub issue "I_9" has the comments:
      | id   | body          | author |
      | IC_6 | \u0000        |        |
      | IC_7 | Fine\u0000    | none   |
    When the GitHub issue sync runs
    And GitHub assigns me the issues:
      | number | comments        |
      | 7      | IC_2            |
      | 8      | IC_5 IC_8 +more |
    And the GitHub issue "I_7" has the comments:
      | id   | body   |
      | IC_2 | Edited |
    And the GitHub issue sync runs
    Then the task from the issue "I_7" holds the comments:
      | id   | body   |
      | IC_2 | Edited |
    And the task from the issue "I_8" holds the comments:
      | id   |
      | IC_4 |
      | IC_5 |
      | IC_8 |
    And the task from the issue "I_9" holds the comments:
      | id   | body | author |
      | IC_7 | Fine | none   |

  Scenario: Comments stop coming to a task I finished or one canceled upstream
    Given the tasks tracking issues:
      | title    | number | status   | state       |
      | Finished | 7      | done     | open        |
      | Dropped  | 8      | canceled | not_planned |
      | Taken    | 9      | open     | open        |
    And GitHub assigns me the issues:
      | number | comments |
      | 7      | IC_1     |
    And GitHub knows the issues:
      | number | comments | state  | reason      | assignee     |
      | 8      | IC_2     | CLOSED | NOT_PLANNED |              |
      | 9      | IC_3     | OPEN   |             | someone else |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" holds no comments
    And the task from the issue "I_8" holds no comments
    And the task from the issue "I_9" holds no comments

  Scenario: A rate limit part way saves no comments
    Given the tasks tracking issues:
      | title   | number |
      | Tracked | 7      |
    And GitHub assigns me the issues:
      | number | comments |
      | 8      | IC_1     |
    And GitHub rate limits the next issue lookup
    When the GitHub issue sync runs
    Then the GitHub issue sync records the failure "rate_limited"
    And 0 task comments are stored

  Scenario: Related issues imported in one run link up, the blocker blocking its pair
    Given GitHub assigns me the issues:
      | number | blocked_by | blocking |
      | 7      | I_1        |          |
      | 1      |            | I_7      |
    When the GitHub issue sync runs
    Then the task links read "I_1 blocks I_7 synced"
    And the database soon holds "true" for:
      """
      SELECT EXISTS (SELECT 1 FROM task_links WHERE type = 'blocks')
      """

  Scenario: An issue links to a task already here, and a sub-issue to its parent
    Given the tasks tracking issues:
      | title  | number |
      | Before | 1      |
    And GitHub knows the issues:
      | number | blocking |
      | 1      | I_7      |
    And GitHub assigns me the issues:
      | number | blocked_by | parent | sub_issues |
      | 7      | I_1        |        |            |
      | 8      |            | I_9    |            |
      | 9      |            |        | I_8        |
    When the GitHub issue sync runs
    Then the task links read "I_1 blocks I_7 synced | I_9 parent I_8 synced"

  Scenario: A parent link stays while the parent names the child, and the strongest kind wins
    Given GitHub assigns me the issues:
      | number | parent | blocked_by | sub_issues |
      | 7      | I_1    |            |            |
      | 1      |        |            | I_7        |
      | 8      | I_2    | I_2        |            |
      | 2      |        |            |            |
    When the GitHub issue sync runs
    And GitHub assigns me the issues:
      | number | sub_issues |
      | 7      |            |
      | 1      | I_7        |
      | 8      |            |
      | 2      |            |
    And GitHub knows the issues:
      | number |
      | 8      |
    Then the task links read "I_1 parent I_7 synced | I_2 parent I_8 synced"

  Scenario: An issue at the other end that is not here imports and links, without its own relations
    Given GitHub assigns me the issues:
      | number | blocked_by |
      | 7      | I_1        |
    And GitHub knows the issues:
      | number | assignee     | blocked_by |
      | 1      | someone else | I_2        |
      | 2      | someone else |            |
    When the GitHub issue sync runs twice
    Then the task from the issue "I_1" reads:
      | list   | external |
      | status | open     |
    And the task links read "I_1 blocks I_7 synced"
    And the synced issues are "I_1, I_7"

  Scenario: An imported neighbor stays open one run past its last link, then is canceled
    Given GitHub assigns me the issues:
      | number | blocked_by |
      | 7      | I_1        |
    And GitHub knows the issues:
      | number | assignee     |
      | 1      | someone else |
    When the GitHub issue sync runs
    And GitHub assigns me the issues:
      | number |
      | 7      |
    And the GitHub issue sync runs
    Then the task links read ""
    And the task from the issue "I_1" reads:
      | status | open |
    When the GitHub issue sync runs
    Then the task from the issue "I_1" reads:
      | status | canceled |

  Scenario: The sync imports no closed neighbor and none GitHub cannot find
    Given GitHub assigns me the issues:
      | number | blocked_by |
      | 7      | I_1 I_2    |
    And GitHub knows the issues:
      | number | assignee     | state  | reason    |
      | 1      | someone else | CLOSED | COMPLETED |
    When the GitHub issue sync runs
    Then the synced issues are "I_7"

  Scenario: A failed lookup of the other end is reported while the rest still link
    Given GitHub assigns me the issues:
      | number | blocked_by |
      | 7      | I_1 I_2    |
      | 1      |            |
    And GitHub answers the next issue lookup with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 0, "resetAt": "2030-01-01T00:00:00Z"}},
        "errors": [{"message": "GitHub said no", "type": "RATE_LIMITED"}]}
      """
    When the GitHub issue sync runs
    Then the GitHub issue sync records the failure "rate_limited"
    And the task links read "I_1 blocks I_7 synced"

  Scenario: Synced links follow GitHub, but stand while GitHub leaves the relations out
    Given GitHub assigns me the issues:
      | number | blocked_by | blocking |
      | 7      | I_1        |          |
      | 1      |            | I_7      |
      | 8      | I_2        |          |
      | 2      |            | I_8      |
      | 9      | I_3        |          |
      | 3      |            | I_9      |
    When the GitHub issue sync runs
    And GitHub assigns me the issues:
      | number | parent | without   |
      | 7      |        |           |
      | 1      |        |           |
      | 8      | I_2    |           |
      | 2      |        |           |
      | 9      |        | blockedBy |
      | 3      |        | blocking  |
    And the GitHub issue sync runs
    Then the task links read "I_2 parent I_8 synced | I_3 blocks I_9 synced"

  Scenario: Relations that run past a page or hide an issue change no links
    Given GitHub assigns me the issues:
      | number | blocked_by | blocking   | sub_issues |
      | 7      | I_1        |            | I_5 +more  |
      | 1      |            |            |            |
      | 8      |            | I_2 hidden |            |
      | 2      |            |            |            |
    When the GitHub issue sync runs
    Then the task links read ""

  Scenario: A link I made by hand stays, and blocks the synced link on its pair
    Given the tasks tracking issues:
      | title   | number |
      | Seven   | 7      |
      | One     | 1      |
    And the task_links table holds the rows:
      | from_task_id | to_task_id | type    |
      | {task:Seven} | {task:One} | relates |
    And GitHub assigns me the issues:
      | number | blocked_by |
      | 7      | I_1        |
      | 1      |            |
    When the GitHub issue sync runs
    Then the task links read "I_7 relates I_1"

  Scenario: A task with a parent set by hand takes no synced parent
    Given the tasks tracking issues:
      | title | number |
      | Seven | 7      |
    And the tasks:
      | title     |
      | By hand   |
    And the task_links table holds the rows:
      | from_task_id   | to_task_id   | type   |
      | {task:By hand} | {task:Seven} | parent |
    And GitHub assigns me the issues:
      | number | parent |
      | 7      | I_1    |
      | 1      |        |
    When the GitHub issue sync runs
    Then the task links read "By hand parent I_7"

  Scenario: A closed task keeps its synced links as they were
    Given the tasks tracking issues:
      | title   | number | status | state     |
      | Seven   | 7      | open   | open      |
      | Blocker | 1      | done   | completed |
    And the database runs:
      """
      INSERT INTO task_links (from_task_id, to_task_id, type, synced) VALUES ({task:Blocker}, {task:Seven}, 'blocks', true)
      """
    And GitHub assigns me the issues:
      | number |
      | 7      |
    And GitHub knows the issues:
      | number | state  | reason    | sub_issues |
      | 1      | CLOSED | COMPLETED | I_7        |
    When the GitHub issue sync runs
    Then the task links read "I_1 blocks I_7 synced"

  Scenario: The sync asks for relations in the lookup by ID, and never for tracked issues
    Given the tasks tracking issues:
      | title   | number |
      | Tracked | 8      |
    And GitHub assigns me the issues:
      | number |
      | 7      |
    And GitHub knows the issues:
      | number | blocking |
      | 8      | I_2      |
    When the GitHub issue sync runs
    Then GitHub's issue lookup asked for "blockedBy, blocking, parent, subIssues"
    And no GitHub query asked for "tracked"
    And GitHub was asked to look up issues 1 time

  Scenario Outline: An issue closed as <reason> leaves its <before> task <status>
    Given the tasks tracking issues:
      | title   | number | status   | state   |
      | Tracked | 7      | <before> | <state> |
    And GitHub knows the issues:
      | number | state  | reason   |
      | 7      | CLOSED | <reason> |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | status | <status> |

    Examples:
      | reason      | before   | state       | status   |
      | COMPLETED   | open     | open        | done     |
      | NOT_PLANNED | open     | open        | canceled |
      | DUPLICATE   | open     | open        | canceled |
      |             | open     | open        | done     |
      | COMPLETED   | canceled | not_planned | done     |

  Scenario Outline: An issue reopened on GitHub reopens its <status> task, <state> before
    Given the tasks tracking issues:
      | title   | number | status   | state   |
      | Tracked | 7      | <status> | <state> |
    And GitHub assigns me the issues:
      | number |
      | 7      |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | status    | open  |
      | completed | false |

    Examples:
      | status   | state       |
      | done     | completed   |
      | canceled | not_planned |
      | canceled | unassigned  |

  Scenario: A closed issue is checked once a day, an open one every run
    Given the tasks tracking issues:
      | title    | number | status | state     | checked |
      | Closed   | 7      | done   | completed |         |
      | Stale    | 8      | done   | completed | 1500    |
      | Reopened | 9      | done   | completed | 1440    |
    And GitHub knows the issues:
      | number | state  | reason    |
      | 7      | CLOSED | COMPLETED |
      | 8      | CLOSED | COMPLETED |
      | 9      | OPEN   |           |
    When the GitHub issue sync runs twice
    Then GitHub looked up the issue "I_7" 1 time
    And GitHub looked up the issue "I_8" 1 time
    And the source of the task from the issue "I_8" was checked just now
    And the task from the issue "I_9" reads:
      | status | open |

  Scenario: An open tracked issue is checked every run
    Given the tasks tracking issues:
      | title   | number |
      | Tracked | 7      |
    And GitHub knows the issues:
      | number |
      | 7      |
    When the GitHub issue sync runs twice
    Then GitHub was asked to look up issues 2 times

  Scenario: More than a hundred tracked issues are looked up a hundred at a time
    Given 101 tasks tracking GitHub issues
    When the GitHub issue sync runs
    Then GitHub was asked to look up issues 2 times

  Scenario Outline: An issue taken off me <outcome>
    Given the tasks tracking issues:
      | title   | number | status   | state   |
      | Tracked | 7      | <before> | <state> |
    And GitHub knows the issues:
      | number | assignee     | state    | reason   |
      | 7      | someone else | <closed> | <reason> |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | status | <status> |

    Examples:
      | outcome                                    | before   | state      | closed | reason    | status   |
      | cancels its task                           | open     | open       | OPEN   |           | canceled |
      | marks its task done when also completed    | open     | open       | CLOSED | COMPLETED | done     |
      | leaves a task I finished done              | done     | open       | OPEN   |           | done     |
      | leaves its task canceled when it closes    | canceled | unassigned | CLOSED | COMPLETED | canceled |

  Scenario: A task I closed by hand stays closed, and one in progress stays in progress
    Given the tasks tracking issues:
      | title    | number | status      |
      | Finished | 7      | done        |
      | Working  | 8      | in_progress |
    And GitHub assigns me the issues:
      | number |
      | 7      |
      | 8      |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | status | done |
    And the task from the issue "I_8" reads:
      | status | in_progress |

  Scenario: A deleted issue cancels its task, and the sync stops asking about it
    Given the tasks tracking issues:
      | title   | number |
      | Tracked | 7      |
    And GitHub cannot find the issues it is asked to look up
    And GitHub answers the REST path "aaronmallen/aaronmallen.me/issues/7" with status 410
    And GitHub answers the REST path "aaronmallen/aaronmallen.me" with:
      """
      {"full_name": "aaronmallen/aaronmallen.me"}
      """
    When the GitHub issue sync runs twice
    Then the task from the issue "I_7" reads:
      | status | canceled |
      | state  | deleted  |
    And GitHub was asked to look up issues 1 time
    And GitHub was asked 1 time for "aaronmallen/aaronmallen.me/issues/7"

  Scenario: An issue in a repo the token no longer sees leaves its task alone
    Given the tasks tracking issues:
      | title  | number |
      | Seven  | 7      |
      | Eight  | 8      |
    And GitHub cannot find the issues it is asked to look up
    When the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | status | open |
      | state  | open |
    And GitHub was asked 1 time for "aaronmallen/aaronmallen.me"

  Scenario Outline: A <state> issue assigned to me again reopens its task while the rest import
    Given the tasks tracking issues:
      | title   | number | status   | state   |
      | Tracked | 7      | canceled | <state> |
    When the GitHub issue sync runs
    Then GitHub was asked to look up issues 0 times
    Given GitHub rate limits the next issue search
    When the GitHub issue sync runs
    Then the GitHub issue sync records the failure "rate_limited"
    Given GitHub assigns me the issues:
      | number |
      | 7      |
      | 8      |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | status | open    |
      | state  | open    |
    And the task from the issue "I_8" reads:
      | status | open |
    And the GitHub issue sync records no failure

    Examples:
      | state   |
      | deleted |
      | moved   |

  Scenario: An issue moved to another repository cancels the old task and imports the new one once
    Given the tasks tracking issues:
      | title | number |
      | Old   | 7      |
    And the task "Old" holds the synced comment "IC_1"
    And GitHub cannot find the issues it is asked to look up
    And GitHub moves the REST path "aaronmallen/aaronmallen.me/issues/7" to "{stub}/github/api/repos/aaronmallen/elsewhere/issues/3"
    And GitHub answers the REST path "aaronmallen/elsewhere/issues/3" with:
      """
      {"html_url": "https://github.com/aaronmallen/elsewhere/issues/3"}
      """
    And GitHub assigns me the issues:
      | id   | number | repo                  | comments |
      | I_3  | 3      | aaronmallen/elsewhere | IC_1     |
    When the GitHub issue sync runs twice
    Then the task from the issue "I_7" reads:
      | status | canceled |
    And the task from the issue "I_3" reads:
      | list   | external                                       |
      | status | open                                           |
      | url    | https://github.com/aaronmallen/elsewhere/issues/3 |
    And the task from the issue "I_3" holds the comments:
      | id   |
      | IC_1 |
    And 2 tasks come from GitHub

  Scenario: An issue moved away that is no longer mine imports nothing
    Given the tasks tracking issues:
      | title | number |
      | Old   | 7      |
    And GitHub cannot find the issues it is asked to look up
    And GitHub moves the REST path "aaronmallen/aaronmallen.me/issues/7" to "{stub}/github/api/repos/aaronmallen/elsewhere/issues/3"
    And GitHub answers the REST path "aaronmallen/elsewhere/issues/3" with:
      """
      {"html_url": "https://github.com/aaronmallen/elsewhere/issues/3"}
      """
    When the GitHub issue sync runs
    Then 1 tasks come from GitHub

  Scenario: A check GitHub fails is recorded rather than cancel the task, and the next run catches up
    Given the tasks tracking issues:
      | title   | number |
      | Tracked | 7      |
    And GitHub answers the next issue lookup with status 500
    And GitHub knows the issues:
      | number | state  |
      | 7      | CLOSED |
    When the GitHub issue sync runs
    Then the GitHub issue sync records the failure "github_failed"
    And the task from the issue "I_7" reads:
      | status | open |
    When the GitHub issue sync runs
    Then the GitHub issue sync records no failure
    And the task from the issue "I_7" reads:
      | status | done |

  Scenario: A deleted issue's check GitHub fails is recorded rather than cancel the task
    Given the tasks tracking issues:
      | title   | number |
      | Tracked | 7      |
    And GitHub cannot find the issues it is asked to look up
    And GitHub answers the REST path "aaronmallen/aaronmallen.me/issues/7" with status 500
    When the GitHub issue sync runs
    Then the GitHub issue sync records the failure "github_failed"
    And the task from the issue "I_7" reads:
      | status | open |

  Scenario: A search or check GitHub answers with no viewer is recorded rather than acted on
    Given the tasks tracking issues:
      | title   | number |
      | Tracked | 7      |
    And GitHub answers the next issue search with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2030-01-01T00:00:00Z"},
        "search": {"nodes": [], "pageInfo": {"endCursor": null, "hasNextPage": false}}}}
      """
    When the GitHub issue sync runs
    Then the GitHub issue sync records the failure "github_failed"
    And the GitHub issue sync failure message holds "no viewer"
    Given GitHub answers the next issue lookup with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2030-01-01T00:00:00Z"}, "nodes": [null]}}
      """
    When the GitHub issue sync runs
    Then the GitHub issue sync failure message holds "no viewer"
    And the task from the issue "I_7" reads:
      | status | open |

  Scenario: A tracked task deleted while the run waits on GitHub lets the rest import
    Given the tasks tracking issues:
      | title   | number |
      | Doomed  | 7      |
    And GitHub assigns me the issues:
      | number | title   |
      | 7      | Renamed |
      | 8      |         |
    And GitHub rate limits the next issue search
    When the GitHub issue sync runs
    Given the task "Doomed" is deleted while GitHub's search runs
    When the GitHub issue sync runs
    Then the task from the issue "I_8" reads:
      | status | open |
    And the GitHub issue sync records no failure
