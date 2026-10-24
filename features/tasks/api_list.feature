Feature: Listing tasks through the API
  GET /api/v1/tasks lists tasks in every status, newest first, and narrows them by status, list, tag, words,
  window, sprint day and contributor.

  Background:
    Given an API token

  Scenario: The task list narrows by status, list, tag, words and window
    Given the tasks with their times:
      | title              | list     | status      | tags  | note          | made      | closed     |
      | older              | next     | open        |       |               | today - 2 |            |
      | started            | next     | in_progress |       |               | today - 1 |            |
      | idea               | someday  | open        | admin | about the feed | today - 3 |           |
      | poking at it       | someday  | in_progress |       |               | today - 4 |            |
      | settled            | someday  | done        |       |               | today - 9 | today - 8  |
      | issue              | external | open        |       |               | today - 4 |            |
      | Fix the feed       | next     | open        | admin |               | today - 3 |            |
      | Fix the feed later | next     | open        | ruby  |               | today - 3 |            |
      | finished           | next     | done        |       |               | today - 30 | today     |
      | dropped            | next     | canceled    |       |               | today - 30 | today - 20 |
    Then the API lists these tasks:
      | query                                | titles                                                                                         |
      |                                      | finished, started, older, Fix the feed later, Fix the feed, idea, issue, poking at it, settled, dropped |
      | statuses[]=done&statuses[]=canceled  | finished, settled, dropped                                                                     |
      | statuses=open,in_progress            | started, older, Fix the feed later, Fix the feed, idea, issue, poking at it                    |
      | statuses=canceled                    | dropped                                                                                        |
      | lists=someday,external               | idea, issue, poking at it                                                                      |
      | lists=someday                        | idea, poking at it                                                                             |
      | lists=someday&statuses=done          | settled                                                                                        |
      | tag=admin&query=feed                 | Fix the feed, idea                                                                             |
      | tag=%20Admin%20                      | Fix the feed, idea                                                                             |
      | query=feed                           | Fix the feed later, Fix the feed, idea                                                         |
      | from={day:today - 5}&to={day:today}  | finished, started, older, Fix the feed later, Fix the feed, idea, issue, poking at it          |
      | from={day:today - 1}                 | finished, started                                                                              |
      | window_by=closed&from={day:today - 5}&to={day:today} | finished                                                                       |
      | window_by=closed&from={day:today - 9} | finished, settled                                                                             |
      | lists=someday&tag=admin&query=feed&statuses=open&from={day:today - 5} | idea                                                          |

  Scenario: The task list carries each task's tags, links, source and times
    Given the tasks with their times:
      | title    | status | tags  | made      | closed | changed     |
      | blocker  | open   |       | today - 1 |        | today 15:00 |
      | finished | done   | admin | today - 1 | today  | today 16:00 |
    And the task "blocker" blocks the task "finished"
    And the task sources:
      | task    | url                                                    |
      | blocker | https://github.com/aaronmallen/aaronmallen.me/issues/7 |
    When I GET "/tasks" through the API
    Then the API answer holds:
      """
      {
        "tasks": [
          {
            "title": "finished",
            "status": "done",
            "tags": ["admin"],
            "completed_at": "{at:today 12:00}",
            "updated_at": "{at:today 16:00}",
            "source": null,
            "links": [{ "label": "blocked_by", "title": "blocker" }]
          },
          {
            "title": "blocker",
            "updated_at": "{at:today 15:00}",
            "source": { "reference": "aaronmallen/aaronmallen.me#7" },
            "links": [{ "label": "blocks", "title": "finished" }]
          }
        ]
      }
      """
    And the API answer has "tasks.0.type" as "undefined"

  Scenario: The task list refuses filters it cannot read
    Then the API calls answer:
      | call                                                 | body | status | holds                                                                  |
      | GET /tasks?from={day:today}&to={day:today - 1}       |      | 422    | {"error": "invalid", "message": "from comes after to", "errors": {"from": ["from comes after to"], "to": ["from comes after to"]}} |
      | GET /tasks?from=last%20week                          |      | 422    | {"message": "give from and to as days, such as 2026-01-01"}            |
      | GET /tasks?statuses=lost                             |      | 422    | "statuses"                                                             |
      | GET /tasks?lists=nowhere                             |      | 422    | "lists"                                                                |
      | GET /tasks?window_by=made                            |      | 422    |                                                                        |
      | GET /tasks?contributor=someone                       |      | 422    | "contributor"                                                          |
      | GET /tasks?sprint_on=soon                            |      | 422    | "sprint_on"                                                            |
      | GET /tasks?page=0                                    |      | 422    | "page"                                                                 |
      | GET /tasks?page=two                                  |      | 422    | "page"                                                                 |

  Scenario: The task list answers a page at a time and counts every match
    Given 101 more open tasks
    And the tasks:
      | title | status |
      | done  | done   |
    Then the API calls answer:
      | call                          | body | status | holds                                                   |
      | GET /tasks                    |      | 200    | {"count": 100, "partial": true, "next_page": 2, "total": 102} |
      | GET /tasks?page=2             |      | 200    | {"count": 2, "partial": false, "total": 102}            |
      | GET /tasks?statuses=done      |      | 200    | {"count": 1, "total": 1}                                |
      | GET /tasks?statuses=open&page=2 |    | 200    | {"count": 1, "partial": false, "total": 101}            |

  Scenario: A GitHub style query narrows the task list
    Given the projects:
      | name    | key |
      | Podcast | POD |
    And the tasks with their times:
      | title            | status      | stage | tags     | note        | project | made      | closed |
      | Record the intro | open        |       |          |             | Podcast | today - 9 |        |
      | Mow the lawn     | open        |       |          | after POD-1 |         | today - 8 |        |
      | bug              | open        |       | bug      |             |         | today - 7 |        |
      | docs             | open        |       | docs     |             |         | today - 6 |        |
      | both             | open        |       | bug docs |             |         | today - 5 |        |
      | ready            | open        | ready |          |             |         | today - 4 |        |
      | doing            | in_progress | ready |          |             |         | today - 3 |        |
      | closed           | done        |       |          |             |         | today - 30 | today - 30 |
      | dropped          | canceled    |       |          |             |         | today - 30 | today - 30 |
    And the task "closed" blocks the task "ready"
    And the task "Mow the lawn" blocks the task "doing"
    Then the API lists these tasks:
      | query                          | titles                                                     |
      | query=pod-1                    | Record the intro, Mow the lawn                             |
      | query=label:bug,docs           | both, docs, bug                                            |
      | query=l:Docs                   | both, docs                                                 |
      | query=-label:bug               | doing, ready, docs, Mow the lawn, Record the intro, dropped, closed |
      | query=no:label                 | doing, ready, Mow the lawn, Record the intro, dropped, closed |
      | query=-no:label                | both, docs, bug                                            |
      | query=is:closed                | dropped, closed                                            |
      | query=is:doing                 | doing                                                      |
      | query=is:blocked               | doing                                                      |
      | query=-is:blocked              | ready, both, docs, bug, Mow the lawn, Record the intro, dropped, closed |
      | query=column:ready             | ready                                                      |
      | query=col:%22in%20progress%22  | doing                                                      |
      | query=-col:backlog             | doing, ready, dropped, closed                                         |
      | query=%233                     | docs                                                       |
      | query=3                        | docs                                                       |
    When I GET "/tasks?query=label:bug%20author:me%20-is:soon%20col:nowhere%20no:tags%20column:later%20label:," through the API
    Then the API answer holds:
      """
      { "ignored": ["author:me", "-is:soon", "col:nowhere", "no:tags", "column:later", "label:,"] }
      """
    When I GET "/tasks?query=is:open" through the API
    Then the API answer holds:
      """
      { "ignored": [] }
      """

  Scenario: A query joins its terms and finds a quoted phrase whole
    Given the tasks:
      | title              | status      | tags | note  |
      | Fix the feed       | in_progress | bug  | today |
      | Fix the feed again | open        | bug  | today |
      | the feed, fix it   | in_progress | bug  | today |
    Then the API lists these tasks:
      | query                                        | titles       |
      | query=%22fix%20the%22%20today%20label:bug%20is:doing | Fix the feed |

  Scenario: The task list narrows by contributor
    Given the tasks:
      | title           |
      | mine by default |
      | mine            |
      | claude          |
      | sonnet          |
      | codex           |
      | shared          |
    And the task contributors:
      | task   | agent       | model             |
      | mine   |             |                   |
      | claude | claude-code | claude-opus-5-5   |
      | sonnet | claude-code | claude-sonnet-5   |
      | codex  | codex       | gpt-6             |
      | shared |             |                   |
      | shared | claude-code | claude-opus-5-5   |
    Then the API lists these tasks:
      | query                                                        | titles                       |
      | contributor=owner                                            | shared, mine, mine by default |
      | contributor=agent                                            | shared, codex, sonnet, claude |
      | agent=%20Codex%20                                            | codex                        |
      | model=claude-opus-5-5                                        | shared, claude               |
      | contributor=owner&agent=claude-code&model=claude-opus-5-5    | shared                       |
      | agent=nobody                                                 |                              |

  Scenario: The task list narrows to a sprint day
    Given the tasks:
      | title          | sprint    | status |
      | planned        | today + 2 | open   |
      | finished early | today + 2 | done   |
      | another day    | today + 3 | open   |
      | on a list      |           | open   |
    Then the API lists these tasks:
      | query                                 | titles                  |
      | sprint_on={day:today + 2}             | finished early, planned |
      | sprint_on={day:today + 9}             |                         |
    And the API calls answer:
      | call                                          | body | status | holds                 |
      | GET /tasks?sprint_on={day:today + 2}&statuses=open | | 200    | {"count": 1, "total": 1} |

  Scenario: Listing tasks leaves today's sprint unclaimed
    Given the tasks:
      | title | list    | tags  |
      | idea  | someday | admin |
    When I GET "/tasks?lists=someday&tag=admin&query=x" through the API
    Then the database answers "0" for:
      """
      SELECT count(*) FROM sprints
      """
