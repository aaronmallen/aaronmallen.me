Feature: Admin palette task actions
  With a task on screen the palette offers to start, complete or pause it, whichever fits. With no task on screen it
  offers to complete or pause each task in progress. Each runs where I am and leaves me there.

  Background:
    Given I am signed in to the admin

  Scenario: A task that is not in progress offers Start task, and running it starts the task in place
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Email the accountant', 1, 'next');
      """
    When I visit "/admin/tasks/1?filter=next"
    And I press the keys "Meta+/"
    And I type "task" in the palette
    Then "#command-palette-start-task:has-text('Start task')" shows
    And the admin markup lacks "#command-palette-complete-task:visible, [id^='command-palette-pause-task']:visible"
    When I press the keys "Backspace Backspace Backspace Backspace"
    And I type "start task" in the palette
    And I press the keys "Enter"
    And the palette closes
    Then the database soon answers "in_progress" for:
      """
      SELECT status FROM tasks WHERE id = 1
      """
    And the admin address is "/admin/tasks/1?filter=next"
    And ".task-drawer-head:has-text('in progress')" shows

  Scenario: A task in progress offers Complete task and Pause task, and no other task in progress
    Given a palette task "Ship the palette" in progress
    And a palette task "Write the record" in progress
    When I visit "/admin/tasks/1?filter=today"
    And I press the keys "Meta+/"
    And I type "task" in the palette
    Then "#command-palette-complete-task:has-text('Complete task')" shows
    And "#command-palette-pause-task:has-text('Pause task')" shows
    And the admin markup lacks "#command-palette-start-task:visible"
    And the admin markup lacks "[id*='-task-in-progress-']:visible"

  Scenario: Pause task returns the task on screen to open, ends its work session and leaves me there
    Given a palette task "Ship the palette" in progress
    When I visit "/admin/tasks/1?filter=today"
    And I press the keys "Meta+/"
    And I type "pause task" in the palette
    And I press the keys "Enter"
    And the palette closes
    Then the database soon answers "open 0" for:
      """
      SELECT status, (SELECT count(*) FROM work_sessions WHERE ended_at IS NULL) FROM tasks WHERE id = 1
      """
    And the admin address is "/admin/tasks/1?filter=today"
    And ".task-drawer-head:has-text('open')" shows

  Scenario: Complete task finishes the task on screen and leaves me there
    Given a palette task "Ship the palette" in progress
    When I visit "/admin/tasks/1?filter=today"
    And I press the keys "Meta+/"
    And I type "complete task" in the palette
    And I press the keys "Enter"
    And the palette closes
    Then the database soon answers "done" for:
      """
      SELECT status FROM tasks WHERE id = 1
      """
    And the admin address is "/admin/tasks/1?filter=today"
    And ".task-drawer-head:has-text('done')" shows

  Scenario: A closed task offers none of them, nor the tasks in progress
    Given a palette task "Ship the palette" in progress
    And the database runs:
      """
      INSERT INTO tasks (title, position, list, status, completed_at) VALUES ('Filed away', 9, 'next', 'done', now());
      """
    When I visit "/admin/tasks/2"
    And I press the keys "Meta+/"
    And I type "task" in the palette
    Then "#command-palette-create-task" shows
    And the admin markup lacks "#command-palette-start-task:visible"
    And the admin markup lacks "[id^='command-palette-complete-task']:visible, [id^='command-palette-pause-task']:visible"

  Scenario: With no task on screen the palette completes a task in progress and leaves me where I was
    Given a palette task "Ship the palette" in progress
    And a palette task "Write the record" in progress
    And the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Not started', 9, 'next');
      """
    When I visit "/admin/posts"
    And I press the keys "Meta+/"
    And I type "complete" in the palette
    Then ".pal-r:has-text('Complete Ship the palette')" shows
    And ".pal-r:has-text('Complete Write the record')" shows
    And the admin markup lacks ".pal-r:has-text('Not started'):visible"
    And the admin markup lacks "#command-palette-start-task:visible, #command-palette-complete-task:visible"
    When I click the palette row "command-palette-complete-task-in-progress-1"
    And the palette closes
    Then the database soon answers "done" for:
      """
      SELECT status FROM tasks WHERE id = 1
      """
    And the admin address is "/admin/posts"

  Scenario: With no task on screen the palette pauses a task in progress and leaves me where I was
    Given a palette task "Ship the palette" in progress
    And a palette task "Write the record" in progress
    And the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Not started', 9, 'next');
      """
    When I visit "/admin/posts"
    And I press the keys "Meta+/"
    And I type "pause" in the palette
    Then ".pal-r:has-text('Pause Ship the palette')" shows
    And ".pal-r:has-text('Pause Write the record')" shows
    And the admin markup lacks ".pal-r:has-text('Not started'):visible"
    And the admin markup lacks "#command-palette-pause-task:visible"
    When I click the palette row "command-palette-pause-task-in-progress-1"
    And the palette closes
    Then the database soon answers "open 0" for:
      """
      SELECT status, (SELECT count(*) FROM work_sessions WHERE task_id = 1 AND ended_at IS NULL) FROM tasks WHERE id = 1
      """
    And the admin address is "/admin/posts"

  Scenario: With no task on screen and none in progress the palette lists none to complete or pause
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Not started', 1, 'next');
      """
    When I visit "/admin/posts"
    And I press the keys "Meta+/"
    And I type "complete" in the palette
    Then the admin markup lacks "[data-palette-list][aria-busy]"
    And the admin markup lacks "[id^='command-palette-complete-task']:visible, [id^='command-palette-pause-task']:visible"
    When I press the keys "Backspace Backspace Backspace Backspace Backspace Backspace Backspace Backspace"
    And I type "pause" in the palette
    Then the admin markup lacks "[id^='command-palette-pause-task']:visible"

  Scenario: A task open in the flyout gets Start task, which starts it and leaves me on the list
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Email the accountant', 1, 'next');
      """
    And a palette task "Ship the palette" in progress
    When I visit "/admin/tasks?filter=next"
    And I click the link "Email the accountant"
    Then "dialog[data-task-panel][open]:has-text('Email the accountant')" shows
    When I press the keys "Meta+/"
    And I type "task" in the palette
    Then "#command-palette-start-task" shows
    And the admin markup lacks "[id^='command-palette-complete-task']:visible"
    When I click the palette row "command-palette-start-task"
    And the palette closes
    Then the database soon answers "in_progress" for:
      """
      SELECT status FROM tasks WHERE id = 1
      """
    And the admin address is "/admin/tasks?filter=next"

  Scenario: On a phone the search button starts, pauses and completes the task on screen
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Email the accountant', 1, 'next');
      """
    And the admin window is 375 by 800
    When I visit "/admin/tasks/1"
    And I tap the top bar search button
    And I click the palette row "command-palette-start-task"
    And the palette closes
    Then the database soon answers "in_progress" for:
      """
      SELECT status FROM tasks WHERE id = 1
      """
    And the admin address is "/admin/tasks/1"
    And ".task-drawer-head:has-text('in progress')" shows
    When I tap the top bar search button
    And I click the palette row "command-palette-pause-task"
    And the palette closes
    Then the database soon answers "open" for:
      """
      SELECT status FROM tasks WHERE id = 1
      """
    And ".task-drawer-head:has-text('open')" shows
    When I tap the top bar search button
    And I click the palette row "command-palette-start-task"
    And the palette closes
    Then the database soon answers "in_progress" for:
      """
      SELECT status FROM tasks WHERE id = 1
      """
    And ".task-drawer-head:has-text('in progress')" shows
    When I tap the top bar search button
    And I click the palette row "command-palette-complete-task"
    And the palette closes
    Then the database soon answers "done" for:
      """
      SELECT status FROM tasks WHERE id = 1
      """

  Scenario Outline: <path> with a task passes axe in light and dark
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Email the accountant', 1, 'next');
      """
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path                      |
      | /admin/tasks/1?filter=next |
      | /admin/tasks?filter=next  |
