Feature: Working on a task in the drawer
  The drawer takes comments, edits the task, links tasks and records, and deletes, all without leaving the list.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title                | list    |
      | Email the accountant | next    |
      | Learn Elixir         | someday |

  Scenario: The comment box shows its button once it holds text and adds a comment in place
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I fill in "New comment" in "dialog#task-panel[open]" with "  "
    Then the page has no "dialog#task-panel[open] button:visible:text-is('Add comment')"
    When I fill in "New comment" in "dialog#task-panel[open]" with "Sent the **forms**"
    And I click "Add comment" in "dialog#task-panel[open]"
    Then the toast says "Comment added"
    And I am on "/admin/tasks?filter=next"
    And the database soon holds "Sent the **forms**" for:
      """
      SELECT body FROM task_comments
      """

  Scenario: A comment edits and deletes from the drawer
    Given the task_comments table holds the rows:
      | task_id                     | body           |
      | {task:Email the accountant} | Sent the forms |
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click the page part "dialog#task-panel[open] .comment:has-text('Sent the forms') summary:has-text('Edit')"
    And I fill in "Comment" in "dialog#task-panel[open] .comment:has-text('Sent the forms')" with "Sent the forms twice"
    And I click "Save" in "dialog#task-panel[open] .comment:has-text('Sent the forms')"
    Then the toast says "Comment saved"
    And the database soon holds "Sent the forms twice" for:
      """
      SELECT body FROM task_comments
      """
    When I open the task "Email the accountant" in the drawer
    And I click "Delete comment" in "dialog#task-panel[open] .comment"
    And I say yes to the question
    Then the toast says "Comment deleted"
    And the task_comments table holds 0 rows

  Scenario: The comment editor in the drawer inserts snippets and previews through the task renderer
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click the page part "dialog#task-panel[open] [data-markdown-editor]:has(textarea[name='comment[body]']) [role='toolbar'] button[aria-label='Bold']"
    Then the page field "dialog#task-panel[open] textarea[name='comment[body]']" holds "**bold**"
    When I fill in "New comment" in "dialog#task-panel[open]" with "<script>window.ran = true</script>\n\n<details><summary>M</summary>x</details>"
    And I click the page part "dialog#task-panel[open] [data-markdown-editor]:has(textarea[name='comment[body]']) .seg-option:has-text('Preview')"
    Then the page part "dialog#task-panel[open] .preview details summary" reads "M"
    And the page has no "dialog#task-panel[open] .preview script"
    And the script in the page did not run

  Scenario: The comment editor on the task page inserts snippets and previews through the task renderer
    When I visit "/admin/tasks/{task:Email the accountant}"
    And I click the page part "main [data-markdown-editor]:has(textarea[name='comment[body]']) [role='toolbar'] button[aria-label='Bold']"
    Then the page field "main textarea[name='comment[body]']" holds "**bold**"
    When I fill in "New comment" in "main" with "<script>window.ran = true</script>\n\n<details><summary>M</summary>x</details>"
    And I click the page part "main [data-markdown-editor]:has(textarea[name='comment[body]']) .seg-option:has-text('Preview')"
    Then the page part "main .preview details summary" reads "M"
    And the page has no "main .preview script"
    And the script in the page did not run

  Scenario: The note editor in the drawer inserts snippets, previews and saves what it formats
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click "Edit" in "dialog#task-panel[open] .task-drawer-foot"
    And I click the page part "dialog#task-panel[open] [data-markdown-editor]:has(textarea[name='task[note]']) [role='toolbar'] button[aria-label='Bold']"
    Then the page field "dialog#task-panel[open] textarea[name='task[note]']" holds "**bold**"
    When I click "Save" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page shows the part "dialog#task-panel[open] [data-task-read]"
    And the database soon holds "**bold**" for:
      """
      SELECT note FROM tasks WHERE title = 'Email the accountant'
      """
    When I click "Edit" in "dialog#task-panel[open] .task-drawer-foot"
    And I fill in "Notes" in "dialog#task-panel[open]" with "<script>window.ran = true</script>\n\nsay **why**"
    And I click the page part "dialog#task-panel[open] [data-markdown-editor]:has(textarea[name='task[note]']) .seg-option:has-text('Preview')"
    Then the page part "dialog#task-panel[open] .preview strong" reads "why"
    And the page has no "dialog#task-panel[open] .preview script"

  Scenario: A link in a note sits inline on a wide screen and takes a tap square on a phone
    Given the task "Read the guide" has the note:
      """
      start with [the guide](https://example.com) today
      """
    When I visit "/admin/tasks?filter=next"
    And I open the task "Read the guide" in the drawer
    Then the page part "#task-panel .markdown-body a" sits inline, shorter than 44 pixels
    Given the window is 375 by 800
    Then the page part "#task-panel .markdown-body a" is at least 44 pixels square

  Scenario: Editing turns the drawer into the form and saves back to reading the new values
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click "Edit" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page field "dialog#task-panel[open] [data-task-edit] [name='task[title]']" holds "Email the accountant"
    And the page has no "dialog#task-create[open]"
    And the page has no "dialog#task-panel[open] [data-task-read]"
    And the page has "dialog#task-panel[open] .task-drawer-foot a:has-text('Cancel')"
    And the page has "dialog#task-panel[open] .task-drawer-foot button:has-text('Save')"
    And the page has no axe breaches in light or dark
    When I set the page field "dialog#task-panel[open] [data-task-edit] [name='task[title]']" to "Email the bookkeeper"
    And I fill in "Tags" in "dialog#task-panel[open] [data-task-edit]" with "admin"
    And I click "Save" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page part "dialog#task-panel[open] [data-task-read] h1" reads "Email the bookkeeper"
    And the toast says "Task saved"
    When I click the page part "dialog#task-panel[open] [data-task-read] .task-drawer-close"
    Then the page part ".task:has-text('Email the bookkeeper') .task-meta .tag" reads "#admin"

  Scenario: Editing moves the task through the list field
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click "Edit" in "dialog#task-panel[open] .task-drawer-foot"
    And I pick "someday" in the page select "dialog#task-panel[open] select[name='task[list]']"
    And I click "Save" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page shows the part "dialog#task-panel[open] [data-task-read]"
    When I click the page part "dialog#task-panel[open] [data-task-read] .task-drawer-close"
    And I click the page part ".task-tabs .screen-tab:has-text('someday')"
    Then the page has ".task-title:has-text('Email the accountant')"

  Scenario: A failed save stays in the form, says what went wrong, and saves once fixed
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click "Edit" in "dialog#task-panel[open] .task-drawer-foot"
    And I set the page field "dialog#task-panel[open] [data-task-edit] [name='task[title]']" to " "
    And I fill in "Tags" in "dialog#task-panel[open] [data-task-edit]" with "not_a_tag"
    And I click "Save" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page has 2 of "dialog#task-panel[open] [data-task-edit] .field-error"
    And the page part "dialog#task-panel[open] [data-task-edit] .field-error" holds "Write the task down first."
    And the page part "dialog#task-panel[open] [data-task-edit] .tag-pick-chip" holds "#not_a_tag"
    And I am on "/admin/tasks?filter=next"
    When I click the page part "dialog#task-panel[open] [data-task-edit] button[aria-label='Remove not_a_tag']"
    And I set the page field "dialog#task-panel[open] [data-task-edit] [name='task[title]']" to "Email the bookkeeper"
    And I click "Save" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page part "dialog#task-panel[open] [data-task-read] h1" reads "Email the bookkeeper"

  Scenario: The form finds a task to link in place, and Cancel goes back to reading without a save
    Given the tasks:
      | title           |
      | Book the flight |
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click "Edit" in "dialog#task-panel[open] .task-drawer-foot"
    And I set the page field "dialog#task-panel[open] [data-task-edit] [name='link_q']" to "flight"
    And I click "Find" in "dialog#task-panel[open] [data-task-edit]"
    Then the page part "dialog#task-panel[open] [data-task-edit] .task-link-target" holds "Book the flight"
    When I set the page field "dialog#task-panel[open] [data-task-edit] [name='task[title]']" to "Something else"
    And I click "Cancel" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page part "dialog#task-panel[open] [data-task-read] h1" reads "Email the accountant"
    And the database soon holds "1" for:
      """
      SELECT count(*) FROM tasks WHERE title = 'Email the accountant'
      """

  Scenario: The form fits a phone with tap squares in the footer
    Given the window is 375 by 800
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click "Edit" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page shows the part "dialog#task-panel[open] [data-task-edit]"
    And "the page" does not scroll sideways
    And "[data-task-panel-body]" does not scroll sideways
    And every visible control in "#task-panel .task-drawer-foot" is at least 44 pixels square

  Scenario: The E key turns the drawer into the form, but types an e into a field
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I fill in "New comment" in "dialog#task-panel[open]" with "the"
    Then the page has no "dialog#task-panel[open] [data-task-edit]"
    When I press "e" in "dialog#task-panel[open]"
    Then the page field "dialog#task-panel[open] [data-task-edit] [name='task[title]']" holds "Email the accountant"

  Scenario: A row's pen opens the drawer in edit mode, and Escape hands focus back to it
    When I visit "/admin/tasks?filter=next"
    And I hover the page part ".task:has-text('Email the accountant')"
    And I click the page part ".task:has-text('Email the accountant') a[data-task-open-edit]"
    Then the page field "dialog#task-panel[open] [data-task-edit] [name='task[title]']" holds "Email the accountant"
    And the page has no "dialog#task-create[open]"
    When I press "Escape" in "dialog#task-panel[open] [data-task-edit] [name='task[title]']"
    Then the page has no "dialog#task-panel[open]"
    And the focus is on the control named "Edit"

  Scenario: A row's buttons fit a phone and give the pen a tap square
    Given the window is 375 by 800
    When I visit "/admin/tasks?filter=next"
    Then the page part ".task a[data-task-open-edit]" ends within 375 pixels
    And the page part ".task a[data-task-open-edit]" is at least 44 pixels square
    And "the page" does not scroll sideways

  Scenario: Linking a task from the drawer saves one blocks link and marks the row blocked
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I fill in "Task links" in "dialog#task-panel[open]" with "elixir"
    And I click "Find" in "dialog#task-panel[open]"
    Then the page part "dialog#task-panel[open] .task-link-target" holds "Learn Elixir"
    When I pick "is blocked by" in the page select "#task-{task:Email the accountant}-link-kind"
    And I click the page part ".task-link-target:has-text('Learn Elixir')"
    Then the toast says "Tasks linked"
    And the database soon holds "Learn Elixir, Email the accountant, blocks" for:
      """
      SELECT f.title, t.title, type FROM task_links JOIN tasks f ON f.id = from_task_id JOIN tasks t ON t.id = to_task_id
      """
    And the page part ".task:has-text('Email the accountant') .task-meta .task-mark.pink" reads "blocked by 1"

  Scenario: A link type picked before the find stays picked once the matches load
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I pick "is blocked by" in the page select "#task-{task:Email the accountant}-link-kind"
    And I fill in "Task links" in "dialog#task-panel[open]" with "elixir"
    And I click "Find" in "dialog#task-panel[open]"
    Then the page part "dialog#task-panel[open] .task-link-target" holds "Learn Elixir"
    And the page field "#task-{task:Email the accountant}-link-kind" holds "blocked_by"
    And I am on "/admin/tasks?filter=next"
    When I click the page part ".task-link-target:has-text('Learn Elixir')"
    Then the toast says "Tasks linked"
    And the database soon holds "Learn Elixir, Email the accountant, blocks" for:
      """
      SELECT f.title, t.title, type FROM task_links JOIN tasks f ON f.id = from_task_id JOIN tasks t ON t.id = to_task_id
      """

  Scenario: The finder finds a task by its key and leaves the task itself out
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I fill in "Task links" in "dialog#task-panel[open]" with "#{task:Learn Elixir}"
    And I click "Find" in "dialog#task-panel[open]"
    Then the page part ".task-link-target" holds "Learn Elixir"
    When I fill in "Task links" in "dialog#task-panel[open]" with "{task:Email the accountant}"
    And I click "Find" in "dialog#task-panel[open]"
    Then the page part ".task-link-editor" holds "No unlinked task matches."

  Scenario: A linked task opens in the drawer, still moves and completes, and its link removes
    Given the task_links table holds the rows:
      | from_task_id        | to_task_id                  | type   |
      | {task:Learn Elixir} | {task:Email the accountant} | blocks |
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click "Learn Elixir" in "dialog#task-panel[open]"
    Then the page part "dialog#task-panel[open] h1" reads "Learn Elixir"
    And I am on "/admin/tasks?filter=next"
    When I visit "/admin/tasks?filter=next"
    And I click "Start" on the task row "Email the accountant"
    Then the toast says "Started"
    When I click "Done" on the task row "Email the accountant"
    Then the toast says "Done"

  Scenario: A blocked task removes its link from the drawer and still moves
    Given the task_links table holds the rows:
      | from_task_id        | to_task_id                  | type   |
      | {task:Learn Elixir} | {task:Email the accountant} | blocks |
    When I visit "/admin/tasks?filter=next"
    And I click "Move to Someday" on the task row "Email the accountant"
    Then the toast says "Moved"
    When I visit "/admin/tasks?filter=someday"
    And I open the task "Email the accountant" in the drawer
    And I click "Remove the link to 2"
    Then the toast says "Link removed"
    And the page has no ".task:has-text('Email the accountant') .task-meta .task-mark.pink"

  Scenario: The blocked by count goes once the blocker is canceled
    Given the task_links table holds the rows:
      | from_task_id        | to_task_id                  | type   |
      | {task:Learn Elixir} | {task:Email the accountant} | blocks |
    When I visit "/admin/tasks?filter=someday"
    And I click "Cancel" on the task row "Learn Elixir"
    And I say yes to the question
    Then the toast says "Canceled"
    When I click the page part ".task-tabs .screen-tab:has-text('next')"
    Then the page has no ".task:has-text('Email the accountant') .task-meta .task-mark.pink"

  Scenario: A link refused because the pair was linked since the page loaded, or to itself, says why
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I fill in "Task links" in "dialog#task-panel[open]" with "elixir"
    And I click "Find" in "dialog#task-panel[open]"
    Then the page part ".task-link-target" holds "Learn Elixir"
    Given the task_links table holds the rows:
      | from_task_id        | to_task_id                  | type    |
      | {task:Learn Elixir} | {task:Email the accountant} | relates |
    When I click the page part ".task-link-target:has-text('Learn Elixir')"
    Then the page part "#task-{task:Email the accountant}-link-other-id-error" holds "These two tasks are already linked."
    Given the database runs:
      """
      DELETE FROM task_links
      """
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I fill in "Task links" in "dialog#task-panel[open]" with "elixir"
    And I click "Find" in "dialog#task-panel[open]"
    And the page part ".task-link-target" gets the value "{task:Email the accountant}"
    And I click the page part ".task-link-target:has-text('Learn Elixir')"
    Then the page part "#task-{task:Email the accountant}-link-other-id-error" holds "A task cannot link to itself."

  Scenario: The record picker finds and links a record without leaving the drawer
    Given a published post "Filing the quarterly taxes"
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I fill in "Link a record" in ".record-picker" with "quarterly"
    And I click "Search" in ".record-picker"
    Then the page part "dialog#task-panel[open] .record-picker-target" holds "Filing the quarterly taxes"
    And I am on "/admin/tasks?filter=next"
    When I click the page part ".record-picker-target:has-text('Filing the quarterly taxes')"
    Then the toast says "Record linked"
    And the database soon holds "post" for:
      """
      SELECT CASE WHEN left_kind = 'task' THEN right_kind ELSE left_kind END FROM record_links
      """

  Scenario: The record picker spans a phone with no sideways scroll
    Given a published post "Filing the quarterly taxes"
    And the window is 375 by 800
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I fill in "Link a record" in ".record-picker" with "quarterly"
    And I click "Search" in ".record-picker"
    Then the page part ".record-picker-target" holds "Filing the quarterly taxes"
    And "#task-panel" does not scroll sideways
    And "the page" does not scroll sideways

  Scenario: A linked record links to its page and removes from the drawer
    Given a published post "Filing the quarterly taxes"
    And the task "Email the accountant" links the post "Filing the quarterly taxes"
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    Then the page has "dialog#task-panel[open] .record-links a[href^='/admin/posts/'][href$='/edit']:has-text('Filing the quarterly taxes')"
    When I click "Remove the link to Filing the quarterly taxes"
    Then the toast says "Link removed"
    And 0 record links remain

  Scenario: A record linked since the page loaded says it is linked already
    Given a published post "Filing the quarterly taxes"
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I fill in "Link a record" in ".record-picker" with "quarterly"
    And I click "Search" in ".record-picker"
    Then the page part ".record-picker-target" holds "Filing the quarterly taxes"
    Given the task "Email the accountant" links the post "Filing the quarterly taxes"
    When I click the page part ".record-picker-target:has-text('Filing the quarterly taxes')"
    Then the page part ".record-picker #task-{task:Email the accountant}-record-other-id-error" holds "These two are already linked."

  Scenario: Deleting from the editor asks with the task's name, keeps it on no and deletes on yes
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click "Edit" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page shows the part "dialog#task-panel[open] [data-task-edit]"
    When I click "Delete" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page part "[data-confirm-ask] [data-confirm-message]" reads "Delete Email the accountant? This cannot be undone."
    When I say no to the question
    Then the page has no ".toast"
    And the page field "dialog#task-panel[open] [name='task[title]']" holds "Email the accountant"
    When I click "Delete" in "dialog#task-panel[open] .task-drawer-foot"
    And I say yes to the question
    Then the toast says "Task deleted"
