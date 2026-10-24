Feature: Marking a synced task seen
  Moving, scheduling, starting or retagging a synced task in the admin marks its issue seen. A status change
  that keeps the task in place, or a move to its own list, leaves it unseen.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title    | list     |
      | Someday  | external |
      | Today    | external |
      | Schedule | external |
      | Start    | external |
      | Stay     | external |
      | Tag      | external |
      | Keep     | external |
      | Complete | external |
    And the task sources:
      | task     | url                                                     |
      | Someday  | https://github.com/aaronmallen/aaronmallen.me/issues/11 |
      | Today    | https://github.com/aaronmallen/aaronmallen.me/issues/12 |
      | Schedule | https://github.com/aaronmallen/aaronmallen.me/issues/13 |
      | Start    | https://github.com/aaronmallen/aaronmallen.me/issues/14 |
      | Stay     | https://github.com/aaronmallen/aaronmallen.me/issues/15 |
      | Tag      | https://github.com/aaronmallen/aaronmallen.me/issues/16 |
      | Keep     | https://github.com/aaronmallen/aaronmallen.me/issues/17 |
      | Complete | https://github.com/aaronmallen/aaronmallen.me/issues/18 |

  Scenario: A move, a schedule, a start or a new tag marks the task seen, and the rest leave it unseen
    When I send the admin form "/admin/tasks/{task:Someday}/move/someday"
    And I send the admin form "/admin/tasks/{task:Today}/move/today"
    And I send the admin form "/admin/tasks/{task:Schedule}/schedule" with:
      | sprint_on | {day:today + 2} |
    And I send the admin form "/admin/tasks/{task:Start}/start"
    And I send the admin form "/admin/tasks/{task:Stay}/move/external"
    And I send the admin form "/admin/tasks/{task:Complete}/complete"
    And I save the task "Tag" in the admin with:
      | filter     | external |
      | task[list] |          |
      | task[tags] | work     |
    And I save the task "Keep" in the admin with:
      | filter     | external |
      | task[list] |          |
      | task[tags] |          |
    Then the database reads "Someday, true / Today, true / Schedule, true / Start, true / Stay, false / Tag, true / Keep, false / Complete, false" for:
      """
      SELECT title, seen_at IS NOT NULL FROM tasks JOIN task_sources ON task_id = tasks.id ORDER BY tasks.id
      """

  Scenario: A later move keeps the first time the task was seen
    When I send the admin form "/admin/tasks/{task:Someday}/move/someday"
    And the database runs:
      """
      UPDATE task_sources SET seen_at = now() - interval '10 minutes';
      """
    And I send the admin form "/admin/tasks/{task:Someday}/move/next"
    Then the database reads "true" for:
      """
      SELECT seen_at < now() - interval '9 minutes' FROM task_sources JOIN tasks ON tasks.id = task_id WHERE title = 'Someday'
      """
