Feature: A series makes its next copy
  Closing a copy makes the next one on the cadence's next day, carrying the title, note, tags, project and
  photos but not the history. A paused series makes none until it resumes.

  Background:
    Given an API token
    And the projects:
      | name    | key |
      | Podcast | POD |

  Scenario: Completing or canceling a copy makes the next one, marked as made by its series
    Given the tasks:
      | title  |
      | Plants |
      | Ferns  |
    And the task "Plants" repeats every 3 days
    And the task "Ferns" repeats every 1 days
    When I POST "/tasks/{task:Plants}/complete" through the API with:
      """
      {}
      """
    And I POST "/tasks/{task:Ferns}/cancel" through the API with:
      """
      {}
      """
    Then the next copy of "Plants" sits in the sprint on "today + 3"
    And the next copy of "Ferns" sits in the sprint on "today + 1"
    And the API calls answer:
      | call        | body | status | holds |
      | GET /tasks/3 |     | 200    | {"title": "Plants", "status": "open", "timeline": [{"kind": "recurred"}]} |

  Scenario: The next copy dates from today when a copy closes late or on its day, and from its day when early
    Given the tasks:
      | title | sprint    |
      | Late  | today - 20 |
      | Early | today + 2  |
      | OnDay | today      |
      | None  |            |
    And the task "Late" repeats every 1 weeks from "today - 28"
    And the task "Early" repeats every 1 weeks from "today - 5"
    And the task "OnDay" repeats every 1 weeks from "today - 7"
    And the task "None" repeats every 1 weeks from "today - 5"
    When I POST "/tasks/bulk/complete" through the API with:
      """
      { "ids": [1, 2, 3, 4] }
      """
    Then the next copy of "Late" sits in the sprint on "today + 7"
    And the next copy of "Early" sits in the sprint on "today + 9"
    And the next copy of "OnDay" sits in the sprint on "today + 7"
    And the next copy of "None" sits in the sprint on "today + 2"

  Scenario: The copy carries the title, note, tags, project and photos, and none of the history
    Given the photo "0123456789abcdef0123456789abcdef.jpg" uploaded 1 days ago
    And the tasks:
      | title            | note                                                                    | project | tags       |
      | Water the plants | the ferns too ![A photo](/media/0123456789abcdef0123456789abcdef.jpg) | Podcast |            |
      | Other            |                                                                         |         |            |
    And a published post "On plants"
    And the task "Water the plants" links the post "On plants"
    And the task comments:
      | task             | body  |
      | Water the plants | Hello |
    And the task work sessions:
      | task             | from        | until       |
      | Water the plants | today 08:00 | today 09:00 |
    And the task contributors:
      | task             | agent       | model           |
      | Water the plants | claude-code | claude-opus-5-5 |
    And the task "Water the plants" blocks the task "Other"
    And I PATCH "/tasks/{task:Water the plants}" through the API with:
      """
      { "tags": ["home", "money"], "note": "the ferns too ![A photo](/media/0123456789abcdef0123456789abcdef.jpg)" }
      """
    And the task "Water the plants" repeats on the cadence:
      | cadence   |
      | month_end |
    When I POST "/tasks/{task:Water the plants}/complete" through the API with:
      """
      {}
      """
    Then the API calls answer:
      | call        | body | status | holds |
      | GET /tasks/3 |     | 200    | {"title": "Water the plants", "note": "the ferns too ![A photo](/media/0123456789abcdef0123456789abcdef.jpg)", "tags": ["home", "money"], "label": "POD-2", "comments": [], "worked_seconds": 0, "contributors": [{"kind": "owner"}], "links": [], "record_links": {}} |
    And the database reads "1, 1 / 3, 1" for:
      """
      SELECT owner_id, photo_id FROM photo_claims WHERE owner = 'task' ORDER BY owner_id
      """

  Scenario: A paused series makes no copy until it resumes, and an earlier copy closing again makes none
    Given the tasks:
      | title  |
      | Paused |
      | Open   |
      | Again  |
    And the task "Paused" repeats every 1 days
    And the task "Open" repeats every 1 days
    And the task "Again" repeats every 1 days
    Then the API calls answer:
      | call                       | body | status | holds |
      | POST /task_series/1/pause   |      | 200    | |
      | POST /tasks/1/complete      | {}   | 200    | |
      | POST /task_series/2/pause   |      | 200    | |
      | POST /task_series/2/resume  |      | 200    | {"task": {"id": 2}} |
      | POST /tasks/2/complete      | {}   | 200    | |
      | POST /tasks/3/complete      | {}   | 200    | |
      | POST /tasks/3/reopen        | {}   | 200    | |
      | POST /tasks/3/complete      | {}   | 200    | |
    And the database reads "Paused, 1 / Open, 2 / Again, 2" for:
      """
      SELECT title, count(*) FROM tasks GROUP BY title ORDER BY min(id)
      """
    And the API calls answer:
      | call                       | body | status | holds |
      | POST /task_series/1/resume  |      | 200    | {"task": {"status": "open", "sprint_on": "{day:today + 1}"}} |
      | POST /task_series/999/pause   |      | 404    | |
      | POST /task_series/999/resume  |      | 404    | |

  Scenario: The API sets a cadence in place, keeps a pause and makes the next copy of a closed task
    Given the tasks:
      | title   | status |
      | Plants  | open   |
      | Done    | done   |
    Then the API calls answer:
      | call                   | body                                                         | status | holds |
      | PATCH /tasks/1          | {"recur": {"cadence": "days", "every": 3, "day": 9}}        | 200    | {"recur": {"cadence": "days", "every": 3, "day": null}} |
      | POST /task_series/1/pause |                                                            | 200    | |
      | PATCH /tasks/1          | {"recur": {"cadence": "month_end", "every": 9}}             | 200    | {"recur": {"id": 1, "cadence": "month_end", "every": null, "paused": true}} |
      | PATCH /tasks/2          | {"recur": {"cadence": "days", "every": 1}}                  | 200    | |
    And the database reads "Plants, open, 1,  / Done, done, 0,  / Done, open, 1, {day:today + 1}" for:
      """
      SELECT title, status, (SELECT count(*) FROM task_series WHERE task_id = tasks.id), sprint_date::text
      FROM tasks LEFT JOIN sprints ON sprints.id = sprint_id ORDER BY tasks.id
      """
    And the API calls answer:
      | call                   | body                                                | status | holds |
      | PATCH /tasks/2          | {"recur": {"cadence": "days", "every": 2}}         | 422    | {"errors": {"cadence": ["its series has moved on to a newer copy; set the cadence there"]}} |
      | POST /tasks/3/complete  | {}                                                  | 200    | |
      | PATCH /tasks/3          | {"recur": {"cadence": "days", "every": 2}}         | 422    | "cadence" |
      | PATCH /tasks/4          | {"recur": null}                                     | 200    | |
      | PATCH /tasks/2          | {"recur": {"cadence": "days", "every": 2}}         | 200    | |
      | PATCH /tasks/999999     | {"recur": {"cadence": "month_end"}}                 | 404    | |
      | POST /tasks             | {"title": "Bad", "recur": {"cadence": "month_weekday"}} | 422 | {"errors": {"week": ["month_weekday needs a week"], "weekday": ["weeks and month_weekday need a weekday"]}} |
      | POST /tasks             | {"title": "Bad", "recur": {"cadence": "hourly"}}    | 422    | recur/cadence |
      | POST /tasks             | {"title": "Bad", "recur": {"cadence": "month_weekday", "week": 5, "weekday": 1}} | 422 | week |
    And the database holds 2 task_series rows
