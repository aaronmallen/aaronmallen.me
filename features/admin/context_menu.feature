Feature: Admin row context menu
  A right-click on a task row opens its menu at the pointer in place of the browser's own. The keyboard opens it
  too, steps through it and closes it. From the menu I start, tag, copy and delete a task without a page load.

  Background:
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO tasks (title, list, position) VALUES ('Ship it', 'next', 1);
      """

  Scenario: Right-clicking a task row opens its menu at the pointer in place of the browser's own
    Given the menu window is 1280 by 1600
    When I visit "/admin/tasks?filter=next"
    And I watch the context menu events
    And I right-click the row part ".task:has-text('Ship it') .record-key"
    Then the menu head holds "1 · Ship it"
    And the row menu sits at the pointer
    And the browser's own menu was held back

  Scenario: The menu holds the actions an open task takes
    When I visit "/admin/tasks?filter=next"
    And I right-click the row part ".task:has-text('Ship it') .record-key"
    Then the menu items include "Open, Start, Complete, Schedule, Tags, Copy, Delete"
    And the menu items leave out "Reopen"

  Scenario: The open menu keeps admin keys quiet
    When I visit "/admin/tasks?filter=next"
    And I right-click the row part ".task:has-text('Ship it') .record-key"
    And I press "s"
    Then ".toast" does not show within a second

  Scenario: The menu closes when I click elsewhere
    When I visit "/admin/tasks?filter=next"
    And I right-click the row part ".task:has-text('Ship it') .record-key"
    And I click the page heading
    Then the row menu is shut

  Scenario: Shift and right-click shows the browser's own menu
    When I visit "/admin/tasks?filter=next"
    And I watch the context menu events
    And I shift and right-click the row part ".task:has-text('Ship it') .record-key"
    Then the browser's own menu was let through
    And "[data-context-menu]" does not show within a second

  Scenario: A right-click on a link in the row shows the browser's own menu
    When I visit "/admin/tasks?filter=next"
    And I watch the context menu events
    And I right-click the row part ".task-title:has-text('Ship it')"
    Then the browser's own menu was let through
    And "[data-context-menu]" does not show within a second

  Scenario Outline: <key> opens the menu beside the row with the first item in focus
    When I visit "/admin/tasks?filter=next"
    And I focus the task title "Ship it"
    And I press "<key>"
    Then the row menu sits 24 pixels into the row ".task:has-text('Ship it')"
    And the row menu focus holds "Open"

    Examples:
      | key         |
      | ContextMenu |
      | Shift+F10   |

  Scenario: The arrow keys step through the menu and in and out of a submenu
    When I visit "/admin/tasks?filter=next"
    And I focus the task title "Ship it"
    And I press "ContextMenu"
    And the row menu focus holds "Open"
    And I press "ArrowDown"
    Then the row menu focus holds "Start"
    When I step down the row menu until the focus holds "Move to"
    And I press "ArrowRight"
    Then the row menu focus holds "Today"
    When I press "ArrowLeft"
    Then the row menu focus holds "Move to"

  Scenario: Enter runs the item in focus
    When I visit "/admin/tasks?filter=next"
    And I focus the task title "Ship it"
    And I press "ContextMenu"
    And the row menu focus holds "Open"
    And I press the keys "ArrowDown Enter"
    Then a row toast says "Started · it is today's work now"

  Scenario: Escape closes the menu and hands focus back to the row
    When I visit "/admin/tasks?filter=next"
    And I focus the task title "Ship it"
    And I press "ContextMenu"
    And I press "Escape"
    Then the row menu is shut
    And the focus is back on the task row "Ship it"

  Scenario: Starting a task from the menu switches its row to pause with no page load
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      UPDATE tasks SET list = NULL,
        sprint_id = (SELECT id FROM sprints WHERE sprint_date = (now() AT TIME ZONE 'America/Chicago')::date);
      """
    When I visit "/admin/tasks?filter=today"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I pick "Start" in the row menu
    Then a row toast says "Started · it is today's work now"
    And the admin markup holds ".task:has-text('Ship it') button[aria-label='Stop']"
    And the row page stayed

  Scenario: The tag menu lists only private tags, read as checkboxes
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('home', 'mk-blue', 'private'), ('homework', 'mk-pink', 'private'),
        ('ruby', 'mk-blue', 'public');
      """
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Tags" in the row menu
    Then the row menu holds "[role=menuitemcheckbox][aria-checked=false]:has-text('#home')"
    And the row menu does not mention "#ruby"

  Scenario: Ticking a tag tags the task
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('home', 'mk-blue', 'private');
      """
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Tags" in the row menu
    And I pick "#home" in the row menu
    Then a row toast says "Tagged 1 task home"
    And the database soon answers "home" for:
      """
      SELECT string_agg(t.name, ', ') FROM task_tags tt JOIN tags t ON t.id = tt.tag_id
      """

  Scenario: Unticking a tag the task holds untags it
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('home', 'mk-blue', 'private');
      INSERT INTO task_tags (task_id, tag_id) VALUES (1, 1);
      """
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Tags" in the row menu
    And I pick "#home" in the row menu
    Then a row toast says "Took home off 1 task"
    And the database soon answers "0" for:
      """
      SELECT count(*) FROM task_tags
      """

  Scenario: The new tag box makes a new tag
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Tags" in the row menu
    And I type "Errands" in the row menu tag box
    And I press "Enter"
    Then a row toast says "Tagged 1 task errands"

  Scenario: The new tag box suggests the tags that match, each in its color, and passes axe
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('home', 'mk-blue', 'private'), ('homework', 'mk-pink', 'private');
      """
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Tags" in the row menu
    And I type "hom" in the row menu tag box
    Then the row menu suggestions read "#home, #homework"
    And the row menu holds ".ctx-suggest .tag.pink:has-text('#homework')"
    And the page has no axe breaches in light or dark

  Scenario: Picking a suggestion applies it
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('home', 'mk-blue', 'private'), ('homework', 'mk-pink', 'private');
      """
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Tags" in the row menu
    And I type "hom" in the row menu tag box
    And I pick the row menu suggestion "#homework"
    Then a row toast says "Tagged 1 task homework"

  Scenario: The keyboard alone picks a suggestion
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('home', 'mk-blue', 'private'), ('homework', 'mk-pink', 'private');
      """
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Tags" in the row menu
    And I type "hom" in the row menu tag box
    Then the row menu suggestions read "#home, #homework"
    When I press the keys "ArrowDown ArrowDown ArrowUp Enter"
    Then a row toast says "Tagged 1 task home"
    And the database soon answers "home" for:
      """
      SELECT string_agg(t.name, ', ') FROM task_tags tt JOIN tags t ON t.id = tt.tag_id
      """

  Scenario: Escape closes the suggestions and keeps the menu
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('home', 'mk-blue', 'private'), ('homework', 'mk-pink', 'private');
      """
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Tags" in the row menu
    And I type "hom" in the row menu tag box
    Then the row menu suggestions read "#home, #homework"
    When I press "Escape"
    Then the row menu suggestions read ""
    And the focus is in the row menu tag box

  Scenario: The new tag box refuses a bad name with an error toast
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Tags" in the row menu
    And I type "no good" in the row menu tag box
    And I press "Enter"
    Then a failed row toast says "Nothing changed · a tag takes lowercase letters, numbers and dashes"
    And the database answers "0" for:
      """
      SELECT count(*) FROM task_tags
      """

  Scenario: Delete asks for a second click
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I pick "Delete" in the row menu
    Then the row menu offers "Click again to delete"
    And the database answers "1" for:
      """
      SELECT count(*) FROM tasks
      """

  Scenario: Escape after the first click deletes nothing
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I pick "Delete" in the row menu
    And I press "Escape"
    Then the row menu is shut
    And the database answers "1" for:
      """
      SELECT count(*) FROM tasks
      """

  Scenario: The second click deletes the task
    When I visit "/admin/tasks?filter=next"
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I pick "Delete" in the row menu
    And I pick "Click again to delete" in the row menu
    Then a row toast says "Task deleted"

  Scenario: Copying the title puts it on the clipboard and shows a toast
    When I visit "/admin/tasks?filter=next"
    And I watch the row menu clipboard
    And I open the row menu on ".task:has-text('Ship it') .record-key"
    And I point at "Copy" in the row menu
    And I pick "Title" in the row menu
    Then a row toast says "Title copied"
    And the row menu clipboard holds "Ship it"

  Scenario: Near the edge of the window the menu stays on screen with items 44px tall
    Given the menu window is 400 by 500
    When I visit "/admin/tasks?filter=next"
    And I right-click the row part ".task:has-text('Ship it')" near the bottom right of the window
    Then the row menu stays inside the window
    And the row menu items stand at least 44 pixels tall

  Scenario: The menu opens from a pool row on Today
    When I visit "/admin"
    And I right-click the row part "[data-pools] .li:has-text('Ship it')"
    Then the menu head holds "Ship it"

  Scenario: A live update waits until the menu closes
    When I open "/admin/tasks?filter=next" and its live stream
    And I right-click the row part ".task:has-text('Ship it') .record-key"
    And the row menu offers "Open"
    And the database runs:
      """
      INSERT INTO tasks (title, list, position) VALUES ('Arrived live', 'next', 2);
      """
    And the live page hears it
    Then ".task-title:has-text('Arrived live')" does not show within a second
    When I press "Escape"
    Then ".task-title:has-text('Arrived live')" shows
