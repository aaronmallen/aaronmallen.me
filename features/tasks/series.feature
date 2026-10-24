Feature: Recurring tasks
  A task on a cadence makes its next copy when it closes. The recurring tab lists each series once, and its
  switch pauses and resumes it. The API sets, shows, clears, pauses and resumes a cadence.

  Background:
    Given I am signed in to the admin
    And an API token
    And the tasks:
      | title            |
      | Water the plants |

  Scenario: The recurring tab follows external with its count and lists each series once
    Given the task "Water the plants" repeats every 3 days
    When I send the admin form "/admin/tasks/{task:Water the plants}/complete" with:
      | filter | next |
    And I visit "/admin/tasks?filter=recurring"
    Then the recurring tab follows the external tab, counting "1"
    And the page has 1 of ".series-row"
    And the page part ".series-row a:text-is('Water the plants')" has "href" set to "/admin/tasks/2"
    And the page part ".series-row" holds "Every 3 days · next"
    And the page part ".series-row" holds the long day "today + 3"
    And the page box ".series-row input[type='checkbox'][name='on']" is ticked
    And the page part ".series-row form" has "action" set to "/admin/tasks/series/1/switch"
    And the page has ".series-row form[method='post'][data-autosubmit][data-morph] input[type='hidden'][name='_csrf_token']"
    And the page has no axe breaches in light or dark

  Scenario: The recurring tab says when nothing repeats
    When I visit "/admin/tasks?filter=recurring"
    Then the page part "main" holds "Nothing repeats yet. Pick a cadence in a task's Repeats field."

  Scenario: An open copy outside a sprint has no date yet
    Given the task_series table holds the rows:
      | task_id                | cadence   |
      | {task:Water the plants} | month_end |
    When I visit "/admin/tasks?filter=recurring"
    Then the page part ".series-row" holds "Last day of each month · not in a sprint"

  Scenario Outline: The recurring tab describes <text>
    Given the task_series table holds the rows:
      | task_id                | cadence   | every   | weekday   | week   | day   | month   | starts_on |
      | {task:Water the plants} | <cadence> | <every> | <weekday> | <week> | <day> | <month> | <starts>  |
    When I visit "/admin/tasks?filter=recurring"
    Then the page part ".series-row .series-meta" holds "<text>"

    Examples:
      | cadence       | every | weekday | week | day | month | starts     | text                           |
      | days          | 1     |         |      |     |       |            | Every day                      |
      | weeks         | 1     | 4       |      |     |       | 2026-10-01 | Every Thursday                 |
      | weeks         | 2     | 4       |      |     |       | 2026-10-01 | Every 2 weeks on Thursday      |
      | month_day     |       |         |      | 1   |       |            | Day 1 of each month            |
      | month_weekday |       | 1       | 1    |     |       |            | The first Monday of each month |
      | month_weekday |       | 5       | -1   |     |       |            | The last Friday of each month  |
      | yearly        |       |         |      | 4   | 3     |            | Each year on March 4           |

  Scenario: Pausing a series keeps its cadence and makes no copy when its copy closes
    Given the task "Water the plants" repeats every 1 days
    When I send the admin form "/admin/tasks/series/1/switch" with:
      | on | 0 |
    Then the admin answer goes to "/admin/tasks?filter=recurring"
    And the database reads "true, days, 1, 1" for:
      """
      SELECT paused, cadence, every, task_id FROM task_series
      """
    When I visit "/admin/tasks?filter=recurring"
    Then the page box ".series-row input[type='checkbox'][name='on']" is not ticked
    When I send the admin form "/admin/tasks/{task:Water the plants}/complete" with:
      | filter | next |
    Then the database reads "1" for:
      """
      SELECT task_id FROM task_series
      """
    When I visit "/admin/tasks?filter=recurring"
    Then the page part ".series-row" holds the long day "today + 1"
    When I send the admin form "/admin/tasks/series/1/switch" with:
      | on | 1 |
    Then the database reads "false, 2" for:
      """
      SELECT paused, task_id FROM task_series
      """
    When I send the admin form "/admin/tasks/series/0/switch" with:
      | on | 1 |
    Then the server answers 404

  Scenario: Resuming a series whose copy is open makes nothing
    Given the task "Water the plants" repeats every 1 days
    When I send the admin form "/admin/tasks/series/1/switch" with:
      | on | 0 |
    And I send the admin form "/admin/tasks/series/1/switch" with:
      | on | 1 |
    Then the database reads "false, 1" for:
      """
      SELECT paused, task_id FROM task_series
      """

  Scenario: A paused series counts its next date from a closed copy's day still ahead
    Given the tasks:
      | title | sprint    |
      | Ahead | today + 3 |
    And the task "Ahead" repeats every 2 days
    When I send the admin form "/admin/tasks/series/1/switch" with:
      | on | 0 |
    And I send the admin form "/admin/tasks/{task:Ahead}/complete" with:
      | filter | upcoming |
    And I visit "/admin/tasks?filter=recurring"
    Then the page part ".series-row" holds the long day "today + 5"

  Scenario Outline: The API captures and changes a task on a <cadence> cadence
    Given the task "Water the plants" repeats every 9 days
    Then the API calls answer:
      | call                               | body                                                               | status | holds |
      | POST /tasks                         | {"title": "Rent", "recur": {"cadence": "<cadence>"<fields>}}      | 201    | {"recur": {"cadence": "<cadence>"<fields>}} |
      | PATCH /tasks/{task:Water the plants} | {"recur": {"cadence": "<cadence>"<fields>}}                      | 200    | {"recur": {"cadence": "<cadence>"<fields>}} |

    Examples:
      | cadence       | fields                                                 |
      | days          | , "every": 3                                           |
      | weeks         | , "every": 2, "weekday": 4, "starts_on": "2026-10-01"  |
      | month_day     | , "day": 31                                            |
      | month_end     |                                                        |
      | month_weekday | , "week": -1, "weekday": 5                             |
      | yearly        | , "month": 2, "day": 29                                |

  Scenario: The API starts a weekly cadence today, keeps one a save leaves out and clears one with null
    Given the task "Water the plants" repeats every 3 days
    Then the API calls answer:
      | call                               | body                                                        | status | holds |
      | POST /tasks                         | {"title": "Review", "recur": {"cadence": "weeks", "every": 1, "weekday": 4}} | 201 | {"recur": {"starts_on": "{day:today}"}} |
      | PATCH /tasks/{task:Water the plants} | {"title": "Renamed"}                                       | 200    | {"recur": {"cadence": "days", "every": 3}} |
      | GET /tasks/{task:Renamed}            |                                                            | 200    | {"recur": {"cadence": "days", "every": 3}} |
      | GET /tasks?query=Renamed             |                                                            | 200    | {"tasks": [{"recur": {"cadence": "days", "every": 3}}]} |
      | PATCH /tasks/{task:Renamed}          | {"recur": null}                                            | 200    | {"recur": null} |
      | GET /tasks/{task:Renamed}            |                                                            | 200    | {"recur": null} |
      | PATCH /tasks/{task:Renamed}          | {"recur": null}                                            | 200    | {"recur": null} |
    And the database holds 1 task_series row

  Scenario: The API refuses a cadence it cannot keep and saves nothing
    Given the tasks:
      | title        | list     | status |
      | Fix the feed | external | open   |
      | Done copy    | next     | done   |
    And the task sources:
      | task         | url                                                    |
      | Fix the feed | https://github.com/aaronmallen/aaronmallen.me/issues/8 |
    And the task "Done copy" repeats every 1 days
    And the task "Done copy" moved on to a newer copy
    Then the API calls answer:
      | call                           | body                                                              | status | holds |
      | POST /tasks                     | {"title": "Pay rent", "recur": {"cadence": "yearly", "month": 2}} | 422    | {"errors": {"day": ["month_day and yearly need a day"]}} |
      | POST /tasks                     | {"title": "Pay rent", "recur": {"cadence": "yearly", "month": 2, "day": 30}} | 422 | {"errors": {"day": ["that month has fewer days"]}} |
      | PATCH /tasks/{task:Fix the feed} | {"title": "Renamed", "recur": {"cadence": "month_end"}}           | 422    | {"errors": {"recur": ["an imported task cannot recur"]}} |
      | PATCH /tasks/3                   | {"recur": {"cadence": "days", "every": 2}}                        | 422    | {"errors": {"cadence": ["its series has moved on to a newer copy; set the cadence there"]}} |
    And the database reads "Water the plants / Fix the feed / Done copy / Done copy" for:
      """
      SELECT title FROM tasks ORDER BY id
      """
    And the database holds 1 task_series row

  Scenario: The API lists, pauses and resumes a series
    Given the task "Water the plants" repeats every 2 days
    Then the API calls answer:
      | call                      | body | status | holds |
      | GET /tasks/{task:Water the plants} |  | 200 | {"recur": {"cadence": "days", "every": 2}} |
      | GET /task_series           |      | 200    | {"task_series": [{"id": 1, "cadence": "days", "every": 2, "paused": false, "task": {"id": 1, "title": "Water the plants", "status": "open", "sprint_on": null}}]} |
      | POST /task_series/1/pause  |      | 200    | {"paused": true} |
      | POST /task_series/1/resume |      | 200    | {"paused": false, "task": {"id": 1}} |
      | POST /task_series/1/pause  |      | 200    | {"paused": true} |
      | POST /tasks/1/complete     | {}   | 200    | {"status": "done"} |
    And the database holds 1 tasks row
    And the API calls answer:
      | call                       | body | status | holds |
      | POST /task_series/1/resume  |      | 200    | {"paused": false, "task": {"status": "open", "sprint_on": "{day:today + 2}"}} |
      | POST /task_series/999/pause |      | 404    | |
      | POST /task_series/999/resume |     | 404    | |
    And the database holds 2 tasks rows
