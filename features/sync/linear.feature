Feature: The Linear issue sync
  The sync imports the Linear issues assigned to me in every workspace I hold a key for, and moves their tasks as
  the issues start, finish, move or go.

  Background:
    Given Linear holds the keys "lin_api_one"

  Scenario: A new issue assigned to me becomes one unseen task on the external list
    Given Linear assigns me the issues:
      | key   | title       | description         |
      | ABC-1 | Sync Linear | Keep Linear in step |
    When the Linear issue sync runs twice
    Then the task from the issue "L_1" reads:
      | title  | Sync Linear                                              |
      | note   | Keep Linear in step                                      |
      | list   | external                                                 |
      | status | open                                                     |
      | tags   |                                                          |
      | seen   | false                                                    |
      | url    | https://linear.app/aaronmallen/issue/abc-1/sync-my-issues |
    And the synced issues are "L_1"
    And Linear was sent a query holding "{state: {type: {nin: [\"completed\", \"canceled\"]}}}"
    And Linear was sent a query holding "first: 25"
    And Linear was sent a query holding "assignedIssues(" with the key "lin_api_one"
    And Linear received POST "/graphql" with the headers:
      | Authorization | lin_api_one |
    And the Linear issue sync records no failure

  Scenario: A run clears the failure the last run left, and a failure leaves GitHub alone
    Given Linear assigns me the issues:
      | key   |
      | ABC-1 |
    And Linear refuses the next assigned query with "RATELIMITED" saying "Linear said no"
    When the Linear issue sync runs
    Then the Linear issue sync records the failure "rate_limited"
    And the GitHub issue sync records no failure
    When the Linear issue sync runs
    Then the Linear issue sync records no failure

  Scenario: A new issue already started arrives in progress, once, with a work session
    Given Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | started |
    When the Linear issue sync runs twice
    Then the task from the issue "L_1" reads:
      | list   |             |
      | status | in_progress |
      | state  | started     |
      | seen   | false       |
    And the synced issues are "L_1"
    And the work sessions of the task from the issue "L_1" read "0 to open"

  Scenario: Labels become the private tags they name, a grouped label by its own name
    Given the private tags "bug-fix, needs-review, type-bug-fix"
    And Linear assigns me the issues:
      | key   | labels                        |
      | ABC-1 | Bug Fix, needs review, BugFix |
      | ABC-2 | Type/Bug Fix                  |
      | ABC-3 | area/api, Someday             |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | tags | bug-fix, needs-review |
    And the task events from the issue "L_1" read "tagged bug-fix, tagged needs-review"
    And the task from the issue "L_2" reads:
      | tags | bug-fix |
    And the task from the issue "L_3" reads:
      | tags |  |

  Scenario: Rules for a team and a workspace tag a new issue, and only Linear rules count
    Given an API token
    And the private tags "bug-fix"
    And the saved task rules:
      | pattern  | tags           | provider |
      | acme/eng | ruby, hanami   | linear   |
      | acme/*   | projects, ruby | linear   |
      | acme/*   | github         | github   |
    And Linear assigns me the issues:
      | key    | workspace | labels  |
      | ENG-12 | acme      | Bug Fix |
      | OPS-3  | acme      |         |
      | ENG-13 | octocat   |         |
    When the Linear issue sync runs
    Then the task from the issue "L_12" reads:
      | tags | bug-fix, hanami, projects, ruby |
    And the task from the issue "L_3" reads:
      | tags | projects, ruby |
    And the task from the issue "L_13" reads:
      | tags |  |

  Scenario: Rule tags land only on import
    Given an API token
    And the saved task rules:
      | pattern  | tags | provider |
      | acme/eng | ruby | linear   |
    And the tasks tracking issues:
      | title          | provider | issue  | key    | workspace |
      | Sync my issues | linear   | L_12   | ENG-12 | acme      |
    And Linear assigns me the issues:
      | key    | workspace |
      | ENG-12 | acme      |
    When the Linear issue sync runs
    Then the task from the issue "L_12" reads:
      | tags |  |

  Scenario: An issue filed into a project takes its labels as the project's tags
    Given an API token
    And the projects:
      | name | key |
      | Pod  | POD |
    And the private tags "bug-fix"
    And the saved task rules:
      | pattern       | projects | provider |
      | aaronmallen/* | Pod      | linear   |
    And Linear assigns me the issues:
      | key   | labels  |
      | ABC-1 |         |
      | ABC-2 | Bug Fix |
    When the Linear issue sync runs
    And Linear assigns me the issues:
      | key   | labels  |
      | ABC-1 | Bug Fix |
      | ABC-2 |         |
    And the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | tags    | bug-fix@POD |
      | project | Pod         |
    And the task events from the issue "L_1" read "tagged bug-fix"
    And the task from the issue "L_2" reads:
      | tags | bug-fix@POD |

  Scenario: Issues in every workspace I hold a key for become one task each
    Given Linear holds the keys "lin_api_two"
    And Linear assigns me the issues:
      | key   | in          |
      | ABC-1 | lin_api_one |
      | XYZ-2 | lin_api_two |
    When the Linear issue sync runs
    Then the synced issues are "L_1, L_2"

  Scenario: An issue edited on Linear moves its task in step, and one moved to another team keeps its task
    Given the tasks tracking issues:
      | title | note     | provider | issue | key   |
      | Old   | Old body | linear   | L_1   | ABC-1 |
    And Linear assigns me the issues:
      | id  | key   | title | description |
      | L_1 | XYZ-9 | New   | New body    |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | title | New                                                       |
      | note  | New body                                                  |
      | url   | https://linear.app/aaronmallen/issue/xyz-9/sync-my-issues |
    And the synced issues are "L_1"

  Scenario: An issue whose title is blank once cleaned takes its key until it has a title
    Given Linear assigns me the issues:
      | key   | title         |
      | ABC-1 | \u0000 \u0000 |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | title | ABC-1 |
    When Linear assigns me the issues:
      | key   | title         | description |
      | ABC-1 | \u0000        | New body    |
    And the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | title | ABC-1    |
      | note  | New body |
    When Linear assigns me the issues:
      | key   | title        |
      | ABC-1 | Sync my work |
    And the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | title | Sync my work |

  Scenario: Comments arrive with author, body, time and link, follow edits and deletes, and keep what a cut list leaves out
    Given Linear assigns me the issues:
      | key   | comments |
      | ABC-1 | c1 c2    |
      | ABC-2 | c4       |
      | ABC-3 | c6 c7    |
    And the Linear issue "L_3" has the comments:
      | id | ago | author |
      | c6 | 15  | aaron  |
      | c7 | 10  | none   |
    When the Linear issue sync runs twice
    Then 5 task comments are stored
    And the task from the issue "L_3" holds the comments:
      | id | author | url                                                                 |
      | c6 | aaron  | https://linear.app/aaronmallen/issue/abc-1/sync-my-issues#comment-c6 |
      | c7 | none   | https://linear.app/aaronmallen/issue/abc-1/sync-my-issues#comment-c7 |
    When Linear assigns me the issues:
      | key   | comments |
      | ABC-1 | c2       |
      | ABC-2 | c4       |
      | ABC-3 | c7 c8    |
    And the Linear issue "L_2" has the comments:
      | id | body   |
      | c4 | Edited |
    And the Linear issue "L_3" has the comments:
      | id | ago |
      | c7 | 10  |
      | c8 | 5   |
    And the Linear issue "L_3" cuts its comments short
    And the Linear issue sync runs
    Then the task from the issue "L_1" holds the comments:
      | id |
      | c2 |
    And the task from the issue "L_2" holds the comments:
      | id | body   |
      | c4 | Edited |
    And the task from the issue "L_3" holds the comments:
      | id |
      | c6 |
      | c7 |
      | c8 |

  Scenario: Comments reach a tracked issue through the check by ID and a task its issue reopens, not one it cancels
    Given the tasks tracking issues:
      | title    | provider | issue | key   | status | state     |
      | Tracked  | linear   | L_1   | ABC-1 | open   | open      |
      | Finished | linear   | L_2   | ABC-2 | done   | completed |
      | Dropped  | linear   | L_3   | ABC-3 | open   | open      |
    And Linear assigns me the issues:
      | key   | comments |
      | ABC-2 | c2       |
    And Linear knows the issues:
      | key   | comments | state    |
      | ABC-1 | c1       | started  |
      | ABC-3 | c3       | canceled |
    When the Linear issue sync runs
    Then the task from the issue "L_1" holds the comments:
      | id |
      | c1 |
    And the task from the issue "L_2" holds the comments:
      | id |
      | c2 |
    And the task from the issue "L_3" holds no comments

  Scenario Outline: A <relation> relation becomes a <link> link
    Given Linear assigns me the issues:
      | key   | relations          |
      | ABC-1 | <relation> L_2     |
      | ABC-2 |                    |
    When the Linear issue sync runs
    Then the task links read "L_1 <link> L_2 synced"

    Examples:
      | relation  | link       |
      | blocks    | blocks     |
      | related   | relates    |
      | duplicate | duplicates |

  Scenario: Every kind of relation and the parent link come from the issue's side, and similar ones are left out
    Given Linear assigns me the issues:
      | key   | parent | children | relations                          | inverse                                  |
      | ABC-1 | L_9    | L_8      | similar L_7                        | blocks L_6; related L_5; duplicate L_4; similar L_3 |
      | ABC-9 |        | L_1      |                                    |                                          |
      | ABC-8 |        |          |                                    |                                          |
      | ABC-6 |        |          |                                    |                                          |
      | ABC-5 |        |          |                                    |                                          |
      | ABC-4 |        |          |                                    |                                          |
      | ABC-3 |        |          |                                    |                                          |
      | ABC-7 |        |          |                                    |                                          |
    When the Linear issue sync runs
    Then the task links read "L_1 parent L_8 synced | L_1 relates L_5 synced | L_4 duplicates L_1 synced | L_6 blocks L_1 synced | L_9 parent L_1 synced"
    And Linear was sent a query holding "children(first: 10)"
    And Linear was sent a query holding "relations(first: 10)"
    And Linear was sent a query holding "inverseRelations(first: 10)"
    And Linear was sent 0 queries holding "issue(id:"

  Scenario: A parent with more children than a page holds reads them on their own and imports each
    Given Linear assigns me the issues:
      | key   | children                                                   |
      | ABC-1 | L_2; L_3; L_4; L_5; L_6; L_7; L_8; L_9; L_10; L_11; +more |
    And Linear holds the children "L_2; L_3; L_4; L_5; L_6; L_7; L_8; L_9; L_10; L_11; L_12" of "L_1" on their own
    And Linear knows the issues:
      | key    | assignee |
      | ABC-2  | none     |
      | ABC-3  | none     |
      | ABC-4  | none     |
      | ABC-5  | none     |
      | ABC-6  | none     |
      | ABC-7  | none     |
      | ABC-8  | none     |
      | ABC-9  | none     |
      | ABC-10 | none     |
      | ABC-11 | none     |
      | ABC-12 | none     |
    When the Linear issue sync runs
    Then the database soon holds "11" for:
      """
      SELECT count(*) FROM task_links WHERE type = 'parent'
      """
    And Linear was sent a query holding "children(first: 250)"

  Scenario: Relations that run past a page of 250 are left out
    Given the tasks tracking issues:
      | title  | provider | issue | key   |
      | Linked | linear   | L_1   | ABC-1 |
      | Other  | linear   | L_2   | ABC-2 |
    And the database runs:
      """
      INSERT INTO task_links (from_task_id, to_task_id, type, synced) VALUES ({task:Linked}, {task:Other}, 'blocks', true)
      """
    And Linear assigns me the issues:
      | key   | children   |
      | ABC-1 | L_9; +more |
    And Linear knows the issues:
      | key   | children   |
      | ABC-2 | L_8; +more |
    And Linear holds the children "L_9; +more" of "L_1" on their own
    And Linear holds the children "L_8; +more" of "L_2" on their own
    When the Linear issue sync runs
    Then the task links read "L_1 blocks L_2 synced"

  Scenario: The other end that is not here imports, links and stays open
    Given Linear assigns me the issues:
      | key   | relations  |
      | ABC-1 | blocks L_2 |
    And Linear knows the issues:
      | key   | assignee     |
      | ABC-2 | someone else |
    When the Linear issue sync runs twice
    Then the task from the issue "L_2" reads:
      | status | open |
    And the task links read "L_1 blocks L_2 synced"

  Scenario: An issue that starts puts its task in progress in Today, ahead of every other, still unseen
    Given the tasks:
      | title   | status      | sprint |
      | Working | in_progress | today  |
    And the tasks tracking issues:
      | title          | provider | issue | key   |
      | Sync my issues | linear   | L_1   | ABC-1 |
    And Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | started |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | list   |             |
      | status | in_progress |
      | sprint | {day:today} |
      | seen   | false       |
    And the task from the issue "L_1" comes first
    And the work sessions of the task from the issue "L_1" read "0 to open"
    And the status changes of the task from the issue "L_1" read "open to in_progress"

  Scenario: An issue that reopens puts its task ahead of every other and takes comments again
    Given the tasks:
      | title |
      | Other |
    And the tasks tracking issues:
      | title          | provider | issue | key   | status | state     |
      | Sync my issues | linear   | L_1   | ABC-1 | done   | completed |
    And Linear assigns me the issues:
      | key   |
      | ABC-1 |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | open |
    And the task from the issue "L_1" comes first
    And the status changes of the task from the issue "L_1" read "done to open"

  Scenario Outline: An issue that moves back to <state> reopens its task in progress and ends its session
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status      | state   |
      | Sync my issues | linear   | L_1   | ABC-1 | in_progress | started |
    And the task "Sync my issues" has a work session from 60 minutes ago
    And Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | <state> |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | open |
    And the work sessions of the task from the issue "L_1" read "60 to 0"
    And the status changes of the task from the issue "L_1" read "in_progress to open"

    Examples:
      | state     |
      | triage    |
      | backlog   |
      | unstarted |

  Scenario Outline: An issue that is <state> settles its task <status> and ends its session with its length
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status      | state   |
      | Sync my issues | linear   | L_1   | ABC-1 | in_progress | started |
    And the task "Sync my issues" has a work session from 60 minutes ago
    And Linear knows the issues:
      | key   | state   |
      | ABC-1 | <state> |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | <status> |
    And the work sessions of the task from the issue "L_1" read "60 to 0"
    And the status changes of the task from the issue "L_1" read "in_progress to <status>"
    And the database soon holds "true" for:
      """
      SELECT worked_seconds BETWEEN 3595 AND 3610 FROM tasks
      """

    Examples:
      | state     | status   |
      | completed | done     |
      | canceled  | canceled |

  Scenario: An open task's issue that completes or cancels settles it
    Given the tasks tracking issues:
      | title | provider | issue | key   |
      | One   | linear   | L_1   | ABC-1 |
      | Two   | linear   | L_2   | ABC-2 |
      | Three | linear   | L_3   | ABC-3 |
    And Linear knows the issues:
      | key   | state     | assignee     |
      | ABC-1 | completed |              |
      | ABC-2 | canceled  |              |
      | ABC-3 | completed | someone else |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | done |
    And the task from the issue "L_2" reads:
      | status | canceled |
    And the status changes of the task from the issue "L_2" read "open to canceled"
    And the task from the issue "L_3" reads:
      | status | done |

  Scenario: A task I work on, closed upstream then reopened, stays in progress
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status      | state     |
      | Sync my issues | linear   | L_1   | ABC-1 | in_progress | completed |
    And Linear assigns me the issues:
      | key   |
      | ABC-1 |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | in_progress |

  Scenario: A started issue whose task I moved to a list leaves the task open there
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status | state   |
      | Sync my issues | linear   | L_1   | ABC-1 | open   | started |
    And Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | started |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | list   | external |
      | status | open     |

  Scenario Outline: A status I set by hand <outcome>
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status | state    |
      | Sync my issues | linear   | L_1   | ABC-1 | done   | <before> |
    And Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | <after> |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | <status> |

    Examples:
      | outcome                                    | before  | after     | status      |
      | holds while the issue stays in its state   | open    | unstarted | done        |
      | holds while the issue stays started        | started | started   | done        |
      | gives way when the issue goes back to open | started | unstarted | open        |
      | gives way when the issue's state changes   | open    | started   | in_progress |

  Scenario: The history starts the session when the issue went In Progress, not when the sync ran, and replays once
    Given the tasks tracking issues:
      | title          | provider | issue | key   | cursor |
      | Sync my issues | linear   | L_1   | ABC-1 | 60     |
    And Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | started |
    And Linear's history of "L_1" holds:
      | from      | to        | ago |
      | unstarted | started   | 14  |
      | started   | unstarted | 9   |
      | unstarted | started   | 4   |
    When the Linear issue sync runs twice
    Then the work sessions of the task from the issue "L_1" read "14 to 9, 4 to open"
    And Linear was sent 1 queries holding "history(first:"
    And the history cursor of the issue "L_1" sits 4 minutes ago

  Scenario: A start on an earlier day still lands the task in today's sprint, its session at Linear's time
    Given the tasks tracking issues:
      | title          | provider | issue | key   | cursor |
      | Sync my issues | linear   | L_1   | ABC-1 | 2000   |
    And Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | started |
    And Linear's history of "L_1" holds:
      | from      | to      | ago  |
      | unstarted | started | 1500 |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | sprint | {day:today} |
    And the work sessions of the task from the issue "L_1" read "1500 to open"

  Scenario Outline: The history ends the session at Linear's time when the issue is <state>
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status      | state   | cursor |
      | Sync my issues | linear   | L_1   | ABC-1 | in_progress | started | 60     |
    And the task "Sync my issues" has a work session from 44 minutes ago
    And Linear knows the issues:
      | key   | state   |
      | ABC-1 | <state> |
    And Linear's history of "L_1" holds:
      | from    | to      | ago |
      | started | <state> | 14  |
    When the Linear issue sync runs
    Then the work sessions of the task from the issue "L_1" read "44 to 14"
    And the task from the issue "L_1" reads:
      | status | <status> |

    Examples:
      | state     | status   |
      | completed | done     |
      | canceled  | canceled |

  Scenario: The history moves a session I started by hand to Linear's start and counts from there
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status      | cursor |
      | Sync my issues | linear   | L_1   | ABC-1 | in_progress | 60     |
    And the task "Sync my issues" has a work session from 12 minutes ago
    And Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | started |
    And Linear's history of "L_1" holds:
      | from      | to      | ago |
      | unstarted | started | 14  |
    When the Linear issue sync runs
    Then the work sessions of the task from the issue "L_1" read "14 to open"
    Given Linear assigns me the issues:
      | key   |
    And Linear knows the issues:
      | key   | state     |
      | ABC-1 | completed |
    And Linear's history of "L_1" holds:
      | from      | to        | ago |
      | unstarted | started   | 14  |
      | started   | completed | 4   |
    When the Linear issue sync runs
    Then the database soon holds "true" for:
      """
      SELECT worked_seconds BETWEEN 595 AND 605 FROM tasks
      """

  Scenario: The history keeps a session I started by hand before Linear's start
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status      | cursor |
      | Sync my issues | linear   | L_1   | ABC-1 | in_progress | 60     |
    And the task "Sync my issues" has a work session from 44 minutes ago
    And Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | started |
    And Linear's history of "L_1" holds:
      | from      | to      | ago |
      | unstarted | started | 14  |
    When the Linear issue sync runs
    Then the work sessions of the task from the issue "L_1" read "44 to open"

  Scenario: A status I set by hand holds when the history has no matching change
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status | cursor |
      | Sync my issues | linear   | L_1   | ABC-1 | done   | 60     |
    And Linear assigns me the issues:
      | key   |
      | ABC-1 |
    And Linear's issue "L_1" changed 14 minutes ago
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | done |

  Scenario: An issue with no history cursor replays nothing and takes a cursor at the time of the run
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status      |
      | Sync my issues | linear   | L_1   | ABC-1 | in_progress |
    And the task "Sync my issues" has a work session from 74 to 44 minutes ago
    And Linear assigns me the issues:
      | key   | state   |
      | ABC-1 | started |
    And Linear's history of "L_1" holds:
      | from      | to      | ago |
      | unstarted | started | 14  |
    When the Linear issue sync runs
    Then Linear was sent 0 queries holding "history(first:"
    And the history cursor of the issue "L_1" sits 0 minutes ago

  Scenario: The sync sends no history query when no tracked issue changed
    Given the tasks tracking issues:
      | title          | provider | issue | key   | cursor |
      | Sync my issues | linear   | L_1   | ABC-1 | 60     |
    And Linear assigns me the issues:
      | key   |
      | ABC-1 |
    And Linear's issue "L_1" changed 61 minutes ago
    When the Linear issue sync runs
    Then Linear was sent 0 queries holding "history(first:"

  Scenario: A deleted issue cancels its task, trashed or unknown, unless no key holds its workspace
    Given the tasks tracking issues:
      | title   | provider | issue | key   |
      | Trashed | linear   | L_1   | ABC-1 |
      | Unknown | linear   | L_2   | ABC-2 |
    And Linear knows the issues:
      | key   | trashed |
      | ABC-1 | yes     |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | canceled |
    And the task from the issue "L_2" reads:
      | status | canceled |

  Scenario: An issue in a workspace no key holds leaves its task alone
    Given the tasks tracking issues:
      | title   | provider | issue | key   |
      | Tracked | linear   | L_1   | ABC-1 |
    And Linear answers lookups in the workspace "elsewhere"
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | open |
      | state  | open |

  Scenario: Tracked issues in two workspaces are each found in their own, the second asked only for the rest
    Given Linear holds the keys "lin_api_two"
    And the tasks tracking issues:
      | title | provider | issue | key   | workspace   |
      | One   | linear   | L_1   | ABC-1 | aaronmallen |
      | Two   | linear   | L_2   | XYZ-2 | lin_api_two |
    And Linear knows the issues:
      | key   | in          | state     | workspace   |
      | ABC-1 | lin_api_one | unstarted | aaronmallen |
      | XYZ-2 | lin_api_two | completed | lin_api_two |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | state | open |
    And the task from the issue "L_2" reads:
      | state | completed |
    And Linear was asked to look up "L_2" with the key "lin_api_two"

  Scenario: A deleted issue assigned to me again reopens its task instead of importing another
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status   | state   |
      | Sync my issues | linear   | L_1   | ABC-1 | canceled | deleted |
    And Linear assigns me the issues:
      | key   |
      | ABC-1 |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | open |
    And the synced issues are "L_1"

  Scenario Outline: An issue checked an hour ago is not asked about while <state>
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status   | state   | checked |
      | Sync my issues | linear   | L_1   | ABC-1 | canceled | <state> | 60      |
    When the Linear issue sync runs
    Then Linear was asked to look up issues 0 times

    Examples:
      | state       |
      | completed   |
      | not_planned |
      | unassigned  |

  Scenario: An issue checked an hour ago is asked about again while started, and another provider's never
    Given the tasks tracking issues:
      | title   | provider | issue | key   | status      | state   | checked |
      | Started | linear   | L_1   | ABC-1 | in_progress | started | 60      |
      | GitHub  | github   | I_7   |       | open        | open    |         |
    And Linear knows the issues:
      | key   | state   |
      | ABC-1 | started |
    When the Linear issue sync runs
    Then Linear was asked to look up "L_1" with the key "lin_api_one"

  Scenario: Nothing tracked checks nothing, and more than 25 tracked are checked 25 at a time
    When the Linear issue sync runs
    Then Linear was asked to look up issues 0 times
    Given 26 tasks tracking Linear issues
    When the Linear issue sync runs
    Then Linear was asked to look up issues 2 times

  Scenario: An archived issue leaves its task as it was, and lookups take the archived
    Given the tasks tracking issues:
      | title          | provider | issue | key   | status | state     |
      | Sync my issues | linear   | L_1   | ABC-1 | done   | completed |
      | Open           | linear   | L_2   | ABC-2 | open   | open      |
    And Linear knows the issues:
      | key   | state     | archived |
      | ABC-1 | completed | yes      |
      | ABC-2 | unstarted |          |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status    | done |
      | completed | true |
    And Linear was sent a query holding "includeArchived: true"

  Scenario Outline: A run that meets <case> is recorded under linear_issues as <reason>
    Given the tasks tracking issues:
      | title   | provider | issue | key   |
      | Tracked | linear   | L_1   | ABC-1 |
    And <failure>
    When the Linear issue sync runs
    Then the Linear issue sync records the failure "<reason>"
    And the Linear issue sync failure message holds "<message>"
    And the task from the issue "L_1" reads:
      | status | open |

    Examples:
      | case               | failure                                                                                             | reason        | message                 |
      | a rate limit error | Linear refuses the next assigned query with "RATELIMITED" saying "Linear said no"                    | rate_limited  |                         |
      | a 429              | Linear answers the next assigned query with status 429                                              | rate_limited  |                         |
      | an auth error      | Linear refuses the next assigned query with "AUTHENTICATION_ERROR" saying "Authentication required" | linear_failed | Authentication required |
      | a failed check     | Linear answers the next lookup query with status 500                                                | linear_failed |                         |
      | a dropped link     | Linear drops the next assigned query                                                                | linear_failed | request failed          |

  Scenario: A check Linear answers with no viewer is recorded rather than cancel the task
    Given the tasks tracking issues:
      | title   | provider | issue | key   |
      | Tracked | linear   | L_1   | ABC-1 |
    And Linear answers the next lookup query with:
      """
      {"data": {"issues": {"nodes": []}}}
      """
    When the Linear issue sync runs
    Then the Linear issue sync records the failure "linear_failed"
    And the Linear issue sync failure message holds "no viewer"
    And the task from the issue "L_1" reads:
      | status | open |

  Scenario: A failure in one provider leaves the other to run
    Given GitHub holds a token for the issue sync
    And GitHub assigns me the issues:
      | number |
      | 7      |
    And Linear assigns me the issues:
      | key   |
      | ABC-1 |
    And Linear answers the next assigned query with status 500
    When the Linear issue sync runs
    And the GitHub issue sync runs
    Then the Linear issue sync records the failure "linear_failed"
    And the synced issues are "I_7"
    Given GitHub answers the next issue search with:
      """
      {}
      """
    When the GitHub issue sync runs
    And the Linear issue sync runs
    Then the GitHub issue sync records the failure "github_failed"
    And the Linear issue sync records no failure
    And the synced issues are "I_7, L_1"

  Scenario: A captured task and an imported one land on different positions
    Given an API token
    And Linear assigns me the issues:
      | key   |
      | ABC-1 |
    When a task is captured through the API and the Linear sync imports while another session holds the task lock
    Then the database soon holds "2" for:
      """
      SELECT count(DISTINCT position) FROM tasks
      """

  Scenario: The sync reads every page of assigned issues
    Given Linear assigns me 12 issues 1 a page
    When the Linear issue sync runs
    Then Linear was sent 12 queries holding "assignedIssues("
    And the database soon holds "12" for:
      """
      SELECT count(*) FROM task_sources WHERE provider = 'linear'
      """
    And the Linear issue sync records no failure

  Scenario: The sync stops when the next page cursor never moves
    Given Linear's assigned query keeps sending the same next page
    When the Linear issue sync runs
    Then Linear was sent 2 queries holding "assignedIssues("
    And the Linear issue sync records the failure "page_limit"

  Scenario: A tag I removed stays off, and a label added later adds no tag
    Given the private tags "bug-fix"
    And Linear assigns me the issues:
      | key   | labels  |
      | ABC-1 | Bug Fix |
      | ABC-2 |         |
    When the Linear issue sync runs
    And the database runs:
      """
      DELETE FROM task_tags
      """
    And Linear assigns me the issues:
      | key   | labels  |
      | ABC-1 | Bug Fix |
      | ABC-2 | Bug Fix |
    And the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | tags |  |
    And the task from the issue "L_2" reads:
      | tags |  |

  Scenario: Comments come to a task already tracked, leave my own alone and stop at a task I finished
    Given the tasks tracking issues:
      | title    | provider | issue | key   | status |
      | Tracked  | linear   | L_1   | ABC-1 | open   |
      | Finished | linear   | L_2   | ABC-2 | done   |
    And the task "Tracked" holds my comment "Mine"
    And Linear assigns me the issues:
      | key   | comments |
      | ABC-1 | c1       |
      | ABC-2 | c2       |
    When the Linear issue sync runs
    Then the task from the issue "L_1" holds the comments:
      | id   |
      | c1   |
      | mine |
    And the task from the issue "L_2" holds no comments

  Scenario: An issue taken off me cancels its task, and assigned back reopens it
    Given the tasks tracking issues:
      | title | provider | issue | key   | status   | state      |
      | Taken | linear   | L_1   | ABC-1 | open     | open       |
      | Back  | linear   | L_2   | ABC-2 | canceled | unassigned |
    And Linear assigns me the issues:
      | key   |
      | ABC-2 |
    And Linear knows the issues:
      | key   | assignee     |
      | ABC-1 | someone else |
    When the Linear issue sync runs
    Then the task from the issue "L_1" reads:
      | status | canceled |
    And the task from the issue "L_2" reads:
      | status | open |

  Scenario: A tracked task deleted while the run waits on Linear lets the rest import and clears the last failure
    Given the tasks tracking issues:
      | title  | provider | issue | key   |
      | Doomed | linear   | L_1   | ABC-1 |
    And Linear assigns me the issues:
      | key   | title   |
      | ABC-1 | Renamed |
      | ABC-2 |         |
    And Linear answers the next assigned query with status 429
    When the Linear issue sync runs
    Given the task "Doomed" is deleted while Linear's assigned query runs
    When the Linear issue sync runs
    Then the task from the issue "L_2" reads:
      | status | open |
    And the Linear issue sync records no failure
