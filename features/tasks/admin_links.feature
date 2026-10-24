Feature: Task links in the admin
  The task list counts each task's open blocks, and the task page finds, adds and removes links.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title               |
      | Ship the links      |
      | Write the migration |

  Scenario: A row counts what the task blocks after its comments, and what blocks it with a lock
    Given the tasks:
      | title             |
      | Run the migration |
      | Alone             |
    And the task "Ship the links" blocks the task "Write the migration"
    And the task "Ship the links" blocks the task "Run the migration"
    And the task "Run the migration" blocks the task "Write the migration"
    And the task comments:
      | task           | body  |
      | Ship the links | Hello |
    When I visit "/admin/tasks?filter=next"
    Then the page part ".task:has(.task-title:text-is('Ship the links')) .task-meta .task-mark.sand" reads "blocking 2"
    And the page has ".task:has(.task-title:text-is('Ship the links')) .task-meta .task-mark.sand .fa-arrow-right-long"
    And the page has ".task:has(.task-title:text-is('Ship the links')) .task-mark:has(.fa-comment) + .task-mark.sand"
    And the blocking mark on "Ship the links" lists "Run the migration, Write the migration" on hover
    And the page part ".task:has(.task-title:text-is('Write the migration')) .task-meta .task-mark.pink" reads "blocked by 2"
    And the page has ".task:has(.task-title:text-is('Write the migration')) .task-meta .task-mark.pink .fa-lock"
    And the page has no ".task:has(.task-title:text-is('Alone')) .task-meta .task-mark"
    And the page has no ".task:has(.task-title:text-is('Ship the links')) .task-meta .task-mark.pink"
    And the page has no axe breaches in light or dark

  Scenario Outline: A <type> link shows no chip and no count on the row, but lists on the task page
    Given the task "Ship the links" <link> the task "Write the migration"
    When I visit "/admin/tasks?filter=next"
    Then the page has no ".task-meta .task-link-label"
    And the page has no ".task-meta .task-mark.sand, .task-meta .task-mark.pink"
    When I visit "/admin/tasks/{task:Write the migration}?filter=next"
    Then the page part ".task-link-row .task-link-label" reads "<label>"
    And the page part ".task-link-row .task-link-title" reads "Ship the links"

    Examples:
      | type       | link             | label         |
      | duplicates | duplicates       | duplicated by |
      | relates    | relates to       | relates to    |
      | parent     | is the parent of | child of      |

  Scenario: The task page lists a blocks link with its type and title
    Given the task "Ship the links" blocks the task "Write the migration"
    When I visit "/admin/tasks/{task:Write the migration}?filter=next"
    Then the page part ".task-link-row .task-link-label" reads "blocked by"
    And the page part ".task-link-row .task-link-title" reads "Ship the links"
    And the page has ".task-link-row form[action='/admin/tasks/2/links/1/delete']"
    And the page has no axe breaches in light or dark

  Scenario: The blocked by count goes once no open blocker is left
    Given the tasks:
      | title              | status   |
      | Drop the migration | canceled |
    And the task "Write the migration" blocks the task "Ship the links"
    And the task "Drop the migration" blocks the task "Ship the links"
    And the task "Write the migration" relates to the task "Drop the migration"
    When I visit "/admin/tasks?filter=next"
    Then the page part ".task:has(.task-title:text-is('Ship the links')) .task-meta .task-mark.pink" reads "blocked by 1"
    And the page has no ".task:has(.task-title:text-is('Write the migration')) .task-meta .task-mark.pink"
    And the page has ".task:has(.task-title:text-is('Ship the links')) form[action='/admin/tasks/1/start']"
    And the page has ".task:has(.task-title:text-is('Ship the links')) form[action='/admin/tasks/1/move/someday']"
    When I send the admin form "/admin/tasks/{task:Write the migration}/complete" with:
      | filter | next |
    And I visit "/admin/tasks?filter=next"
    Then the page has no ".task-meta .task-mark.pink"

  Scenario: Canceling a blocker or the blocked task ends the counts
    Given the tasks:
      | title  |
      | Third  |
      | Fourth |
    And the task "Write the migration" blocks the task "Ship the links"
    And the task "Third" blocks the task "Fourth"
    When I send the admin form "/admin/tasks/{task:Write the migration}/cancel" with:
      | filter | next |
    And I send the admin form "/admin/tasks/{task:Fourth}/cancel" with:
      | filter | next |
    And I visit "/admin/tasks?filter=next"
    Then the page has no ".task-meta .task-mark.pink"
    And the page has no ".task-meta .task-mark.sand"

  Scenario: A relates link shows no blocked by count
    Given the task "Write the migration" relates to the task "Ship the links"
    When I visit "/admin/tasks?filter=next"
    Then the page has no ".task-meta .task-mark.pink"

  Scenario: A blocked task still moves and completes
    Given the tasks:
      | title  |
      | Second |
    And the task "Write the migration" blocks the task "Ship the links"
    And the task "Write the migration" blocks the task "Second"
    When I send the admin form "/admin/tasks/{task:Ship the links}/move/someday" with:
      | filter | next |
    And I send the admin form "/admin/tasks/{task:Second}/complete" with:
      | filter | next |
    Then the database reads "someday, open / next, done" for:
      """
      SELECT concat_ws(', ', list, status) FROM tasks WHERE title IN ('Ship the links', 'Second') ORDER BY id
      """

  Scenario: The link finder finds a task by its number or label, ahead of title matches
    Given the projects:
      | name    | key |
      | Podcast | POD |
    And the tasks:
      | title            | project |
      | Record the intro | Podcast |
      | Edit the intro   | Podcast |
      | Mix the outro    | Podcast |
      | Plan 2.0         |         |
    And the database runs:
      """
      UPDATE tasks SET number = 23 WHERE title = 'Mix the outro';
      """
    Then the link finder on "Ship the links" finds:
      | query  | targets      |
      | 2      | 2, POD-2, 3  |
      | #2     | 2, POD-2     |
      | POD-2  | POD-2        |
      | pod-2  | POD-2        |
      | #POD-2 | POD-2        |
    Given the database runs:
      """
      INSERT INTO tasks (id, title, list, position) VALUES (900001, 'Loose', 'next', 99);
      """
    Then the link finder on "Ship the links" finds:
      | query  | targets |
      | 900001 |         |

  Scenario: The link finder finds by title, leaves out linked tasks, and offers canceled tasks last
    Given the tasks:
      | title              | status   | position |
      | Drop the migration | canceled | 1        |
      | Linked migration   | open     | 4        |
    And the task "Linked migration" blocks the task "Ship the links"
    Then the link finder on "Ship the links" finds:
      | query           | targets |
      | migration       | 2, 3    |
      | #1              |         |
    When I visit "/admin/tasks/{task:Ship the links}?filter=next&link_q=nothing%20like%20it"
    Then the page part ".task-link-editor" holds "No unlinked task matches."
    When I visit "/admin/tasks/{task:Ship the links}?filter=next&link_q=migration"
    Then the page field "#task-1-link-other-id" holds "migration"
    And the page has "form#task-1-link-add[method='post'][action='/admin/tasks/1/links']"
    And the page has ".task-link-target[form='task-1-link-add'][name='link[other_id]'][value='2']"
    And the page has "select[form='task-1-link-add'][name='link[kind]']"
    And the page has no axe breaches in light or dark

  Scenario: The link form sends the find and the type, and offers the four types
    When I visit "/admin/tasks/{task:Ship the links}?filter=next"
    Then the page has "input#task-1-link-other-id[form='task-1-link-add'][name='link_q']"
    And the page part "button[form='task-1-link-add'][name='link_find']" reads "Find"
    And the page has "select[form='task-1-link-add'][name='link[kind]']"
    And the page parts "#task-1-link-kind option" have "value" set to "blocks | blocked_by | relates | duplicates"
    When I visit "/admin/tasks/{task:Ship the links}?filter=next&link_q=migration&link_kind=follows"
    Then the page has no "#task-1-link-kind option[selected]"

  Scenario: The link finder works for a task waiting on the upcoming tab
    Given the tasks:
      | title   | sprint    |
      | Waiting | today + 1 |
    When I visit "/admin/tasks/{task:Waiting}?filter=upcoming&link_q=migration"
    Then the page has "#task-3-link-other-id"
    And the page parts ".task-link-target .record-key" read "2"
    And the page has "form#task-3-link-add input[name='filter'][value='upcoming']"

  Scenario: A find with a type picked comes back with the query and the type, and writes nothing
    When I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter     | next          |
      | link_find  | 1             |
      | link_q     | " migration " |
      | link[kind] | blocked_by    |
    Then the admin answer goes to a page starting "/admin/tasks/1?filter=next&origin=tasks&link_kind=blocked_by&link_q=migration"
    And the database holds 0 task_links rows
    When I follow the admin answer
    Then the page part "#task-1-link-kind option[selected]" has "value" set to "blocked_by"
    And the page parts ".task-link-target .record-key" read "2"
    When I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter         | next       |
      | link[kind]     | blocked_by |
      | link[other_id] | 2          |
    Then the database reads "2, 1, blocks" for:
      """
      SELECT from_task_id, to_task_id, type FROM task_links
      """

  Scenario Outline: Adding a <kind> link stores it and comes back to the list
    When I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter         | next   |
      | link[kind]     | <kind> |
      | link[other_id] | 2      |
    Then the admin answer goes to "/admin/tasks?filter=next"
    And the database reads "<stored>" for:
      """
      SELECT from_task_id, to_task_id, type FROM task_links
      """

    Examples:
      | kind       | stored           |
      | blocks     | 1, 2, blocks     |
      | relates    | 1, 2, relates    |
      | duplicates | 1, 2, duplicates |

  Scenario: Adding a link says so and shows the count, and comes back to Today from there
    When I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter         | next   |
      | link[kind]     | blocks |
      | link[other_id] | 2      |
    And I follow the admin answer
    Then the toast says "Tasks linked"
    And the page part ".task:has(.task-title:text-is('Ship the links')) .task-meta .task-mark.sand" reads "blocking 1"
    When I send the admin form "/admin/tasks/{task:Ship the links}/links/2/delete" with:
      | filter | next |
    And I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter         | today  |
      | origin         | today  |
      | link[kind]     | blocks |
      | link[other_id] | 2      |
    Then the admin answer goes to "/admin"

  Scenario: Adding a link refuses one it cannot store, with the error beside the field
    Given the task "Write the migration" relates to the task "Ship the links"
    When I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter         | next   |
      | link[kind]     | blocks |
      | link[other_id] | 2      |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-1-link-other-id-error" reads "These two tasks are already linked."
    And the page has "[data-task-read='1']"
    And the page part "#task-1-link-kind option[selected]" has "value" set to "blocks"
    And the database holds 1 task_links row
    When I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter         | next   |
      | link[kind]     | blocks |
      | link[other_id] | 1      |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-1-link-other-id-error" reads "A task cannot link to itself."
    And the page part "#task-1-link-other-id" has "aria-describedby" set to "task-1-link-other-id-error"
    When I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter         | next    |
      | link[kind]     | follows |
      | link[other_id] | 2       |
    And I look at the admin answer
    Then the page part "#task-1-link-kind-error" reads "Pick one of the four link types."
    When I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter         | next   |
      | link[kind]     | blocks |
      | link[other_id] | 999999 |
    And I look at the admin answer
    Then the page part "#task-1-link-other-id-error" reads "That task is gone. Find another."
    When I send the admin form "/admin/tasks/{task:Ship the links}/links" with:
      | filter         | next       |
      | link[kind]     | blocks     |
      | link[other_id] | 2147483648 |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-1-link-other-id-error" reads "That task is gone. Find another."

  Scenario: A refused link on a waiting task keeps the upcoming tab
    Given the tasks:
      | title   | sprint    |
      | Waiting | today + 1 |
    When I send the admin form "/admin/tasks/{task:Waiting}/links" with:
      | filter         | upcoming |
      | link[kind]     | blocks   |
      | link[other_id] | 3        |
    And I look at the admin answer
    Then the page has "#task-3-link-other-id-error"
    And the page part ".task-drawer-foot a[data-task-close]" has "href" set to "/admin/tasks?filter=upcoming"

  Scenario: Removing a link clears it from both ends
    Given the task "Write the migration" blocks the task "Ship the links"
    And the tasks:
      | title    |
      | Unlinked |
    When I send the admin form "/admin/tasks/{task:Ship the links}/links/2/delete" with:
      | filter | next |
    Then the admin answer goes to "/admin/tasks?filter=next"
    And the database holds 0 task_links rows
    When I follow the admin answer
    Then the toast says "Link removed"
    Given the task "Write the migration" blocks the task "Ship the links"
    When I send the admin form "/admin/tasks/{task:Write the migration}/links/1/delete" with:
      | filter | next |
    Then the database holds 0 task_links rows
    When I send the admin form "/admin/tasks/{task:Ship the links}/links/3/delete" with:
      | filter | next |
    Then the server answers 404
