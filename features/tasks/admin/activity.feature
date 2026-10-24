Feature: A task's activity
  The task page shows the time worked in sessions and a closed Timeline block of what happened to the task.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title             | status      |
      | Ship the timeline | in_progress |

  Scenario: The Timeline block counts the events and words each one
    Given the task_events table holds the rows:
      | task_id                  | kind           | from_list | to_list | from_sprint_on | to_sprint_on | tag_name | from_status | to_status   | occurred_at |
      | {task:Ship the timeline} | moved          | next      | someday |                |              |          |             |             | now - 86400 |
      | {task:Ship the timeline} | moved          | next      |         |                | 2026-10-03   |          |             |             | now - 86400 |
      | {task:Ship the timeline} | moved          |           | someday | 2026-10-03     |              |          |             |             | now - 86400 |
      | {task:Ship the timeline} | recurred       |           |         |                |              |          |             |             | now - 86400 |
      | {task:Ship the timeline} | tagged         |           |         |                |              | money    |             |             | now - 86400 |
      | {task:Ship the timeline} | untagged       |           |         |                |              | house    |             |             | now - 86400 |
      | {task:Ship the timeline} | status_changed |           |         |                |              |          | open        | in_progress | now - 86400 |
    When I visit "/admin/tasks/{task:Ship the timeline}?filter=next"
    Then the page part "[data-task-read] details.task-timeline:not([open]) > summary" holds "Timeline"
    And the page part "[data-task-read] details.task-timeline > summary .task-timeline-count" reads "7 events"
    And the page parts ".timeline-event-text" read "Moved from next to someday | Moved from next to the Oct 3, 2026 sprint | Moved from the Oct 3, 2026 sprint to someday | Made by its recurring series | Added the tag money | Removed the tag house | Changed the status from open to in progress"
    And the page has no axe breaches in light or dark

  Scenario: A task with no history says nothing has happened, and no sessions yet
    Given the tasks:
      | title      |
      | Elsewhere  |
    And the task_events table holds the rows:
      | task_id          | kind   | tag_name  | occurred_at |
      | {task:Elsewhere} | tagged | elsewhere | now         |
    When I visit "/admin/tasks/{task:Ship the timeline}?filter=next"
    Then the page part ".task-timeline .hint" reads "Nothing has happened yet."
    And the page has no ".timeline-event"
    And the page part ".field .hint:text('No sessions')" reads "No sessions yet."

  Scenario: Comments and sessions stay out of the Timeline block
    Given the task_comments table holds the rows:
      | task_id                  | body |
      | {task:Ship the timeline} | Noon |
    And the work_sessions table holds the rows:
      | task_id                  | started_at       | ended_at         |
      | {task:Ship the timeline} | 2026-10-03 09:00 | 2026-10-03 10:30 |
    When I visit "/admin/tasks/{task:Ship the timeline}?filter=next"
    Then the page part ".task-timeline-count" reads "0 events"
    And the page has 1 of ".task-comments .comment"
    And the page has 1 of ".task-session"
    And the page part "#task-session-{session:Ship the timeline} .task-session-span" reads "Oct 3 · 09:00–10:30"
    And the page part "#task-session-{session:Ship the timeline} .task-session-length" reads "1h 30m"

  Scenario: A running session shows as running
    Given the work_sessions table holds the rows:
      | task_id                  | started_at  |
      | {task:Ship the timeline} | now - 86400 |
    When I visit "/admin/tasks/{task:Ship the timeline}?filter=next"
    Then the page part ".task-session" holds "–now"
    And the page part ".task-session .pill" reads "running"

  Scenario: A tag saved from the editor lands on the timeline
    When I visit "/admin/tasks/{task:Ship the timeline}/edit?filter=next"
    And I send the admin form "/admin/tasks/{task:Ship the timeline}" with:
      | filter      | next              |
      | task[title] | Ship the timeline |
      | task[tags]  | garden            |
    And I visit "/admin/tasks/{task:Ship the timeline}?filter=next"
    Then the page parts ".timeline-event-text" read "Added the tag garden"

  Scenario: The facts show the task's total time
    Given the tasks:
      | title  | worked |
      | Worked | 5700   |
    When I visit "/admin/tasks/{task:Worked}"
    Then the page part ".task-fact:has(dt:text-is('Worked')) dd" reads "1h 35m"
